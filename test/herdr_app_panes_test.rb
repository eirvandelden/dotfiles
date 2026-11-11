#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "shellwords"
require "tmpdir"
require_relative "herdr_app_harness"
require_relative "isolated_git"
%w[command_line panes].each { |name| require File.join(HerdrAppHarness::PANE_LIBRARY, name) }

# HerdrAppPane::Panes with a FakeCommandLine that answers from a HerdrAppHarness::World, in process: no test
# here starts herdr-app or hc. The coordinator is t10 in pane p10 of space sp1; see herdr_app_harness.rb.
module PanesTestSupport
  include HerdrAppHarness::Fixtures

  READY_VARIABLES = %w[HERDR_APP_READY_POLL HERDR_APP_READY_TIMEOUT SHELL].freeze
  ROW = "some-change".freeze

  def setup
    @saved_env = ENV.to_h.slice(*READY_VARIABLES)
    ENV["HERDR_APP_READY_POLL"] = "0"
    ENV["HERDR_APP_READY_TIMEOUT"] = "1"
    @common_dir = Dir.mktmpdir("common-dir")
    @main = Dir.mktmpdir("main-checkout")
    @cwd = Dir.mktmpdir("worktree")
    @world = default_world(cwd: @main)
  end

  def teardown
    READY_VARIABLES.each { |name| ENV[name] = @saved_env[name] }
    FileUtils.rm_rf([ @common_dir, @main, @cwd ])
  end

  private

  # A Panes on the current @world. Every Panes of one test logs into the same calls.
  def panes(own: HerdrAppHarness::COORDINATOR, coordinator: nil)
    command_line = HerdrAppHarness::FakeCommandLine.new(@world, calls)
    HerdrAppPane::Panes.new(own: own, coordinator: coordinator, common_dir: @common_dir, command_line: command_line)
  end

  def calls
    @calls ||= []
  end

  def splits
    actions("pane.split")
  end

  def closed_panes
    actions("pane.close").map { |request| request["pane"] }
  end

  def actions(name)
    calls.select { |call| call.first(3) == [ "herdr-app", "do", name ] }.map { |call| JSON.parse(call[3]) }
  end

  def listed_panes
    @world["spaces"].flat_map { |space| space["tabs"] }.flat_map { |tab| tab["terminals"] }.map { |row| row["pane"] }
  end

  # An agent in state status (nil: hc and herdr-app show no state), listed and known to hc.
  def add_agent(address, pane, status, app: "claude-code", cwd: @main)
    answer = terminal(address, cwd: cwd, status: status && agent(status, app: app))
    add_terminal(@world, agent_row(address, pane, status, app: app), answer)
  end

  def add_shell(address, pane, cwd: @main, foreground_cwd: cwd)
    add_terminal(@world, terminal_row(address, pane), terminal(address, cwd: cwd, foreground_cwd: foreground_cwd))
  end

  # Two spaces with the id sp0, one per machine, each with the coordinator's address t10 and an idle agent t20;
  # the coordinator's hc labels name sp0.
  def list_space_id_on_two_machines
    personal = space("sp0", tab("tb0", agent_row("t10", "p10"), agent_row("t20", "p20")), name: "dotfiles")
    work = space("sp0", tab("tb9", agent_row("t10", "p90"), agent_row("t20", "p92")), name: "api", machine: "work")
    @world["spaces"] = [ personal, work ]
    @world[HerdrAppHarness::FOCUS_KEY] = "p20"
    @world["terminals"]["t10"] = [ terminal("t10", cwd: @main, status: agent, space: "sp0", tab: "tb0") ]
  end

  def record_path(row = ROW)
    File.join(@common_dir, "herdr-app", "stage-panes-#{row}")
  end

  def write_record(*lines, row: ROW)
    FileUtils.mkdir_p(File.dirname(record_path(row)))
    File.write(record_path(row), lines.map { |line| "#{line}\n" }.join)
  end

  def record(row = ROW)
    File.exist?(record_path(row)) ? File.readlines(record_path(row), chomp: true) : []
  end
