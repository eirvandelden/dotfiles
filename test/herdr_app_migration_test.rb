#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"
require_relative "isolated_git"

LIBRARY = File.expand_path("../herdr-app/.local/share/herdr-app-migrate", __dir__)
%w[command_line agent_session layout workspace machine tui_session stale_spaces].each { |name| require File.join(LIBRARY, name) }

# The objects behind herdr-app-migrate, with a fake command line that answers canned JSON and logs every
# call. Names, sessions and folders are invented. No test reaches a real herdr or herdr-app.
class FakeCommandLine
  attr_reader :calls

  def initialize(&answers)
    @answers = answers
    @calls = []
  end

  def json(*command)
    @calls << command
    @answers.call(command) || raise(HerdrAppMigration::Refusal, "no canned answer for #{command.join(' ')}")
  end
end

module MigrationFixtures
  Rect = ->(x, y, width, height) { { "x" => x, "y" => y, "width" => width, "height" => height } }

  def agent(kind, id, cwd = "/work/api")
    HerdrAppMigration::AgentSession.new(kind, id, cwd)
  end

  def tab(name, panes, rects, folder: "/work/api")
    layout = HerdrAppMigration::Layout.new(panes.zip(rects), label: name)
    HerdrAppMigration::Tab.new(name, folder, panes.map { |id| HerdrAppMigration::Pane.new(id, folder) }, layout)
  end

  def single_tab(name = "main", pane = "w1:p1")
    tab(name, [ pane ], [ Rect.(0, 0, 100, 40) ])
  end

  def workspace(name = "api", tabs = [ single_tab ])
    HerdrAppMigration::Workspace.new(name, "/work/api", tabs)
  end

  # herdr-app ls with the spaces given as [name, machine]; each space holds tab<index> with terminal t1 as
  # pane p-tab<index>. A tab made later is listed under its own id with pane p-<tab id>.
  def listing(*spaces, extra_tabs: {})
    rows = spaces.each_with_index.map do |(name, machine), index|
      tabs = [ "tab#{index}", *extra_tabs.fetch("sp#{index}", []) ]
      { "id" => "sp#{index}", "name" => name, "folder" => "/x", "machine" => machine,
        "tabs" => tabs.map { |tab| tab_row(tab) } }
    end
    { "spaces" => rows, "recent" => [] }
  end

  def tab_row(tab)
    { "id" => tab, "name" => "one", "terminals" => [ { "terminal" => "t1", "pane" => "p-#{tab}", "status" => nil } ] }
  end

  # A herdr-app that numbers what it creates and lists it afterwards.
  def app_double(existing = [])
    state = { spaces: existing.dup, tabs: Hash.new { |hash, key| hash[key] = [] }, count: 0 }
    FakeCommandLine.new { |command| app_answer(command, state) }
  end

  def app_answer(command, state)
    return listing(*state[:spaces], extra_tabs: state[:tabs]) if command[1] == "ls"

    arguments = JSON.parse(command.last)
    state[:count] += 1
    case command[2]
    when "space.new"
      state[:spaces] << [ arguments["name"], arguments["machine"].to_s.empty? ? nil : arguments["machine"] ]
      index = state[:spaces].size - 1
      { "space" => "sp#{index}", "tab" => "tab#{index}", "terminal" => "t1" }
    when "tab.new"
      state[:tabs][arguments["space"]] << "tab-new#{state[:count]}"
      { "space" => arguments["space"], "tab" => "tab-new#{state[:count]}", "terminal" => "t1" }
    when "pane.split" then { "pane" => "p-split#{state[:count]}", "terminal" => "t#{state[:count]}" }
    end
  end
end

