#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "tmpdir"
require_relative "herdr_app_agents_harness"
require_relative "isolated_git"
require "#{HerdrAppAgentsHarness::LIBRARY}/session_start"
require "#{HerdrAppAgentsHarness::LIBRARY}/shutdown"

# The public methods of the herdr-app-agents library. test/herdr_app_agents_cli_test.rb runs the executable.
class HerdrAppAgentsTest < Minitest::Test
  include HerdrAppAgentsHarness
  include HerdrAppAgentsHarness::Fixtures
  include HerdrAppAgents

  NOW = Time.utc(2026, 11, 13, 12, 0, 0)
  PANE = { "HC_TERMINAL_ID" => "t5", "HC_TERMINAL_SOCKET" => "/s/default/default.sock",
           "CLAUDE_CODE_ENTRYPOINT" => "cli" }.freeze

  # Answers hc json calls from a Hash of command => answer, and text calls with a Refusal or a canned string.
  class FakeCommandLine
    attr_reader :calls

    def initialize(answers = {})
      @answers = answers
      @calls = []
    end

    def json(*command)
      @calls << command
      answer = @answers.fetch(command) { raise HerdrAppAgents::Refusal, "no answer for #{command.inspect}" }
      raise answer if answer.is_a?(Exception)

      answer
    end

    def text(*command)
      @calls << command
      answer = @answers.fetch(command, "")
      raise answer if answer.is_a?(Exception)

      answer
    end
  end

  def setup
    @dir = Dir.mktmpdir("agents-unit")
    @store = RecordStore.new(root: File.join(@dir, "agents"))
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- CommandLine ---

  def test_command_line_json_sets_hc_session_for_a_core
    script = executable("hc", %(#!/bin/sh\necho "{\\"session\\":\\"$HC_SESSION\\"}"\n))
    with_env("HC_BIN" => script) do
      assert_equal({ "session" => "work" }, CommandLine.new(core: "work").json("hc", "x"))
    end
  end

  def test_command_line_json_refuses_an_error_answer
    script = executable("hc", %(#!/bin/sh\necho '{"error":"nope"}'\n))
    with_env("HC_BIN" => script) do
      assert_raises(Refusal) { CommandLine.new.json("hc", "x") }
    end
  end

  def test_command_line_text_refuses_a_non_zero_exit
    script = executable("hc", "#!/bin/sh\necho boom >&2\nexit 3\n")
    with_env("HC_BIN" => script) do
      error = assert_raises(Refusal) { CommandLine.new.text("hc", "x") }
      assert_match(/boom/, error.message)
    end
  end

  # --- Core and TerminalState ---

  def test_core_of_socket_names_the_core_from_its_socket
    assert_equal("work", Core.of_socket("/s/herdr-core/work/work.sock").name)
  end

  def test_core_of_socket_refuses_an_odd_socket_path
    [ nil, "", "/s/work.sock", "/s/a/b.sock", "/s/../../..sock", "/s/A/A.sock", "/s/a/a.socket" ].each do |path|
      assert_raises(Refusal, path.inspect) { Core.of_socket(path) }
    end
  end

  def test_core_running_asks_the_socket_not_hc
    state = Dir.mktmpdir("agents-sock", "/tmp")
    with_env("XDG_STATE_HOME" => state) do
      refute(Core.new("work").running?)
      FileUtils.mkdir_p(File.join(state, "herdr-core/work"))
      server = UNIXServer.new(File.join(state, "herdr-core/work/work.sock"))
      assert(Core.new("work").running?)
      server.close
      refute(Core.new("work").running?)
    end
  ensure
    FileUtils.rm_rf(state)
  end

  def test_core_started_at_subtracts_uptime_ms
    line = FakeCommandLine.new([ "hc", "server", "status", "--json" ] => { "uptime_ms" => 90_000 })

    assert_equal(NOW - 90, Core.new("default", command_line: line).started_at(NOW))
  end

  def test_core_started_at_refuses_an_answer_without_uptime
    line = FakeCommandLine.new([ "hc", "server", "status", "--json" ] => {})

    assert_raises(Refusal) { Core.new("default", command_line: line).started_at(NOW) }
  end

  def test_core_resume_types_only_into_a_bare_shell
    line = FakeCommandLine.new([ "hc", "get", "t5", "--json" ] => agent("t5", %w[claude]))

    refute(Core.new("default", command_line: line).resume(record, store: @store, now: NOW))
    assert_empty(line.calls.select { |call| call[1] == "send" })
  end

  def test_core_resume_writes_resumed_at_after_a_successful_send
    line = FakeCommandLine.new([ "hc", "get", "t5", "--json" ] => shell("t5"))

    assert(Core.new("default", command_line: line).resume(record, store: @store, now: NOW))
    assert_includes(line.calls, [ "hc", "send", "t5", record.resume_line ])
    assert_equal(NOW, @store.records.first.resumed_at)
  end

  def test_core_resume_writes_nothing_when_the_send_is_refused
    line = FakeCommandLine.new([ "hc", "get", "t5", "--json" ] => shell("t5"),
                               [ "hc", "send", "t5", record.resume_line ] => Refusal.new("busy"))

    refute(Core.new("default", command_line: line).resume(record, store: @store, now: NOW))
    assert_empty(@store.records)
  end

  def test_terminal_state_bare_shell_refuses_an_agent_a_child_process_and_a_missing_field
    child = shell("t5").merge("foreground" => { "pid" => 9, "argv" => [ "vim" ], "cwd" => "/tmp" })
    agent_running = agent("t5", %w[claude])

    [ agent_running, child, shell("t5").except("pid"), shell("t5").merge("state" => "dead"), nil, "x" ].each do |answer|
      refute_predicate(TerminalState.new(answer), :bare_shell?, answer.inspect)
    end
  end

  def test_terminal_state_bare_shell_accepts_a_shell_in_another_folder
    assert_predicate(TerminalState.new(shell("t5", cwd: "/elsewhere")), :bare_shell?)
  end

  def test_terminal_state_interactive_refuses_codex_exec
    codex = ->(*argv) { TerminalState.new(agent("t5", [ "codex", *argv ], app: "codex")) }

    assert(codex.call("-s", "read-only").interactive?("codex"))
    refute(codex.call("exec", "fix").interactive?("codex"))
    refute(codex.call("-s", "read-only", "e", "fix").interactive?("codex"))
    assert(codex.call.interactive?("codex"))
  end

  # --- ProcessTable ---

  def test_process_table_spawned_by_passes_hook_runners_only
    rows = [ [ 10, 11, %w[ruby hook] ], [ 11, 12, %w[/bin/sh -c hook] ], [ 12, 1, %w[claude] ] ]

    assert(ProcessTable.new(rows).spawned_by?(10, 12))
    refute(ProcessTable.new(rows).spawned_by?(10, 99))
    refute(ProcessTable.new(rows).spawned_by?(12, 10))
  end

  def test_process_table_spawned_by_refuses_an_app_server_between
    rows = [ [ 10, 11, %w[ruby hook] ], [ 11, 12, %w[codex app-server] ], [ 12, 1, %w[codex] ] ]

    refute(ProcessTable.new(rows).spawned_by?(10, 12))
  end

  def test_process_table_running_finds_a_session_id_in_argv
    table = ProcessTable.new([ [ 1, 0, [ "claude", "--resume", CLAUDE_ID ] ] ])

    assert(table.running?(CLAUDE_ID))
    refute(table.running?(CODEX_ID))
  end

  def test_process_table_snapshot_calls_ps_once_and_only_when_asked
    line = FakeCommandLine.new([ "ps", "-A", "-ww", "-o", "pid=,ppid=,args=" ] => "7 1 claude --resume #{CLAUDE_ID}\nbad\n")
    table = ProcessTable.snapshot(command_line: line)

    assert_empty(line.calls)
    assert(table.running?(CLAUDE_ID))
    table.running?(CODEX_ID)
    assert_equal(1, line.calls.size)
  end

  # --- AgentRecord ---

  def test_flags_of_keeps_whitelisted_flags_only
    assert_equal(%w[--permission-mode plan --dangerously-skip-permissions],
                 AgentRecord.flags_of("claude", %w[claude --permission-mode=plan --model x --dangerously-skip-permissions]))
    assert_equal(%w[-s workspace-write -a never],
                 AgentRecord.flags_of("codex", %w[codex -s workspace-write --model x -a never]))
    assert_empty(AgentRecord.flags_of("claude", %w[claude --permission-mode $(rm) -s read-only]))
    assert_empty(AgentRecord.flags_of("other", %w[--dangerously-skip-permissions]))
  end

  def test_flags_of_keeps_the_manual_mode_and_the_approval_flags
    assert_equal(%w[--permission-mode manual --allow-dangerously-skip-permissions],
                 AgentRecord.flags_of("claude", %w[claude --permission-mode manual --allow-dangerously-skip-permissions]))
    assert_equal(%w[--approve-for-me], AgentRecord.flags_of("codex", %w[codex --approve-for-me --model x]))
  end

  def test_parse_refuses_each_bad_field
    good = record_hash
    { "kind" => "gemini", "session_id" => "x; ls", "core" => "../x", "terminal" => "t/../x", "cwd" => "relative",
      "transcript_path" => "/a\nb", "flags" => [ "--model", "x" ], "recorded_at" => "yesterday" }.each do |field, value|
      assert_raises(Refusal, field) { AgentRecord.parse(JSON.generate(good.merge(field => value))) }
    end
    assert_raises(Refusal) { AgentRecord.parse(JSON.generate(good.except("resumed_at"))) }
    assert_raises(Refusal) { AgentRecord.parse("[]") }
    assert_raises(Refusal) { AgentRecord.parse("{") }
  end

  def test_distinct_keeps_the_newest_per_session_and_none_on_a_tie
    old = record(terminal: "t1", recorded_at: NOW - 60)
    new = record(terminal: "t2", recorded_at: NOW)
    tie_a = record(terminal: "t3", session_id: CODEX_ID, recorded_at: NOW)
    tie_b = record(terminal: "t4", session_id: CODEX_ID, recorded_at: NOW)

    assert_equal([ new ], AgentRecord.distinct([ old, new, tie_a, tie_b ]))
  end

  def test_resume_line_quotes_a_cwd_with_a_space_and_a_quote
    line = record(cwd: %(/tmp/it's a dir)).resume_line

    assert_equal(%(cd /tmp/it\\'s\\ a\\ dir && claude --resume #{CLAUDE_ID}), line)
    assert_equal("cd /tmp/x && codex resume #{CODEX_ID} -a never",
                 record(kind: "codex", session_id: CODEX_ID, cwd: "/tmp/x", flags: %w[-a never]).resume_line)
  end

  def test_touched_since_reads_recorded_at_resumed_at_and_transcript_mtime
    assert(record(recorded_at: NOW).touched_since?(NOW))
    assert(record(recorded_at: NOW - 9, resumed_at: NOW).touched_since?(NOW))
    assert(record(recorded_at: NOW - 9, transcript_written_at: NOW).touched_since?(NOW))
    refute(record(recorded_at: NOW - 9, transcript_written_at: NOW - 1).touched_since?(NOW))
  end

  def test_to_json_round_trips_without_the_transcript_mtime
    original = record(transcript_written_at: NOW)
    parsed = AgentRecord.parse(original.to_json)

    assert_equal(original.with(transcript_written_at: nil).to_h, parsed.to_h)
    refute_includes(JSON.parse(original.to_json).keys, "transcript_written_at")
  end

  # --- RecordStore ---

  def test_record_store_write_is_atomic_and_keyed_by_core_and_terminal
    @store.write(record(session_id: CLAUDE_ID))
    @store.write(record(session_id: CODEX_ID, kind: "codex"))
    @store.write(record(core: "work"))

    path = File.join(@dir, "agents/default/t5.json")
    assert_equal(CODEX_ID, JSON.parse(File.read(path))["session_id"])
    assert_equal(0o600, File.stat(path).mode & 0o777)
    assert_equal(%w[t5.json], Dir.children(File.join(@dir, "agents/default")))
    assert_equal(2, @store.records.size)
  end

  def test_record_store_records_skips_an_unreadable_file_and_a_misplaced_one
    @store.write(record)
    FileUtils.mkdir_p(File.join(@dir, "agents/default"))
    File.write(File.join(@dir, "agents/default/t6.json"), "{")
    File.write(File.join(@dir, "agents/default/t7.json"), record.to_json)

    _stdout, stderr = capture_io { assert_equal([ "t5" ], @store.records.map(&:terminal)) }
    assert_match(/t6/, stderr)
    assert_match(/t7/, stderr)
  end

  def test_record_store_records_reads_the_transcript_mtime_once
    transcript = File.join(@dir, "log.jsonl")
    agents_touch(transcript, 100)
    @store.write(record(transcript_path: transcript))

    assert_in_delta(Time.now - 100, @store.records.first.transcript_written_at, 5)
  end

  def test_record_store_exclusively_refuses_a_second_holder
    @store.exclusively do
      assert_raises(Refusal) { RecordStore.new(root: File.join(@dir, "agents")).exclusively { flunk } }
    end
    assert_equal(:done, @store.exclusively { :done })
  end

  def test_record_store_note_appends_one_line
    @store.note("first\nsecond")
    @store.note("third")

    assert_equal(2, File.readlines(File.join(@dir, "agents/recorder.log")).size)
  end

  def test_record_store_default_root_follows_xdg_state_home
    with_env("XDG_STATE_HOME" => "/xdg") { assert_equal("/xdg/herdr-app/agents", RecordStore.default_root) }
    with_env("XDG_STATE_HOME" => "") { assert_equal(File.expand_path("~/.local/state/herdr-app/agents"), RecordStore.default_root) }
  end

  # --- SessionStart ---

  def test_session_start_record_answers_nil_outside_herdr_app
    assert_nil(session_start({}).record(processes: ProcessTable.new([]), now: NOW))
  end

  def test_session_start_record_answers_nil_for_claude_print_mode
    assert_nil(session_start(PANE.merge("CLAUDE_CODE_ENTRYPOINT" => "sdk-cli")).record(processes: ProcessTable.new([]), now: NOW))
  end

  def test_session_start_record_refuses_another_address
    line = FakeCommandLine.new([ "hc", "get", "t5", "--json" ] => agent("t9", %w[claude]))

    assert_raises(Refusal) { session_start(PANE, line).record(processes: ProcessTable.new([]), now: NOW) }
  end

  def test_session_start_record_refuses_a_conflicting_hc_session
    assert_raises(Refusal) { session_start(PANE.merge("HC_SESSION" => "work")).record(processes: ProcessTable.new([]), now: NOW) }
  end

  def test_session_start_record_records_the_foreground_cwd_and_flags
    line = FakeCommandLine.new([ "hc", "get", "t5", "--json" ] => agent("t5", %w[claude --permission-mode plan], cwd: @dir))
    processes = ProcessTable.new([ [ 100, 200, %w[ruby hook] ], [ 200, AGENT_PID, %w[sh -c hook] ], [ AGENT_PID, 1, %w[claude] ] ])

    found = session_start(PANE, line).record(processes: processes, now: NOW, pid: 100)

    assert_equal([ "default", "t5", File.realpath(@dir), %w[--permission-mode plan], NOW ],
                 found.to_h.values_at(:core, :terminal, :cwd, :flags, :recorded_at))
  end

  # --- Shutdown ---

  def test_shutdown_moment_is_the_newest_transcript_before_the_core_start
    records = [ record(transcript_written_at: NOW - 300), record(terminal: "t6", transcript_written_at: NOW - 100),
                record(terminal: "t7", transcript_written_at: NOW + 10) ]

    assert_equal(NOW - 100, Shutdown.new(records, started_at: NOW).moment)
    assert_nil(Shutdown.new([], started_at: NOW).moment)
  end

  def test_shutdown_running_keeps_600_seconds_and_drops_601
    moment = NOW - 100
    kept = record(terminal: "t1", transcript_written_at: moment - 600)
    dropped = record(terminal: "t2", transcript_written_at: moment - 601)
    newest = record(terminal: "t3", transcript_written_at: moment)

    assert_equal(%w[t1 t3], Shutdown.new([ kept, dropped, newest ], started_at: NOW).running.map(&:terminal).sort)
  end

  def test_shutdown_running_drops_a_missing_transcript
    assert_empty(Shutdown.new([ record(transcript_written_at: nil) ], started_at: NOW).running)
  end

  def test_shutdown_running_drops_records_touched_since_the_start
    reopened = record(transcript_written_at: NOW - 100, recorded_at: NOW)
    resumed = record(terminal: "t6", transcript_written_at: NOW - 100, resumed_at: NOW + 1)

    assert_empty(Shutdown.new([ reopened, resumed ], started_at: NOW).running)
  end

  private

  def record_hash
    { "core" => "default", "terminal" => "t5", "kind" => "claude", "session_id" => CLAUDE_ID, "cwd" => "/tmp/x",
      "transcript_path" => "/tmp/x.jsonl", "flags" => [], "recorded_at" => (NOW - 3600).iso8601(3), "resumed_at" => nil }
  end

  def record(**fields)
    fields = { core: "default", terminal: "t5", kind: "claude", session_id: CLAUDE_ID, cwd: "/tmp/x",
               transcript_path: "/tmp/x.jsonl", flags: [], recorded_at: NOW - 3600, resumed_at: nil,
               transcript_written_at: nil }.merge(fields)
    AgentRecord.new(**fields)
  end

  def session_start(environment, line = FakeCommandLine.new)
    cores = Class.new do
      define_singleton_method(:of_socket) { |path| Core.of_socket(path).then { |core| Core.new(core.name, command_line: line) } }
    end
    SessionStart.new("claude", JSON.generate("session_id" => CLAUDE_ID, "transcript_path" => "/tmp/x.jsonl"), environment, cores: cores)
  end

  def executable(name, source)
    path = File.join(@dir, name)
    File.write(path, source)
    FileUtils.chmod(0o755, path)
    path
  end

  def with_env(values)
    saved = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