end

class HerdrAppPanesOpenTest < Minitest::Test
  include PanesTestSupport

  def test_open_raises_refusal_with_herdr_apps_reason
    @world["refuse_split"] = { "p10" => "pane p10 is zoomed" }

    error = assert_raises(HerdrAppPane::Refusal) { panes.open(@cwd, command: [ "claude" ]) }

    assert_match(/zoomed/, error.message)
  end

  def test_open_never_anchors_on_a_terminal_of_another_space
    work = space("sp0", tab("tb0", agent_row("t10", "p90"), terminal_row("t11", "p91")), name: "api", machine: "work")
    @world["spaces"].unshift(work)
    write_record("t11")

    panes.open(@cwd, command: [ "claude" ], row: ROW)
    panes.open(@cwd, command: [ "claude" ], placement: :new_row)

    assert_equal(%w[p11 p10], splits.map { |request| request["pane"] })
  end

  def test_open_refuses_a_space_id_listed_on_two_machines
    list_space_id_on_two_machines

    error = assert_raises(HerdrAppPane::Refusal) { panes.open(@cwd, command: [ "claude" ]) }

    assert_match(/sp0/, error.message)
    assert_empty(splits)
  end

  def test_open_falls_back_to_the_coordinator_when_the_row_end_is_gone_or_refuses
    write_record("t29")
    panes.open(@cwd, command: [ "claude" ], row: ROW)
    assert_equal([ %w[p10 right] ], splits.map { |request| request.values_at("pane", "direction") })

    @world = default_world(cwd: @main)
    add_agent("t21", "p21", "idle")
    @world["refuse_split"] = { "p21" => "pane p21 is zoomed" }
    write_record("t21")

    opened = panes.open(@cwd, command: [ "claude" ], row: ROW)

    assert_equal(%w[p10 right], splits.last.values_at("pane", "direction"))
    assert_equal("t61", opened)
  end

  def test_open_places_a_column_right_of_the_rows_last_live_pane
    add_agent("t20", "p20", "idle")
    add_agent("t21", "p21", "working")
    write_record("t20", "t21", "t22")

    panes.open(@cwd, command: [ "claude" ], row: ROW)

    assert_equal([ %w[p21 right] ], splits.map { |request| request.values_at("pane", "direction") })
  end

  def test_open_new_row_splits_down_from_the_coordinator
    add_agent("t21", "p21", "idle")
    write_record("t21")

    panes.open(@cwd, command: [ "claude" ], row: ROW, placement: :new_row)

    assert_equal([ %w[p10 down] ], splits.map { |request| request.values_at("pane", "direction") })
  end

  def test_open_uses_herdr_app_coordinator_over_the_own_terminal
    panes(own: "t11", coordinator: "t10").open(@cwd, command: [ "claude" ])

    assert_equal([ "p10" ], splits.map { |request| request["pane"] })
  end

  def test_open_roots_the_command_in_cwd
    marker = File.join(@main, "ran")
    panes.open(@cwd, command: [ "pwd" ])
    panes.open(@cwd, command: [ "touch", marker ])
    first, second = splits.map { |request| request["argv"] }

    output, status = Open3.capture2(*first)
    assert(status.success?)
    assert_equal(File.realpath(@cwd), File.realpath(output.strip))

    FileUtils.rm_rf(@cwd)
    _, status = Open3.capture2e(*second)
    refute(status.success?, "the command ran without its folder")
    refute_path_exists(marker)
  end

  def test_worktree_open_runs_a_login_shell
    shell_log = File.join(@main, "shell.log")
    ENV["SHELL"] = shell_stub(shell_log)
    @world["new_terminal"] = [ terminal("new", cwd: @cwd) ]

    opened = panes.open(@cwd, placement: :worktree)

    assert_equal("t61", opened)
    assert_equal(1, splits.size, splits.inspect)
    request = splits.first
    assert_equal(%w[p10 down], request.values_at("pane", "direction"))
    _, status = Open3.capture2e({ "SHELL" => ENV.fetch("SHELL") }, *request["argv"])
    assert(status.success?)
    assert_equal([ "-l", File.realpath(@cwd) ], File.readlines(shell_log, chomp: true))
  end

  def test_open_worktree_answers_nil_when_a_pane_already_shows_cwd
    add_shell("t12", "p12", cwd: @main, foreground_cwd: @cwd)

    assert_nil(panes.open(@cwd, placement: :worktree))
    assert_empty(splits)
  end

  def test_open_appends_started_column_and_new_row_panes_to_the_row_record
    first = panes.open(@cwd, command: [ "claude" ], row: ROW)
    second = panes.open(@cwd, command: [ "claude" ], row: ROW, placement: :new_row)

    assert_equal(%w[t61 t62], [ first, second ])
    assert_equal(%w[t61 t62], record)
  end

  def test_unlisted_and_worktree_opens_leave_the_row_record_unchanged
    write_record("t11")

    panes.open(@main, command: %w[gh dash], row: ROW, placement: :unlisted)
    panes.open(@cwd, row: ROW, placement: :worktree)

    assert_equal(2, splits.size)
    assert_equal(%w[t11], record)
  end

  def test_unlisted_open_does_not_wait_for_an_agent
    @world["new_terminal"] = [ terminal("new", cwd: @main) ]

    opened = panes.open(@main, command: %w[gh dash], row: ROW, placement: :unlisted)

    assert_equal("t61", opened)
    assert_empty(closed_panes)
    assert_empty(calls.select { |call| call.first(3) == %w[hc get t61] })
  end

  def test_open_waits_until_hc_shows_an_agent
    shell = terminal("new", cwd: @cwd)
    @world["new_terminal"] = [ shell, shell, terminal("new", cwd: @cwd, status: agent("working")) ]

    opened = panes.open(@cwd, command: [ "claude" ])

    assert_equal("t61", opened)
    assert_operator(calls.count { |call| call.first(3) == %w[hc get t61] }, :>=, 3)
    assert_includes(listed_panes, "p61")
  end

  def test_failed_start_closes_the_pane_and_drops_its_record_line
    write_record("t11")
    @world["new_terminal"] = [ terminal("new", cwd: @cwd) ]

    assert_raises(HerdrAppPane::Refusal) { panes.open(@cwd, command: [ "claude" ], row: ROW) }

    assert_equal(%w[p61], closed_panes)
    refute_includes(listed_panes, "p61")
    assert_equal(%w[t11], record)
  end

  def test_open_gives_focus_back_when_the_split_took_it
    panes.open(@cwd, command: [ "claude" ])

    assert_equal([ { "pane" => "p11" } ], actions("pane.focus"))
    assert_equal("p11", @world[HerdrAppHarness::FOCUS_KEY])
  end

  private

  # A login shell that records its arguments and the folder it started in.
  def shell_stub(log)
    path = File.join(@main, "login-shell")
    File.write(path, "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{log.inspect}\npwd -P >> #{log.inspect}\n")
    FileUtils.chmod(0o755, path)
    path
  end
