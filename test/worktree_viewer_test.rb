#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# worktree-viewer opens the herdr-file-viewer plugin's program at the worktree an agent works in.
# Everything outside the launcher is stubbed: herdr on PATH, and a fake plugin root holding a stub
# viewer program and stub launcher scripts.
class WorktreeViewerTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-viewer", __dir__)
  README = File.expand_path("../herdr/.config/herdr/README.md", __dir__)
  HERDR_CONFIG = File.expand_path("../herdr/.config/herdr/config.toml", __dir__)

  def setup
    @root = Dir.mktmpdir
    @stub_bin = File.join(@root, "bin")
    @plugin_root = File.join(@root, "plugin")
    @config_dir = File.join(@root, "plugin-config")
    @state_home = File.join(@root, "state")
    @panes_file = File.join(@root, "panes.json")
    [ @stub_bin, @config_dir, @state_home, File.join(@plugin_root, "scripts"),
      File.join(@plugin_root, "target", "release") ].each { |dir| FileUtils.mkdir_p(dir) }
    install_herdr_stub
    install_plugin_program
    install_plugin_scripts
    @repo = create_repository("repo")
    @worktree = add_worktree(@repo, "feature")
    focus_pane(cwd: @repo)
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_a_pane_without_an_agent_hands_over_to_the_plugins_own_launchers
    focus_pane(cwd: @repo, agent: nil)

    run_launcher("split")
    run_launcher("tab")

    assert_equal([ "open-file-viewer.sh", "open-file-viewer-tab.sh" ], script_runs)
    assert_empty(herdr_calls_matching("pane", "split"))
    assert_empty(herdr_calls_matching("tab", "create"))
  end

  def test_an_open_viewer_in_the_tab_hands_over_to_the_plugins_own_launcher
    record_worktree
    split_result = run_launcher("split", decision: "FOCUS w1:pF")
    tab_result = run_launcher("tab", decision: "SWITCHTAB w1:t9")

    assert(split_result.last.success? && tab_result.last.success?, split_result[1] + tab_result[1])
    assert_equal([ "open-file-viewer.sh", "open-file-viewer-tab.sh" ], script_runs)
    assert_empty(herdr_calls_matching("pane", "split"))
    assert_empty(herdr_calls_matching("tab", "create"))
  end

  def test_with_a_usable_record_prefix_f_opens_a_split_beside_the_agent_rooted_in_the_worktree
    record_worktree

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    split = first_call("pane", "split")
    assert_equal("w1:pA", option(split, "--pane"))
    assert_equal(@worktree, option(split, "--cwd"))
    assert_includes(herdr_calls, [ "pane", "rename", "w1:pV", "Files" ])
    assert_empty(herdr_calls_matching("pane", "send-keys"))
  end

  def test_with_a_usable_record_prefix_shift_f_opens_a_tab_rooted_in_the_worktree
    record_worktree

    _stdout, stderr, status = run_launcher("tab")

    assert(status.success?, stderr)
    tab = first_call("tab", "create")
    assert_equal(@worktree, option(tab, "--cwd"))
    assert_includes(herdr_calls, [ "pane", "rename", "w1:pT", "Files" ])
    assert_empty(herdr_calls_matching("pane", "send-keys"))
  end

  def test_a_record_for_a_removed_worktree_opens_at_the_pane_folder_with_the_picker
    record_worktree
    system("git", "-C", @repo, "worktree", "remove", "--force", @worktree, exception: true)

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@repo, option(first_call("pane", "split"), "--cwd"))
    assert_includes(herdr_calls, [ "pane", "send-keys", "w1:pV", "W" ])
  end

  def test_a_record_for_another_repository_opens_at_the_pane_folder_with_the_picker
    other_worktree = add_worktree(create_repository("other"), "feature")
    record_worktree(other_worktree)

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@repo, option(first_call("pane", "split"), "--cwd"))
    assert_includes(herdr_calls, [ "pane", "send-keys", "w1:pV", "W" ])
  end

  def test_an_agent_in_the_main_checkout_without_a_record_gets_the_picker_once_the_viewer_draws
    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@repo, option(first_call("pane", "split"), "--cwd"))
    wait_index = herdr_calls.index { |call| call[0..1] == [ "pane", "wait-output" ] }
    key_index = herdr_calls.index([ "pane", "send-keys", "w1:pV", "W" ])
    assert(wait_index, "launcher never waited for the viewer to draw")
    assert(key_index && wait_index < key_index, "W was not sent after the wait")
  end

  def test_when_the_viewer_does_not_draw_in_time_no_key_is_sent
    _stdout, stderr, status = run_launcher("split", wait_status: "1")

    assert(status.success?, stderr)
    wait = first_call("pane", "wait-output")
    assert_equal("5000", option(wait, "--timeout"))
    assert_empty(herdr_calls_matching("pane", "send-keys"))
    assert_empty(herdr_calls_matching("pane", "close"))
  end

  def test_an_agent_pane_in_a_worktree_without_a_record_opens_there_without_the_picker
    focus_pane(cwd: @worktree)

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@worktree, option(first_call("pane", "split"), "--cwd"))
    assert_empty(herdr_calls_matching("pane", "send-keys"))
  end

  def test_the_split_follows_the_viewers_open_direction_setting
    File.write(File.join(@config_dir, "config.toml"), %(open_direction = "down"\n))

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal("down", option(first_call("pane", "split"), "--direction"))
  end

  def test_the_split_opens_to_the_right_by_default
    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal("right", option(first_call("pane", "split"), "--direction"))
  end

  def test_the_viewer_reads_its_settings_from_the_plugin_config_folder
    record_worktree

    run_launcher("split")
    run_launcher("tab")

    expected = "HERDR_PLUGIN_CONFIG_DIR=#{@config_dir}"
    assert_equal(expected, option(first_call("pane", "split"), "--env"))
    assert_equal(expected, option(first_call("tab", "create"), "--env"))
  end

  def test_the_viewer_replaces_the_panes_shell_so_quitting_closes_the_pane
    record_worktree

    run_launcher("split")

    program = File.join(@plugin_root, "target", "release", "herdr-file-viewer")
    assert_includes(herdr_calls, [ "pane", "run", "w1:pV", "exec '#{program}'" ])
  end

  def test_hands_over_to_the_plugins_own_launcher_with_a_warning_when_the_viewer_program_is_missing
    FileUtils.rm(File.join(@plugin_root, "target", "release", "herdr-file-viewer"))

    _stdout, stderr, _status = run_launcher("split")

    assert_match(/warning/i, stderr)
    assert_equal([ "open-file-viewer.sh" ], script_runs)
    assert_empty(herdr_calls_matching("pane", "split"))
  end

  def test_an_unexpected_open_direction_answer_opens_the_split_to_the_right
    _stdout, stderr, status = run_launcher("split", direction: "sideways")

    assert(status.success?, stderr)
    assert_equal("right", option(first_call("pane", "split"), "--direction"))
  end

  def test_the_launcher_calls_the_herdr_named_in_herdr_bin_path
    elsewhere = File.join(@root, "elsewhere")
    FileUtils.mkdir_p(elsewhere)
    FileUtils.mv(File.join(@stub_bin, "herdr"), File.join(elsewhere, "herdr"))
    record_worktree

    _stdout, stderr, status = run_launcher("split", herdr_bin_path: File.join(elsewhere, "herdr"))

    assert(status.success?, stderr)
    assert_equal(@worktree, option(first_call("pane", "split"), "--cwd"))
  end

  def test_without_herdr_the_launcher_exits_with_a_warning_instead_of_a_crash
    FileUtils.rm(File.join(@stub_bin, "herdr"))

    _stdout, stderr, status = run_launcher("split", path: File.dirname(RbConfig.ruby))

    refute(status.success?)
    assert_match(/worktree-viewer: .*herdr/, stderr)
    refute_match(/\.rb:\d+:in /, stderr)
  end

  def test_hands_over_to_the_plugins_own_launcher_with_a_warning_when_open_direction_fails
    _stdout, stderr, _status = run_launcher("split", direction_fails: true)

    assert_match(/warning/i, stderr)
    assert_equal([ "open-file-viewer.sh" ], script_runs)
    assert_empty(herdr_calls_matching("pane", "split"))
  end

  def test_exits_with_a_warning_when_the_plugin_is_not_installed
    _stdout, stderr, _status = run_launcher("split", plugin_installed: false)

    assert_match(/warning/i, stderr)
    assert_empty(script_runs)
    assert_empty(herdr_calls_matching("pane", "split"))
  end

  def test_the_readme_describes_opening_at_the_agents_worktree
    section = File.read(README)[/^### Reading a file an agent wrote\n.*?(?=^### )/m]

    assert_match(/agent['’]s worktree/, section)
    assert_match(/worktree-create/, section)
  end

  def test_prefix_f_and_prefix_shift_f_run_the_launcher
    blocks = File.read(HERDR_CONFIG).split("[[keys.command]]")

    assert_match(%r{worktree-viewer" split}, shell_command_for(blocks, "prefix+f"))
    assert_match(%r{worktree-viewer" tab}, shell_command_for(blocks, "prefix+shift+f"))
  end

  private

  def shell_command_for(blocks, key)
    block = blocks.find { |candidate| candidate.match?(/^key = "#{Regexp.escape(key)}"$/) }
    return "" unless block && block.match?(/^type = "shell"$/)

    block[/^command = (.*)$/, 1].to_s
  end

  def run_launcher(argument, decision: "OPEN", wait_status: "0", direction_fails: false,
                   plugin_installed: true, direction: nil, herdr_bin_path: nil, path: nil)
    environment = {
      "PATH" => path || "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "HERDR_BIN_PATH" => herdr_bin_path,
      "PLUGIN_STUB_DIRECTION" => direction,
      "HOME" => @root,
      "XDG_STATE_HOME" => @state_home,
      "HERDR_PANE_ID" => nil,
      "HERDR_STUB_CALLS" => calls_file,
      "HERDR_STUB_PANES" => @panes_file,
      "HERDR_STUB_PLUGIN_ROOT" => (plugin_installed ? @plugin_root : ""),
      "HERDR_STUB_CONFIG_DIR" => @config_dir,
      "HERDR_STUB_WAIT_STATUS" => wait_status,
      "PLUGIN_STUB_DECISION" => decision,
      "PLUGIN_STUB_DIRECTION_FAILS" => (direction_fails ? "1" : nil),
      "PLUGIN_STUB_SCRIPT_LOG" => script_log
    }
    Open3.capture3(environment, "ruby", SCRIPT, argument)
  end

  def focus_pane(cwd:, agent: "claude")
    pane = { pane_id: "w1:pA", terminal_id: "term_A", tab_id: "w1:t1", focused: true, cwd: cwd }
    pane[:agent] = agent if agent
    File.write(@panes_file, JSON.generate({ result: { panes: [ pane ] } }))
  end

  def record_worktree(path = @worktree)
    directory = File.join(@state_home, "worktree-tools", "agent-worktrees")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "w1_pA"), JSON.generate({ terminal_id: "term_A", path: path }))
  end

  def option(call, flag)
    call[call.index(flag) + 1]
  end

  def calls_file
    File.join(@root, "herdr-calls.jsonl")
  end

  def script_log
    File.join(@root, "script-runs.log")
  end

  def herdr_calls
    return [] unless File.exist?(calls_file)

    File.readlines(calls_file, chomp: true).map { |line| JSON.parse(line) }
  end

  def herdr_calls_matching(*command)
    herdr_calls.select { |call| call.first(command.size) == command }
  end

  def first_call(*command)
    herdr_calls_matching(*command).first || flunk("herdr #{command.join(' ')} was never called")
  end

  def script_runs
    File.exist?(script_log) ? File.readlines(script_log, chomp: true) : []
  end

  def create_repository(name)
    path = File.join(@root, name)
    FileUtils.mkdir_p(path)
    git(path, "init", "--quiet", "--initial-branch=main")
    git(path, "commit", "--quiet", "--allow-empty", "-m", "initial")
    File.realpath(path)
  end

  def add_worktree(repository, name)
    path = File.join(repository, ".worktrees", name)
    git(repository, "worktree", "add", "--quiet", path, "-b", name)
    File.realpath(path)
  end

  def git(dir, *arguments)
    system("git", "-C", dir, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test",
           "-c", "user.email=test@example.com", *arguments, exception: true)
  end

  def install_herdr_stub
    install_executable(File.join(@stub_bin, "herdr"), <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("HERDR_STUB_CALLS"), "a") { |file| file.puts(JSON.generate(ARGV)) }

      case ARGV[0..1]
      when [ "pane", "list" ]
        puts File.read(ENV.fetch("HERDR_STUB_PANES"))
      when [ "plugin", "list" ]
        root = ENV.fetch("HERDR_STUB_PLUGIN_ROOT")
        plugins = root.empty? ? [] : [ { plugin_id: "herdr-file-viewer", plugin_root: root } ]
        puts JSON.generate({ result: { plugins: plugins } })
      when [ "plugin", "config-dir" ]
        puts ENV.fetch("HERDR_STUB_CONFIG_DIR")
      when [ "pane", "split" ]
        puts JSON.generate({ result: { pane: { pane_id: "w1:pV" } } })
      when [ "tab", "create" ]
        puts JSON.generate({ result: { root_pane: { pane_id: "w1:pT" }, tab: { tab_id: "w1:t9" } } })
      when [ "pane", "wait-output" ]
        exit(ENV.fetch("HERDR_STUB_WAIT_STATUS").to_i)
      else
        puts JSON.generate({ result: { type: "ok" } })
      end
    RUBY
  end

  def install_plugin_program
    install_executable(File.join(@plugin_root, "target", "release", "herdr-file-viewer"), <<~'RUBY')
      #!/usr/bin/env ruby
      case ARGV[0]
      when "--launch-decision", "--launch-decision-tab"
        $stdin.read
        puts ENV.fetch("PLUGIN_STUB_DECISION")
      when "--open-direction"
        exit(1) if ENV["PLUGIN_STUB_DIRECTION_FAILS"]
        if ENV["PLUGIN_STUB_DIRECTION"]
          puts ENV["PLUGIN_STUB_DIRECTION"]
          exit
        end
        settings = File.join(ENV.fetch("HERDR_PLUGIN_CONFIG_DIR"), "config.toml")
        down = File.exist?(settings) && File.read(settings).match?(/open_direction\s*=\s*"down"/)
        puts(down ? "down" : "right")
      end
    RUBY
  end

  def install_plugin_scripts
    %w[open-file-viewer.sh open-file-viewer-tab.sh].each do |name|
      File.write(File.join(@plugin_root, "scripts", name),
                 "echo #{name} >> \"$PLUGIN_STUB_SCRIPT_LOG\"\n")
    end
  end

  def install_executable(path, content)
    File.write(path, content)
    FileUtils.chmod(0o755, path)
  end
end
