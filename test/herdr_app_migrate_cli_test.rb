#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "isolated_git"

# Runs the real herdr-app-migrate executable with a PATH that holds one Ruby stub, installed as both
# `herdr` and `herdr-app`. The stub drops a leading `--session <S>`, logs its arguments, answers from a
# JSON fixture and keeps the spaces that `space.new` makes, so a second build sees them. Names, sessions
# and folders are invented. No test reaches a real herdr or herdr-app.
class HerdrAppMigrateCliTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  EXECUTABLE = File.join(REPO_ROOT, "herdr-app/.local/bin/herdr-app-migrate")

  STUB = <<~RUBY.freeze
    #!#{RbConfig.ruby}
    require "json"
    dir = ENV.fetch("STUB_DIR")
    argv = ARGV.dup
    argv.shift(2) if argv.first == "--session"
    File.open(File.join(dir, "calls.log"), "a") { |log| log.puts([ File.basename($0), *argv ].to_json) }
    fixture = JSON.parse(File.read(File.join(dir, "tui.json")))
    state_file = File.join(dir, "app.json")
    state = File.exist?(state_file) ? JSON.parse(File.read(state_file)) : { "spaces" => [], "n" => 0 }
    wrap = ->(result) { puts({ "id" => "x", "result" => result }.to_json) }
    if File.basename($0) == "herdr"
      case argv.first(2)
      when %w[workspace list] then wrap.({ "workspaces" => fixture["workspaces"] })
      when %w[tab list] then wrap.({ "tabs" => fixture["tabs"].fetch(argv.last) })
      when %w[pane list] then wrap.({ "panes" => fixture["panes"].fetch(argv.last) })
      when %w[pane layout] then wrap.({ "layout" => { "panes" => fixture["layouts"].fetch(argv.last) } })
      when %w[agent list] then wrap.({ "agents" => fixture["agents"] })
      else abort("stub herdr: \#{argv.inspect}")
      end
      exit
    end
    add_terminal = lambda do |tab|
      state["n"] += 1
      tab["terminals"] << { "terminal" => "t\#{state['n']}", "pane" => "p\#{state['n']}", "status" => nil }
      { "terminal" => "t\#{state['n']}", "pane" => "p\#{state['n']}" }
    end
    case argv.first(2)
    when %w[ls] then puts({ "spaces" => state["spaces"], "recent" => [] }.to_json)
    when %w[do space.new]
      a = JSON.parse(argv.last)
      state["n"] += 1
      tab = { "id" => "tab\#{state['n']}", "name" => a["tab"], "terminals" => [] }
      space = { "id" => "sp\#{state['n']}", "name" => a["name"], "folder" => a["folder"], "tabs" => [ tab ],
                "machine" => a["machine"].to_s.empty? ? nil : a["machine"] }
      state["spaces"] << space
      made = add_terminal.(tab)
      puts({ "space" => space["id"], "tab" => tab["id"], "terminal" => made["terminal"] }.to_json)
    when %w[do tab.new]
      a = JSON.parse(argv.last)
      state["n"] += 1
      tab = { "id" => "tab\#{state['n']}", "name" => a["name"], "terminals" => [] }
      state["spaces"].find { |space| space["id"] == a["space"] }["tabs"] << tab
      puts({ "space" => a["space"], "tab" => tab["id"], "terminal" => add_terminal.(tab)["terminal"] }.to_json)
    when %w[do pane.split]
      tab = state["spaces"].flat_map { |space| space["tabs"] }.find { |t| t["terminals"].any? { |x| x["pane"] == JSON.parse(argv.last)["pane"] } }
      puts(add_terminal.(tab).to_json)
    when %w[do space.close] then puts({ "ok" => true }.to_json)
    else abort("stub herdr-app: \#{argv.inspect}")
    end
    File.write(state_file, state.to_json)
  RUBY

  def setup
    @directory = Dir.mktmpdir("migrate-cli")
    @bin = File.join(@directory, "bin")
    FileUtils.mkdir_p(@bin)
    %w[herdr herdr-app].each { |name| File.write(File.join(@bin, name), STUB) && File.chmod(0o755, File.join(@bin, name)) }
    write_tui(side_by_side: true)
  end

  def teardown
    FileUtils.rm_rf(@directory)
  end

  def test_the_executable_is_executable
    assert_predicate(File.stat(EXECUTABLE), :executable?)
  end

  def test_build_builds_every_workspace_on_the_machine
    _stdout, _stderr, status = migrate("build", "--tui", "tui1", "--machine", "work")

    assert_predicate(status, :success?)
    assert_equal(%w[alpha beta], app_spaces.map { |space| space["name"] })
    assert_equal([ "work" ], app_spaces.map { |space| space["machine"] }.uniq)
    assert_equal(%w[main logs], app_spaces.first["tabs"].map { |tab| tab["name"] })
  end

  def test_a_second_build_creates_nothing
    migrate("build", "--tui", "tui1", "--machine", "")
    created = creates.size
    stdout, _stderr, status = migrate("build", "--tui", "tui1", "--machine", "")

    assert_predicate(status, :success?)
    assert_equal(created, creates.size)
    assert_equal("skipped\talpha\nskipped\tbeta\n", stdout)
  end

  def test_build_resumes_every_running_agent_once
    migrate("build", "--tui", "tui1", "--machine", "")
    resumes = creates.select { |call| call.last.include?("--resume") }

    assert_equal(1, resumes.size)
    assert_equal([ "claude", "--resume", "abc-123" ], JSON.parse(resumes.first.last)["argv"].last(3))
  end

  def test_build_prints_one_line_per_tui_pane
    stdout, _stderr, _status = migrate("build", "--tui", "tui1", "--machine", "")
    lines = stdout.lines(chomp: true).map { |line| line.split("\t") }

    assert_equal(%w[w1:p1 w1:p2 w1:p3 w2:p1], lines.map { |fields| fields[2] })
    assert_equal("claude abc-123 started", lines.first.last)
    assert_equal("shell", lines[1].last)
    assert(lines.all? { |fields| fields[3].start_with?("p") })
  end

  def test_dry_run_sends_no_create_command
    stdout, _stderr, status = migrate("build", "--tui", "tui1", "--machine", "", "--dry-run")

    assert_predicate(status, :success?)
    assert_empty(creates)
    refute_empty(stdout)
  end

  def test_dry_run_previews_tabs_splits_and_skips
    migrate("build", "--tui", "tui1", "--machine", "work")
    stdout, = migrate("build", "--tui", "tui1", "--machine", "", "--dry-run")

    assert_includes(stdout, "space alpha (/work/alpha)")
    assert_includes(stdout, "  split pane 1 right -> pane 2")
    assert_includes(stdout, "  pane 1: claude session abc-123 in /work/alpha")
    refute_includes(stdout, "skip alpha")
    assert_includes(stdout, "login shell in /work/beta")
  end

  def test_a_refused_layout_creates_nothing
    write_tui(side_by_side: false)
    _stdout, stderr, status = migrate("build", "--tui", "tui1", "--machine", "")

    refute_predicate(status, :success?)
    assert_empty(creates)
    assert_match(/overlap/, stderr)
  end

  def test_a_refusal_prints_one_line_and_exits_1
    File.delete(File.join(@directory, "tui.json"))
    _stdout, stderr, status = migrate("build", "--tui", "tui1", "--machine", "")

    assert_equal(1, status.exitstatus, stderr)
    assert_equal(1, stderr.lines.size)
    assert_match(/\Aherdr-app-migrate: /, stderr)
  end

  def test_stale_lists_the_machines_live_spaces_and_close_closes_the_approved_one
    migrate("build", "--tui", "tui1", "--machine", "")
    listing, = migrate("stale", "--machine", "")
    id = listing.lines.first.split("\t").first
    _stdout, _stderr, status = migrate("close", "--machine", "", id)

    assert_predicate(status, :success?)
    assert_equal(1, calls.count { |call| call[1] == "space.close" })
  end

  def test_close_with_an_unknown_id_closes_nothing
    _stdout, stderr, status = migrate("close", "--machine", "", "nope")

    refute_predicate(status, :success?)
    assert_match(/nope/, stderr)
    assert_equal(0, calls.count { |call| call[1] == "space.close" })
  end

  private

  def migrate(*arguments)
    env = { "PATH" => "#{@bin}:/usr/bin:/bin", "STUB_DIR" => @directory }
    Open3.capture3(env, RbConfig.ruby, EXECUTABLE, *arguments)
  end

  def calls
    path = File.join(@directory, "calls.log")
    File.exist?(path) ? File.readlines(path).map { |line| JSON.parse(line).drop(1) } : []
  end

  def creates
    calls.select { |call| call.first == "do" && %w[space.new tab.new pane.split].include?(call[1]) }.map { |call| call.drop(1) }
  end

  def app_spaces
    JSON.parse(File.read(File.join(@directory, "app.json"))).fetch("spaces")
  end

  def rect(x, y, width, height)
    { "x" => x, "y" => y, "width" => width, "height" => height }
  end

  def write_tui(side_by_side:)
    second = side_by_side ? rect(50, 0, 50, 40) : rect(40, 0, 60, 40)
    first = rect(0, 0, side_by_side ? 50 : 60, 40)
    panes = ->(workspace, tab, id, cwd) { { "pane_id" => "#{workspace}:#{id}", "tab_id" => "#{workspace}:#{tab}", "cwd" => cwd } }
    fixture = {
      "workspaces" => [ { "workspace_id" => "w1", "label" => "alpha" }, { "workspace_id" => "w2", "label" => "beta" } ],
      "tabs" => { "w1" => [ { "tab_id" => "w1:t1", "label" => "main" }, { "tab_id" => "w1:t2", "label" => "logs" } ],
                  "w2" => [ { "tab_id" => "w2:t1", "label" => "only" } ] },
      "panes" => { "w1" => [ panes.("w1", "t1", "p1", "/work/alpha"), panes.("w1", "t1", "p2", "/work/alpha/lib"),
                             panes.("w1", "t2", "p3", "/work/alpha") ],
                   "w2" => [ panes.("w2", "t1", "p1", "/work/beta") ] },
      "layouts" => { "w1:p1" => [ { "pane_id" => "w1:p1", "rect" => first }, { "pane_id" => "w1:p2", "rect" => second } ],
                     "w1:p3" => [ { "pane_id" => "w1:p3", "rect" => rect(0, 0, 100, 40) } ],
                     "w2:p1" => [ { "pane_id" => "w2:p1", "rect" => rect(0, 0, 100, 40) } ] },
      "agents" => [ { "agent" => "claude", "pane_id" => "w1:p1", "cwd" => "/work/alpha",
                      "agent_session" => { "kind" => "id", "value" => "abc-123" } } ]
    }
    File.write(File.join(@directory, "tui.json"), JSON.generate(fixture))
  end
end