end

class HerdrAppPanesCloseTest < Minitest::Test
  include PanesTestSupport

  def setup
    super
    add_agent("t61", "p61", "working")
    add_agent("t62", "p62", "working")
  end

  def test_close_closes_the_pane_of_the_own_terminal
    panes(own: "t61").close

    assert_equal(%w[p61], closed_panes)
    assert_equal(%w[p10 p11 p62], listed_panes)
  end

  def test_close_closes_the_pane_of_a_given_terminal
    panes.close("t62")

    assert_equal(%w[p62], closed_panes)
    assert_equal(%w[p10 p11 p61], listed_panes)
  end
end

class HerdrAppPanesCloseIdleTest < Minitest::Test
  include PanesTestSupport

  def test_close_idle_warns_and_answers_0_when_herdr_app_fails
    write_record("t20")
    add_agent("t20", "p20", "idle")
    @world["fail"] = { "herdr-app ls" => "herdr-app: no window is running" }
    closed = nil

    _, stderr = capture_io { closed = panes.close_idle(ROW) }

    assert_equal(0, closed)
    assert_match(/no window is running/, stderr)
    assert_empty(closed_panes)
  end

  def test_close_idle_closes_nothing_when_the_space_id_is_ambiguous
    list_space_id_on_two_machines
    write_record("t20")
    closed = nil

    _, stderr = capture_io { closed = panes.close_idle(ROW) }

    assert_equal(0, closed)
    assert_match(/sp0/, stderr)
    assert_empty(closed_panes)
  end

  def test_close_idle_leaves_working_blocked_and_unreadable_panes_open
    add_agent("t22", "p22", "working")
    add_agent("t23", "p23", "blocked", app: "codex")
    add_agent("t24", "p24", nil)
    add_terminal(@world, terminal_row("t25", "p25", status: "idle"), terminal("t25", cwd: @main))
    write_record("t22", "t23", "t24", "t25")

    assert_equal(0, panes.close_idle(ROW))
    assert_empty(closed_panes)
  end

  def test_close_idle_keeps_own_coordinator_and_intent_terminals
    add_agent("t12", "p12", "idle")
    add_agent("t20", "p20", "done")
    add_agent("t26", "p26", "idle")
    write_record("t26", "t10", "t12", "t20")
    File.write(File.join(@common_dir, "herdr-app", "intent-pane-#{ROW}"), "t26\n")

    assert_equal(1, panes(own: "t12", coordinator: "t10").close_idle(ROW))
    assert_equal(%w[p20], closed_panes)
  end

  def test_close_idle_closes_idle_and_done_agents
    add_agent("t20", "p20", "idle")
    add_agent("t21", "p21", "done", app: "codex")
    add_agent("t22", "p22", "working")
    write_record("t20", "t21", "t22")

    assert_equal(2, panes.close_idle(ROW))
    assert_equal(%w[p20 p21], closed_panes.sort)
    assert_includes(listed_panes, "p22")
  end

  def test_close_idle_deletes_the_record
    add_agent("t20", "p20", "idle")
    write_record("t20")

    panes.close_idle(ROW)

    refute_path_exists(record_path)
  end
