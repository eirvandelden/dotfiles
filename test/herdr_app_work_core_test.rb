#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "isolated_git"

# install/tasks/27_register_work_core.sh starts the work core and registers it with the default core.
# These tests run the real script with a PATH that holds stubs and a few real tools, a scratch HOME and an
# os-release file. An `hc` stub logs every call and keeps its answers in a state file, so no test reaches a
# real core.
class HerdrAppWorkCoreTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  TASK = File.join(REPO_ROOT, "install/tasks/27_register_work_core.sh")
  REAL_TOOLS = %w[bash env dirname basename jq cat sed grep tr head cut id readlink].freeze

  HC_STUB = <<~RUBY.freeze
    #!#{RbConfig.ruby}
    require "json"
    state_file = File.join(ENV.fetch("STUB_DIR"), "hc.json")
    state = JSON.parse(File.read(state_file))
    session = ENV.fetch("HC_SESSION")
    File.open(File.join(ENV.fetch("STUB_DIR"), "hc.log"), "a") { |log| log.puts("\#{session} \#{ARGV.join(' ')}") }
    save = -> { File.write(state_file, JSON.generate(state)) }
    case ARGV.first(2)
    when %w[server status]
      abort("not running") unless state["running"].include?(session)
      puts({ "live" => 0, "version" => "0.1.18" }.to_json)
    when %w[server start]
      state["running"] << session
      save.()
    when %w[ls --json] then puts({ "terminals" => Array.new(state["live"]) { { "state" => "live" } } }.to_json)
    when %w[machine ls] then puts({ "machines" => state["machines"] }.to_json)
    when %w[machine add]
      if state["too_old"]
        puts({ "error" => { "message" => "the hc on work is too old" } }.to_json)
        exit 1
      end
      name = ARGV[ARGV.index("--name") + 1]
      state["machines"] << { "name" => name, "session" => ARGV[ARGV.index("--session") + 1], "target" => ARGV[ARGV.index("--via") + 1],
                             "via" => true, "state" => state["new_state"] }
      save.()
      puts({ "name" => name }.to_json)
    when %w[machine update]
      state["too_old"] = false
      save.()
    else abort("stub hc: \#{ARGV.inspect}")
    end
  RUBY

  def setup
    @directory = Dir.mktmpdir("work-core")
    @bin = File.join(@directory, "bin")
    @home = File.join(@directory, "home")
    FileUtils.mkdir_p([ @bin, @home ])
    REAL_TOOLS.each { |tool| link_tool(tool) }
    @state = { "running" => [ "work" ], "machines" => [], "live" => 0, "too_old" => false, "new_state" => "connected" }
    @with_hc = true
  end

  def teardown
    FileUtils.rm_rf(@directory)
  end

  def test_the_task_is_executable
    assert_predicate(File.stat(TASK), :executable?)
  end

  def test_install_runs_the_task_after_the_herdr_app_install
    lines = File.readlines(File.join(REPO_ROOT, "install.sh"))
    install = lines.index { |line| line.include?(%(run_task "26_install_herdr_app.sh" "$root")) }
    task = lines.index { |line| line.include?(%(run_task "27_register_work_core.sh" "$root")) }

    refute_nil(task)
    assert_equal(install + 1, task)
  end

  def test_registers_the_work_core_with_the_default_core
    _stdout, stderr, status = run_task

    assert_predicate(status, :success?, stderr)
    assert_includes(calls, "default machine add --via sh -c --name work --session work --json")
    assert_equal([ "work" ], machines.map { |machine| machine["name"] })
  end

  def test_a_second_run_changes_nothing
    run_task
    before = calls.size
    stdout, _stderr, status = run_task

    assert_predicate(status, :success?)
    assert_match(/already registered/, stdout)
    assert_empty(calls.drop(before).grep(/machine add|machine update|server start/))
  end

  def test_starts_the_work_core_when_it_is_not_running
    @state["running"] = []
    run_task

    assert_includes(calls, "work server start")
  end

  def test_the_task_never_stops_a_core
    @state["running"] = []
    @state["too_old"] = true
    run_task
    run_task

    assert_empty(calls.grep(/stop|restart/))
  end

  def test_a_mismatched_work_machine_fails_without_change
    @state["machines"] = [ { "name" => "work", "session" => "other", "target" => "sh -c", "via" => true, "state" => "connected" } ]
    _stdout, stderr, status = run_task

    refute_predicate(status, :success?)
    assert_match(/another session or transport/, stderr)
    assert_empty(calls.grep(/machine add|machine update/))
    assert_equal("other", machines.first["session"])
  end

  def test_an_unreachable_work_machine_warns
    @state["new_state"] = "unreachable"
    _stdout, stderr, status = run_task

    assert_predicate(status, :success?)
    assert_match(/work machine is unreachable/, stderr)
  end

  def test_skips_with_a_warning_without_hc
    @with_hc = false
    _stdout, stderr, status = run_task

    assert_predicate(status, :success?)
    assert_match(/open herdr-app once/, stderr)
  end

  def test_skips_on_debian
    stdout, _stderr, status = run_task(distro: "ubuntu")

    assert_predicate(status, :success?)
    assert_match(/skipping/, stdout)
    assert_empty(calls)
  end

  def test_updates_an_empty_work_core_that_is_too_old
    @state["too_old"] = true
    _stdout, stderr, status = run_task

    assert_predicate(status, :success?, stderr)
    assert_includes(calls, "default machine update work")
    assert_equal([ "work" ], machines.map { |machine| machine["name"] })
  end

  def test_refuses_to_update_a_work_core_with_live_terminals
    @state["too_old"] = true
    @state["live"] = 2
    _stdout, stderr, status = run_task

    refute_predicate(status, :success?)
    assert_match(/2 live terminal/, stderr)
    assert_empty(calls.grep(/machine update/))
  end

  private

  def run_task(distro: "steamos")
    File.write(File.join(@directory, "hc.json"), JSON.generate(@state))
    write_stub("uname", "#!/bin/sh\ncase \"$1\" in -s) echo Linux ;; *) echo x86_64 ;; esac\n")
    write_stub("hc", HC_STUB) if @with_hc
    os_release = File.join(@directory, "os-release")
    File.write(os_release, "ID=#{distro}\nPRETTY_NAME=\"#{distro}\"\n")
    env = { "HOME" => @home, "PATH" => @bin, "OS_RELEASE_FILE" => os_release, "STUB_DIR" => @directory }
    Open3.capture3(env, "bash", TASK, unsetenv_others: true).tap { @state = JSON.parse(File.read(File.join(@directory, "hc.json"))) }
  end

  def calls
    path = File.join(@directory, "hc.log")
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  def machines
    @state.fetch("machines")
  end

  def link_tool(tool)
    path = ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, tool) }.find { |file| File.executable?(file) }
    FileUtils.ln_s(path, File.join(@bin, tool)) if path
  end

  def write_stub(name, body)
    path = File.join(@bin, name)
    FileUtils.rm_f(path)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end
end
