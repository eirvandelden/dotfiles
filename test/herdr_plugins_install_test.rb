#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# Task 52 installs and enables the herdr plugins that packages.conf lists. These tests run the real
# script with stub `herdr` and `go` commands first on PATH, so no test reaches the real herdr.
class HerdrPluginsInstallTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(REPO_ROOT, "install/tasks/52_install_herdr_plugins.sh")
  REPOSITORY = "vigneshwerv/herdr-golden-ratio"
  PLUGIN_ID = "vv.golden-ratio"

  def test_the_task_installs_a_missing_plugin_and_reloads_the_config
    _stdout, _stderr, status = run_task(plugin: :missing)

    assert_predicate(status, :success?)
    assert_includes(herdr_calls, "plugin install -y #{REPOSITORY}")
    assert_includes(herdr_calls, "server reload-config")
  end

  def test_the_task_enables_a_disabled_plugin
    _stdout, _stderr, status = run_task(plugin: :disabled)

    assert_predicate(status, :success?)
    assert_includes(herdr_calls, "plugin enable #{PLUGIN_ID}")
    refute_includes(herdr_calls, "plugin install -y #{REPOSITORY}")
  end

  def test_the_task_skips_an_enabled_plugin
    stdout, stderr, status = run_task(plugin: :enabled)

    assert_predicate(status, :success?)
    assert_match(/already enabled/, stdout + stderr)
    assert_equal([ "plugin list --plugin #{PLUGIN_ID} --json" ], herdr_calls)
  end

  def test_a_failed_reload_only_warns
    _stdout, stderr, status = run_task(plugin: :missing, reload_status: 1)

    assert_predicate(status, :success?)
    assert_match(/next server start/, stderr)
  end

  def test_a_failed_install_fails_the_task
    _stdout, _stderr, status = run_task(plugin: :missing, install_status: 1)

    refute_predicate(status, :success?)
    refute_includes(herdr_calls, "server reload-config")
  end

  def test_the_task_stops_without_go
    _stdout, stderr, status = run_task(plugin: :missing, go: false)

    refute_predicate(status, :success?)
    assert_match(/Missing required command\(s\): go/, stderr)
    assert_empty(herdr_calls)
  end

  def test_packages_conf_installs_go_and_lists_the_golden_ratio_plugin
    assert_includes(bash_array("BREW"), "go")
    assert_includes(bash_array("HERDR_PLUGINS"), "#{PLUGIN_ID}=#{REPOSITORY}")
  end

  def test_the_herdr_package_is_linked_file_by_file
    assert_includes(bash_array("STOW_SHARED"), "herdr")
  end

  def test_install_sh_runs_the_plugin_task_after_stow
    lines = File.readlines(File.join(REPO_ROOT, "install.sh"))
    stow = lines.index { |line| line.include?(%(run_task "50_stow_all.sh")) }
    plugins = lines.index { |line| line.include?(%(run_task "52_install_herdr_plugins.sh")) }

    refute_nil(stow)
    refute_nil(plugins)
    assert_operator(plugins, :>, stow)
  end

  def test_the_task_is_executable
    assert_path_exists(SCRIPT)
    assert_predicate(File.stat(SCRIPT), :executable?)
  end

  def setup
    @tmp = Dir.mktmpdir
    FileUtils.mkdir_p(bin_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmp)
  end

  private

  def bin_dir = File.join(@tmp, "bin")
  def log_path = File.join(@tmp, "herdr.log")

  def herdr_calls
    File.exist?(log_path) ? File.readlines(log_path, chomp: true) : []
  end

  def run_task(plugin:, install_status: 0, reload_status: 0, go: true)
    write_stub("herdr", herdr_stub(plugin))
    write_stub("go", "#!/bin/sh\necho go version go1.25.0\n") if go
    link_system_tools
    env = { "PATH" => bin_dir, "HOME" => @tmp, "STUB_LOG" => log_path,
            "STUB_INSTALL_STATUS" => install_status.to_s, "STUB_RELOAD_STATUS" => reload_status.to_s }
    Open3.capture3(env, system_tool("bash"), SCRIPT)
  end

  # The task runs with only these tools on PATH, so a `go` installed on the machine never leaks in.
  def link_system_tools
    %w[bash env dirname uname jq].each do |tool|
      FileUtils.ln_sf(system_tool(tool), File.join(bin_dir, tool))
    end
  end

  def system_tool(name)
    ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }.find { |path| File.executable?(path) }
  end

  def herdr_stub(plugin)
    plugins = { missing: "[]", enabled: %([{"enabled":true}]), disabled: %([{"enabled":false}]) }.fetch(plugin)
    <<~SH
      #!/bin/sh
      echo "$*" >> "$STUB_LOG"
      case "$1 $2" in
        "plugin list") echo '{"result":{"plugins":#{plugins}}}' ;;
        "plugin install") exit "$STUB_INSTALL_STATUS" ;;
        "server reload-config") exit "$STUB_RELOAD_STATUS" ;;
      esac
    SH
  end

  def write_stub(name, body)
    path = File.join(bin_dir, name)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end

  def bash_array(name)
    stdout, stderr, status = Open3.capture3(
      "bash", "-c", %(source "$0"; printf "%s\\n" "${#{name}[@]}"), File.join(REPO_ROOT, "packages.conf")
    )
    raise stderr unless status.success?

    stdout.split("\n")
  end
end