end

class HerdrAppPanesCloseAtTest < Minitest::Test
  include PanesTestSupport

  def test_close_at_leaves_agent_panes_open
    add_agent("t14", "p14", "idle", cwd: @cwd)
    add_agent("t15", "p15", "done", app: "codex", cwd: @cwd)

    assert_equal(0, panes.close_at(@cwd))
    assert_empty(closed_panes)
  end

  def test_close_at_compares_real_paths
    link = File.join(@main, "link-to-worktree")
    File.symlink(@cwd, link)
    add_shell("t12", "p12", cwd: @main, foreground_cwd: File.realpath(@cwd))
    add_shell("t13", "p13", cwd: link, foreground_cwd: nil)

    assert_equal(2, panes.close_at(link))
    assert_equal(%w[p12 p13], closed_panes.sort)
  end

  def test_close_at_closes_shells_at_cwd_only
    add_shell("t12", "p12", cwd: @main, foreground_cwd: @cwd)
    add_shell("t13", "p13", cwd: @cwd, foreground_cwd: @main)

    assert_equal(1, panes.close_at(@cwd))
    assert_equal(%w[p12], closed_panes)
  end
end

# CommandLine runs stub executables; HERDR_APP_BIN and HC_BIN name them, and the stub folder comes first on
# PATH, so a fallback to PATH finds a stub too, never the real herdr-app or hc.
class HerdrAppCommandLineTest < Minitest::Test
  SAVED = %w[HERDR_APP_BIN HC_BIN PATH].freeze

  def setup
    @saved_env = ENV.to_h.slice(*SAVED)
    @bin = Dir.mktmpdir("command-line-stubs")
    ENV["PATH"] = "#{@bin}:#{ENV.fetch('PATH')}"
    ENV["HERDR_APP_BIN"] = stub("herdr-app", stdout: '{"from":"path"}')
    ENV["HC_BIN"] = stub("hc", stdout: '{"from":"path"}')
  end

  def teardown
    SAVED.each { |name| ENV[name] = @saved_env[name] }
    FileUtils.rm_rf(@bin)
  end

  def test_json_raises_refusal_on_a_failure_an_error_answer_and_unparsable_output
    {
      { stderr: "herdr-app: no window is running", exit: 1 } => /no window is running/,
      { stdout: '{"error":"no pane \"p9\""}', exit: 1 } => /no pane "p9"/,
      { stdout: '{"error":"pane p9 is zoomed"}' } => /zoomed/,
      { stdout: "not json at all" } => /JSON/i
    }.each_with_index do |(answer, reason), index|
      ENV["HERDR_APP_BIN"] = stub("app-#{index}", **answer)

      error = assert_raises(HerdrAppPane::Refusal) { HerdrAppPane::CommandLine.new.json("herdr-app", "ls") }

      assert_match(reason, error.message)
    end
  end

  def test_json_answers_parsed_json
    ENV["HERDR_APP_BIN"] = stub("app", stdout: JSON.generate(spaces: []))

    assert_equal({ "spaces" => [] }, HerdrAppPane::CommandLine.new.json("herdr-app", "ls"))
  end

  def test_json_honours_herdr_app_bin_and_hc_bin
    ENV["HERDR_APP_BIN"] = echo_stub("elsewhere-app", "app")
    ENV["HC_BIN"] = echo_stub("elsewhere-hc", "hc")
    command_line = HerdrAppPane::CommandLine.new

    assert_equal({ "from" => "app", "argv" => %w[ls] }, command_line.json("herdr-app", "ls"))
    assert_equal({ "from" => "hc", "argv" => %w[get t10 --json] }, command_line.json("hc", "get", "t10", "--json"))
  end

  private

  def stub(name, stdout: "", stderr: "", exit: 0)
    path = File.join(@bin, name)
    File.write(path, "#!/bin/sh\nprintf '%s' #{stdout.shellescape}\nprintf '%s' #{stderr.shellescape} >&2\nexit #{exit}\n")
    FileUtils.chmod(0o755, path)
    path
  end

  # Answers its own label and arguments.
  def echo_stub(name, label)
    path = File.join(@bin, name)
    File.write(path, "#!/usr/bin/env -S ruby --disable-gems\nrequire \"json\"\nputs JSON.generate(from: #{label.inspect}, argv: ARGV)\n")
    FileUtils.chmod(0o755, path)
    path
  end