class HerdrAppAgentSessionTest < Minitest::Test
  include MigrationFixtures

  def test_a_claude_session_resumes_by_id_in_its_folder
    argv = agent("claude", "abc-123", "/work/api").resume_argv

    assert_equal([ "sh", "-c" ], argv.first(2))
    assert_equal([ "sh", "/work/api", "claude", "--resume", "abc-123" ], argv.drop(3))
  end

  def test_a_codex_session_resumes_by_id_in_its_folder
    assert_equal([ "sh", "/work/api", "codex", "resume", "def-456" ], agent("codex", "def-456").resume_argv.drop(3))
  end

  def test_an_unknown_kind_is_refused
    assert_raises(HerdrAppMigration::Refusal) { agent("gemini", "x").resume_argv }
  end

  def test_the_resume_runs_inside_a_login_interactive_shell
    assert_includes(run_wrapper("claude").first, "-l -i -c")
  end

  def test_the_resume_keeps_a_shell_after_the_agent_exits
    log = run_wrapper("claude").first

    assert_includes(log, "exec-login-shell")
  end

  def test_a_missing_folder_exits_non_zero
    argv = agent("claude", "abc", "/no/such/folder").resume_argv
    _stdout, _stderr, status = Open3.capture3(*argv)

    refute_predicate(status, :success?)
  end

  def test_a_failed_resume_prints_one_line
    stdout = run_wrapper("claude", agent_exit: 3).last

    assert_equal("herdr-app-migrate: claude exited 3\n", stdout)
  end

  def test_a_folder_with_quotes_and_dollars_stays_one_argument
    Dir.mktmpdir("resume-cwd") do |directory|
      odd = File.join(directory, %(it's "$HOME" `x`))
      Dir.mkdir(odd)
      log, = run_wrapper("claude", folder: odd)

      assert_includes(log, "claude --resume abc")
    end
  end

  private

  # Runs the real wrapper with SHELL set to a stub that records its arguments and, for -c, evaluates the
  # script with a stub `claude` first on PATH. Returns the stub's log and the wrapper's stdout.
  def run_wrapper(kind, agent_exit: 0, folder: Dir.pwd)
    Dir.mktmpdir("resume") do |directory|
      log = File.join(directory, "shell.log")
      bin = File.join(directory, "bin")
      Dir.mkdir(bin)
      stub(File.join(bin, "claude"), "exit #{agent_exit}")
      shell = stub(File.join(directory, "shell"), shell_body(log))
      stdout, = Open3.capture3({ "SHELL" => shell, "PATH" => "#{bin}:#{ENV.fetch('PATH')}" },
                               *agent(kind, "abc", folder).resume_argv)
      [ File.read(log), stdout ]
    end
  end

  def shell_body(log)
    <<~SH
      printf '%s\\n' "$*" >> "#{log}"
      case " $* " in *" -c "*) ;; *) echo exec-login-shell >> "#{log}"; exit 0;; esac
      shift 3
      script="$1"; shift
      exec /bin/sh -c "$script" "$@"
    SH
  end

  def stub(path, body)
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
    path
  end
end