end

# Among the pipeline files, only panes.rb sends `herdr-app ls` or `herdr-app do`, so a change in herdr-app's
# answers touches one file.
class HerdrAppCommandOwnerTest < Minitest::Test
  ROOT = HerdrAppHarness::REPO_ROOT
  PANES = File.join(HerdrAppHarness::PANE_LIBRARY, "panes.rb")
  SENDS = /herdr-app"?,?\s+"?(ls|do)\b/

  def test_only_panes_rb_sends_herdr_app_commands
    assert_match(SENDS, File.read(PANES))

    senders = pipeline_files.reject { |path| path == PANES }.select { |path| File.read(path).match?(SENDS) }

    assert_empty(senders.map { |path| path.delete_prefix("#{ROOT}/") })
  end

  private

  def pipeline_files
    patterns = %w[
      herdr-app/.config/herdr-app/scripts/*.sh herdr-app/.local/bin/herdr-app-pane herdr-app/.local/share/herdr-app-pane/*.rb
      agents/.agents/bin/hand-off-plan agents/.agents/bin/start-review agents/.agents/bin/open-pr-dash
      agents/.agents/skills/deliver/scripts/deliver git/.config/git/worktree-tools/worktree-pane
      git/.config/git/worktree-tools/lib/common.rb rex/.config/rex/scripts/play-tone.sh
    ]
    patterns.flat_map { |pattern| Dir.glob(File.join(ROOT, pattern)) }
  end
end