class HerdrAppPaneTest < Minitest::Test
  include MigrationFixtures

  def test_a_plain_pane_gets_a_login_shell_in_its_folder
    argv = HerdrAppMigration::Pane.new("w1:p1", "/work/api").argv({})

    assert_equal([ "sh", "-c", HerdrAppMigration::Pane::SHELL_IN, "sh", "/work/api" ], argv)
  end

  def test_a_claude_pane_resumes_its_session_in_its_folder
    pane = HerdrAppMigration::Pane.new("w1:p1", "/work/api")

    assert_equal([ "claude", "--resume", "abc" ], pane.argv("w1:p1" => agent("claude", "abc")).last(3))
  end

  def test_a_codex_pane_resumes_its_session_in_its_folder
    pane = HerdrAppMigration::Pane.new("w1:p1", "/work/api")

    assert_equal([ "codex", "resume", "def" ], pane.argv("w1:p1" => agent("codex", "def")).last(3))
  end

  def test_a_folder_with_quotes_and_dollars_stays_one_argument
    odd = %(/work/it's "$HOME" `x`)

    assert_equal(odd, HerdrAppMigration::Pane.new("w1:p1", odd).argv({}).last)
  end
end

class HerdrAppLayoutTest < Minitest::Test
  include MigrationFixtures

  def steps(rects, ids = %w[A B C D].first(rects.size))
    HerdrAppMigration::Layout.new(ids.zip(rects)).steps.map { |step| [ step.from, step.to, step.direction ] }
  end

  def test_one_pane_needs_no_split
    assert_empty(steps([ Rect.(0, 0, 100, 40) ]))
  end

  def test_two_columns_split_right
    assert_equal([ %w[A B right] ], steps([ Rect.(0, 0, 50, 40), Rect.(50, 0, 50, 40) ]))
  end

  def test_two_rows_split_down
    assert_equal([ %w[A B down] ], steps([ Rect.(0, 0, 100, 20), Rect.(0, 20, 100, 20) ]))
  end

  def test_a_two_by_two_tab_splits_in_tree_order
    rects = [ Rect.(0, 0, 50, 20), Rect.(50, 0, 50, 20), Rect.(0, 20, 50, 20), Rect.(50, 20, 50, 20) ]

    assert_equal([ %w[A B right], %w[A C down], %w[B D down] ], steps(rects))
  end

  def test_an_l_shape_splits_in_tree_order
    rects = [ Rect.(0, 0, 50, 20), Rect.(0, 20, 50, 20), Rect.(50, 0, 50, 40) ]

    assert_equal([ %w[A C right], %w[A B down] ], steps(rects))
  end

  def test_reordered_panes_anchor_by_geometry
    layout = HerdrAppMigration::Layout.new([ [ "right", Rect.(50, 0, 50, 40) ], [ "left", Rect.(0, 0, 50, 40) ] ])

    assert_equal("left", layout.anchor)
    assert_equal([ %w[left right right] ], layout.steps.map { |step| [ step.from, step.to, step.direction ] })
  end

  def test_overlapping_rectangles_are_refused
    error = assert_raises(HerdrAppMigration::Refusal) do
      HerdrAppMigration::Layout.new([ [ "A", Rect.(0, 0, 60, 40) ], [ "B", Rect.(50, 0, 50, 40) ] ], label: "logs")
    end

    assert_includes(error.message, "logs")
  end

  def test_a_missing_rectangle_is_refused
    assert_raises(HerdrAppMigration::Refusal) { HerdrAppMigration::Layout.new([ [ "A", nil ] ], label: "logs") }
  end

  def test_a_region_without_a_clean_cut_is_refused
    pinwheel = [ Rect.(0, 0, 60, 20), Rect.(60, 0, 40, 40), Rect.(40, 40, 60, 20), Rect.(0, 20, 40, 40) ]
    layout = HerdrAppMigration::Layout.new(%w[A B C D].zip(pinwheel), label: "pin")

    assert_raises(HerdrAppMigration::Refusal) { layout.steps }
  end
end

class HerdrAppMachineTest < Minitest::Test
  include MigrationFixtures

  def test_the_space_lands_on_the_named_machine
    command_line = app_double
    HerdrAppMigration::Machine.new("work", command_line: command_line)
                              .new_space(name: "api", folder: "/w", tab: "main", argv: [ "sh" ])

    assert_equal("work", JSON.parse(command_line.calls.find { |call| call[2] == "space.new" }.last)["machine"])
  end

  def test_this_computer_is_the_empty_machine
    machine = HerdrAppMigration::Machine.new("", command_line: app_double([ [ "api", nil ], [ "ops", "work" ] ]))

    assert(machine.space?("api"))
    refute(machine.space?("ops"))
  end

  def test_a_name_built_in_this_run_is_not_built_again
    machine = HerdrAppMigration::Machine.new("", command_line: app_double)
    machine.new_space(name: "api", folder: "/w", tab: "main", argv: [ "sh" ])

    assert(machine.space?("api"))
  end

  def test_each_create_answers_its_space_tab_pane_and_terminal
    machine = HerdrAppMigration::Machine.new("", command_line: app_double)
    space = machine.new_space(name: "api", folder: "/w", tab: "main", argv: [ "sh" ])
    split = machine.split(pane: space.pane, direction: "right", argv: [ "sh" ])

    assert_equal(%w[sp0 tab0 p-tab0 t1], space.to_h.values_at(:space, :tab, :pane, :terminal))
    assert_match(/\Ap-split/, split.pane)
  end

  def test_a_reply_without_a_pane_id_is_refused
    command_line = FakeCommandLine.new { |command| command[2] == "pane.split" ? { "terminal" => "t2" } : listing }
    machine = HerdrAppMigration::Machine.new("", command_line: command_line)

    assert_raises(HerdrAppMigration::Refusal) { machine.split(pane: "p", direction: "right", argv: [ "sh" ]) }
  end

  def test_a_terminal_missing_from_the_listing_is_refused
    command_line = FakeCommandLine.new do |command|
      command[2] == "space.new" ? { "space" => "s", "tab" => "t", "terminal" => "t9" } : listing
    end
    machine = HerdrAppMigration::Machine.new("", command_line: command_line)

    assert_raises(HerdrAppMigration::Refusal) { machine.new_space(name: "a", folder: "/", tab: "m", argv: [ "sh" ]) }
  end
end

class HerdrAppWorkspaceTest < Minitest::Test
  include MigrationFixtures

  def migrate(workspace, machine_name: "", existing: [], agents: {})
    command_line = app_double(existing)
    pairings = workspace.migrate_to(HerdrAppMigration::Machine.new(machine_name, command_line: command_line), agents)
    [ pairings, command_line.calls.reject { |call| call[1] == "ls" } ]
  end

  def test_a_workspace_becomes_a_space_with_its_name_and_folder
    _pairings, calls = migrate(workspace)
    arguments = JSON.parse(calls.first.last)

    assert_equal("space.new", calls.first[2])
    assert_equal(%w[api /work/api main], arguments.values_at("name", "folder", "tab"))
  end

  def test_each_further_tab_goes_into_the_created_space
    tabs = [ single_tab("one", "w1:p1"), single_tab("two", "w1:p2") ]
    _pairings, calls = migrate(workspace("api", tabs))
    second = JSON.parse(calls.last.last)

    assert_equal("tab.new", calls.last[2])
    assert_equal(%w[sp0 two], second.values_at("space", "name"))
  end

  def test_a_plain_pane_gets_a_login_shell_in_its_folder
    _pairings, calls = migrate(workspace)

    assert_equal(HerdrAppMigration::Pane::SHELL_IN, JSON.parse(calls.first.last)["argv"][2])
  end

  def test_each_pairing_names_the_tui_pane_and_the_app_pane
    tabs = [ tab("main", %w[w1:p1 w1:p2], [ Rect.(0, 0, 50, 40), Rect.(50, 0, 50, 40) ]) ]
    pairings, = migrate(workspace("api", tabs))

    assert_equal([ %w[w1:p1 p-tab0], %w[w1:p2 p-split2] ], pairings.map { |pairing| [ pairing.tui_pane, pairing.app_pane ] })
    assert_equal("api\tmain\tw1:p1\tp-tab0\tshell", pairings.first.to_s)
  end

  def test_a_pairing_says_started_not_resumed
    pairings, = migrate(workspace, agents: { "w1:p1" => agent("claude", "abc") })

    assert_equal("api\tmain\tw1:p1\tp-tab0\tclaude abc started", pairings.first.to_s)
  end

  def test_a_workspace_whose_name_is_a_space_is_skipped
    pairings, calls = migrate(workspace, existing: [ [ "api", nil ] ])

    assert_empty(pairings)
    assert_empty(calls)
  end

  def test_a_failed_split_names_the_incomplete_space
    tabs = [ tab("main", %w[w1:p1 w1:p2], [ Rect.(0, 0, 50, 40), Rect.(50, 0, 50, 40) ]) ]
    command_line = FakeCommandLine.new do |command|
      next listing([ "listed-by-the-fake", nil ]) if command[1] == "ls"

      command[2] == "space.new" ? { "space" => "sp0", "tab" => "tab0", "terminal" => "t1" } : raise(HerdrAppMigration::Refusal, "split failed")
    end
    error = assert_raises(HerdrAppMigration::Refusal) do
      workspace("api", tabs).migrate_to(HerdrAppMigration::Machine.new("", command_line: command_line), {})
    end

    assert_match(/space api \(sp0\) is incomplete/, error.message)
  end

  def test_the_preview_lists_tabs_splits_and_start_commands
    tabs = [ tab("main", %w[w1:p1 w1:p2], [ Rect.(0, 0, 50, 40), Rect.(50, 0, 50, 40) ]) ]
    preview = workspace("api", tabs).preview("w1:p2" => agent("codex", "def"))

    assert_equal(<<~TEXT.chomp, preview)
      space api (/work/api)
      tab main
        split pane 1 right -> pane 2
        pane 1: login shell in /work/api
        pane 2: codex session def in /work/api
    TEXT
  end
end

class HerdrAppTuiSessionTest < Minitest::Test
  include MigrationFixtures

  def session
    @command_line = FakeCommandLine.new { |command| tui_answer(command.drop(3)) }
    HerdrAppMigration::TuiSession.new("tui1", command_line: @command_line)
  end

  def tui_answer(words)
    result = case words
    in [ "workspace", "list" ] then { "workspaces" => [ { "workspace_id" => "w1", "label" => "api" } ] }
    in [ "tab", "list", "--workspace", "w1" ] then { "tabs" => [ { "tab_id" => "w1:t1", "label" => "main" } ] }
    in [ "pane", "list", "--workspace", "w1" ] then { "panes" => panes }
    in [ "pane", "layout", "--pane", _ ] then { "layout" => { "panes" => rects } }
    in [ "agent", "list" ] then { "agents" => agents }
    end
    { "id" => "x", "result" => result }
  end

  def panes
    [ { "pane_id" => "w1:p1", "tab_id" => "w1:t1", "cwd" => "/work/api" },
      { "pane_id" => "w1:p2", "tab_id" => "w1:t1", "cwd" => "/work/api/lib" } ]
  end

  def rects
    [ { "pane_id" => "w1:p1", "rect" => Rect.(0, 0, 50, 40) }, { "pane_id" => "w1:p2", "rect" => Rect.(50, 0, 50, 40) } ]
  end

  def agents
    [ { "agent" => "claude", "pane_id" => "w1:p1", "cwd" => "/work/api", "agent_session" => { "kind" => "id", "value" => "abc" } },
      { "agent" => "codex", "pane_id" => "w1:p2", "cwd" => "/work/api/lib", "agent_session" => { "kind" => "id", "value" => "def" } },
      { "agent" => "codex", "pane_id" => "w1:p3", "cwd" => "/x", "agent_session" => { "kind" => "last" } },
      { "agent" => "pi", "pane_id" => "w1:p4", "cwd" => "/x", "agent_session" => { "kind" => "id", "value" => "zzz" } } ]
  end

  def test_workspaces_come_in_tui_order_with_their_folders
    workspace = session.workspaces.first

    assert_equal(%w[api /work/api main], [ workspace.name, workspace.folder, workspace.tabs.first.name ])
    assert_equal(%w[w1:p1 w1:p2], workspace.tabs.first.panes.map(&:id))
  end

  def test_running_agents_hold_only_claude_and_codex_with_a_session
    assert_equal(%w[w1:p1 w1:p2], session.running_agents.keys)
    assert_equal("abc", session.running_agents["w1:p1"].id)
  end

  def test_the_session_name_reaches_every_herdr_call
    session.tap(&:workspaces).tap(&:running_agents)

    assert(@command_line.calls.all? { |call| call.first(3) == %w[herdr --session tui1] })
  end

  def test_only_read_requests_are_sent
    session.tap(&:workspaces).tap(&:running_agents)
    verbs = @command_line.calls.map { |call| call.drop(3).reject { |word| word.start_with?("--", "w1") } }

    assert(verbs.all? { |words| %w[list layout].include?(words.last) || words.last == "-pane" || words.size == 2 })
    assert(verbs.none? { |words| (words & %w[new close kill split send run create focus]).any? })
  end
end

class HerdrAppCommandLineTest < Minitest::Test
  def test_a_failed_command_raises_a_refusal_with_its_stderr
    error = assert_raises(HerdrAppMigration::Refusal) { HerdrAppMigration::CommandLine.new.json("sh", "-c", "echo boom >&2; exit 2") }

    assert_includes(error.message, "boom")
  end

  def test_an_error_answer_raises_a_refusal
    error = assert_raises(HerdrAppMigration::Refusal) do
      HerdrAppMigration::CommandLine.new.json("sh", "-c", %(echo '{"error":"no space"}'))
    end

    assert_includes(error.message, "no space")
  end

  def test_a_missing_command_raises_a_refusal
    assert_raises(HerdrAppMigration::Refusal) { HerdrAppMigration::CommandLine.new.json("no-such-herdr-command") }
  end

  def test_an_answer_that_is_not_json_raises_a_refusal
    assert_raises(HerdrAppMigration::Refusal) { HerdrAppMigration::CommandLine.new.json("echo", "plain") }
  end

  def test_a_good_answer_is_parsed
    assert_equal({ "ok" => true }, HerdrAppMigration::CommandLine.new.json("echo", '{"ok":true}'))
  end
end

class HerdrAppStaleSpacesTest < Minitest::Test
  include MigrationFixtures

  def stale(machine, answer)
    @command_line = FakeCommandLine.new { |command| command[1] == "ls" ? answer : { "ok" => true } }
    HerdrAppMigration::StaleSpaces.new(machine, command_line: @command_line)
  end

  def test_the_listing_shows_only_the_machines_live_spaces
    lines = stale("", listing([ "api", nil ], [ "ops", "work" ])).listing

    assert_equal([ "sp0\tapi\t/x\t1\t1\t" ], lines)
  end

  def test_recent_entries_are_not_listed
    answer = listing.merge("recent" => [ { "name" => "old", "folder" => "/old" } ])

    assert_equal([ "no spaces" ], stale("", answer).listing)
  end

  def test_an_empty_listing_says_no_spaces
    assert_equal([ "no spaces" ], stale("work", listing).listing)
  end

  def test_close_refuses_an_unlisted_id_before_closing_any
    stale = stale("", listing([ "api", nil ]))

    assert_raises(HerdrAppMigration::Refusal) { stale.close(%w[sp0 nope]) }
    assert_empty(@command_line.calls.select { |call| call[2] == "space.close" })
  end

  def test_close_confirms_each_approved_id
    stale("", listing([ "a", nil ], [ "b", nil ])).close(%w[sp0 sp1])
    closes = @command_line.calls.select { |call| call[2] == "space.close" }

    assert_equal([ { "id" => "sp0", "confirmed" => true }, { "id" => "sp1", "confirmed" => true } ], closes.map { |call| JSON.parse(call.last) })
  end
end

class HerdrAppBuildSendsNoClosingCommandTest < Minitest::Test
  include MigrationFixtures

  def test_build_sends_no_closing_or_tui_changing_command
    command_line = app_double
    machine = HerdrAppMigration::Machine.new("", command_line: command_line)
    workspace("api").migrate_to(machine, { "w1:p1" => agent("claude", "abc") })

    commands = command_line.calls.select { |call| call[1] == "do" }.map { |call| call[2] }
    assert_empty(commands - %w[space.new tab.new pane.split])
    refute_respond_to(machine, :close)
  end
end
