#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "shellwords"
require_relative "herdr_app_agents_harness"
require_relative "isolated_git"

# herdr-app-agents, run as a child process against stub hc and ps. See herdr_app_agents_harness.rb for the world.
class HerdrAppAgentsCliTest < Minitest::Test
  include HerdrAppAgentsHarness
  include HerdrAppAgentsHarness::Fixtures

  TERMINAL = "t5".freeze
  FOUR_IDS = { "t6" => "00000000-0000-4000-8000-000000000006", "t7" => "00000000-0000-4000-8000-000000000007",
               "t8" => "00000000-0000-4000-8000-000000000008", "t9" => "00000000-0000-4000-8000-000000000009" }.freeze

  def setup
    @cwd = File.realpath(Dir.mktmpdir("agents-cwd"))
    agents_setup
  end

  def teardown
    agents_teardown
    FileUtils.rm_rf(@cwd)
  end

  # --- record ---

  def test_record_claude_writes_the_terminals_record
    claude_pane(argv: %w[claude --permission-mode plan])

    stdout, _stderr, status = record_claude

    assert_predicate(status, :success?)
    assert_empty(stdout)
    record = JSON.parse(File.read(agents_record_path("default", TERMINAL)))
    assert_equal(
      { "core" => "default", "terminal" => TERMINAL, "kind" => "claude", "session_id" => CLAUDE_ID, "cwd" => @cwd,
        "flags" => %w[--permission-mode plan], "resumed_at" => nil },
      record.except("recorded_at", "transcript_path")
    )
    assert_equal(File.join(@agents_dir, "transcript.jsonl"), record["transcript_path"])
    assert_in_delta(Time.now, Time.iso8601(record["recorded_at"]), 30)
  end

  def test_record_codex_writes_the_terminals_record
    world(TERMINAL => agent(TERMINAL, %w[codex -s workspace-write -a never], cwd: @cwd, app: "codex"),
          ps: hook_chain("codex -s workspace-write"))

    _stdout, _stderr, status = agents_cli("record", "codex", stdin: agents_session_payload(CODEX_ID),
                                                            env: pane_env)

    assert_predicate(status, :success?)
    record = JSON.parse(File.read(agents_record_path("default", TERMINAL)))
    assert_equal([ "codex", CODEX_ID, %w[-s workspace-write -a never] ],
                 record.values_at("kind", "session_id", "flags"))
  end

  def test_record_skips_claude_print_mode
    claude_pane

    _stdout, _stderr, status = record_claude(env: { "CLAUDE_CODE_ENTRYPOINT" => "sdk-cli" })

    assert_predicate(status, :success?)
    refute_path_exists(agents_record_path("default", TERMINAL))
    assert_empty(agents_calls)
  end

  def test_record_skips_a_foreground_codex_exec
    world(TERMINAL => agent(TERMINAL, %w[codex exec fix], cwd: @cwd, app: "codex"), ps: hook_chain("codex exec fix"))

    _stdout, _stderr, status = agents_cli("record", "codex", stdin: agents_session_payload(CODEX_ID), env: pane_env)

    assert_predicate(status, :success?)
    refute_path_exists(agents_record_path("default", TERMINAL))
  end

  def test_record_skips_outside_herdr_app
    claude_pane

    _stdout, _stderr, status = record_claude(env: { "HC_TERMINAL_ID" => nil })

    assert_predicate(status, :success?)
    assert_empty(agents_calls)
  end

  def test_record_makes_one_hc_call
    claude_pane

    record_claude

    assert_equal([ [ "hc", "default", "get", TERMINAL, "--json" ] ], agents_calls.select { |call| call[0] == "hc" })
    assert_equal(1, agents_calls.count { |call| call[0] == "ps" })
  end

  def test_record_refuses_a_broken_hook_lineage
    world(TERMINAL => agent(TERMINAL, %w[claude], cwd: @cwd),
          ps: [ "$RECORDER #{HOOK_PID} ruby herdr-app-agents record claude",
                "#{HOOK_PID} 6000 codex app-server --listen", "6000 1 launchd" ])

    _stdout, _stderr, status = record_claude

    assert_predicate(status, :success?)
    refute_path_exists(agents_record_path("default", TERMINAL))
    assert_match(/lineage/, File.read(File.join(agents_store, "recorder.log")))
  end

  def test_record_survives_a_malformed_payload
    claude_pane

    stdout, _stderr, status = record_claude(stdin: "{not json")

    assert_predicate(status, :success?)
    assert_empty(stdout)
    refute_path_exists(agents_record_path("default", TERMINAL))
    assert_path_exists(File.join(agents_store, "recorder.log"))
  end

  # --- restore ---

  def test_restore_resumes_claude_in_its_terminal
    world(TERMINAL => shell(TERMINAL))
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID, flags: %w[--permission-mode plan])

    stdout, _stderr, status = agents_cli("restore")

    assert_predicate(status, :success?)
    assert_equal("herdr-app-agents: restored 1 agents\n", stdout)
    assert_equal([ [ "default", TERMINAL, "cd /tmp/project && claude --resume #{CLAUDE_ID} --permission-mode plan" ] ],
                 agents_sends)
  end

  def test_restore_resumes_codex_in_its_terminal
    world(TERMINAL => shell(TERMINAL))
    agents_write_record(terminal: TERMINAL, session_id: CODEX_ID, kind: "codex", flags: %w[-s workspace-write])

    agents_cli("restore")

    assert_equal([ [ "default", TERMINAL, "cd /tmp/project && codex resume #{CODEX_ID} -s workspace-write" ] ],
                 agents_sends)
  end

  def test_restore_returns_four_sessions_in_one_folder_to_their_own_terminals
    world(**FOUR_IDS.keys.to_h { |terminal| [ terminal.to_sym, shell(terminal) ] })
    FOUR_IDS.each_with_index do |(terminal, id), index|
      agents_write_record(terminal: terminal, session_id: id, transcript_age: 100 + index)
    end

    stdout, = agents_cli("restore")

    assert_match(/restored 4 agents/, stdout)
    assert_equal(FOUR_IDS.map { |terminal, id| [ "default", terminal, "cd /tmp/project && claude --resume #{id}" ] }.sort,
                 agents_sends.sort)
  end

  def test_restore_leaves_a_transcript_older_than_the_window
    world(t6: shell("t6"), t7: shell("t7"))
    agents_write_record(terminal: "t6", session_id: CLAUDE_ID, transcript_age: 120)
    agents_write_record(terminal: "t7", session_id: CODEX_ID, kind: "codex", transcript_age: 120 + 601)

    stdout, = agents_cli("restore")

    assert_match(/restored 1 agents/, stdout)
    assert_equal([ "t6" ], agents_sends.map { |send| send[1] })
  end

  def test_restore_leaves_a_terminal_that_is_not_a_bare_shell
    world(TERMINAL => agent(TERMINAL, %w[claude]))
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID)

    stdout, stderr, status = agents_cli("restore")

    assert_predicate(status, :success?)
    assert_match(/restored 0 agents/, stdout)
    assert_match(/#{TERMINAL}/, stderr)
    assert_empty(agents_sends)
  end

  def test_restore_skips_a_session_reopened_elsewhere_without_its_id_in_argv
    world(TERMINAL => shell(TERMINAL), t6: shell("t6"))
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID)
    agents_write_record(terminal: "t6", session_id: CLAUDE_ID, recorded_age: 5)

    stdout, = agents_cli("restore")

    assert_match(/restored 0 agents/, stdout)
    assert_empty(agents_sends)
  end

  def test_restore_skips_a_session_whose_id_is_in_ps
    world(TERMINAL => shell(TERMINAL), ps: [ "9001 1 claude --resume #{CLAUDE_ID}" ])
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID)

    stdout, = agents_cli("restore")

    assert_match(/restored 0 agents/, stdout)
    assert_empty(agents_sends)
  end

  def test_restore_twice_types_once
    world(TERMINAL => shell(TERMINAL))
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID)

    agents_cli("restore")
    stdout, = agents_cli("restore")

    assert_match(/restored 0 agents/, stdout)
    assert_equal(1, agents_sends.size)
  end

  def test_restore_refuses_while_another_restore_holds_the_lock
    world(TERMINAL => shell(TERMINAL))
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID)

    stdout, stderr, status = File.open(File.join(agents_store, "restore.lock"), File::CREAT | File::RDWR) do |lock|
      lock.flock(File::LOCK_EX)
      agents_cli("restore")
    end

    assert_equal(1, status.exitstatus)
    assert_empty(stdout)
    assert_match(/another restore/, stderr)
    assert_empty(agents_sends)
  end

  def test_restore_covers_the_work_core_with_its_own_hc_session
    agents_world_write("cores" => { "default" => core([ shell(TERMINAL) ]),
                                    "work" => core([ shell(TERMINAL) ]) }, "ps" => [])
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID)
    agents_write_record(terminal: TERMINAL, session_id: CODEX_ID, kind: "codex", core: "work")

    stdout, = agents_cli("restore")

    assert_match(/restored 2 agents/, stdout)
    assert_equal([ [ "default", TERMINAL, "cd /tmp/project && claude --resume #{CLAUDE_ID}" ],
                   [ "work", TERMINAL, "cd /tmp/project && codex resume #{CODEX_ID}" ] ], agents_sends.sort)
  end

  def test_restore_prints_the_count
    world(t6: shell("t6"), t7: shell("t7"))
    agents_write_record(terminal: "t6", session_id: CLAUDE_ID)
    agents_write_record(terminal: "t7", session_id: CODEX_ID, kind: "codex")

    stdout, = agents_cli("restore")

    assert_equal("herdr-app-agents: restored 2 agents\n", stdout)
  end

  def test_restore_calls_hc_once_per_core_and_per_candidate
    world(t6: shell("t6"), t7: shell("t7"))
    agents_write_record(terminal: "t6", session_id: CLAUDE_ID)
    agents_write_record(terminal: "t7", session_id: CODEX_ID, kind: "codex")

    agents_cli("restore")

    hc_calls = agents_calls.select { |call| call[0] == "hc" }.map { |call| call[2] }
    assert_equal(1, hc_calls.count("server"))
    assert_equal(2, hc_calls.count("get"))
    refute_includes(hc_calls, "ls")
  end

  def test_restore_refuses_inside_an_agent
    world(TERMINAL => shell(TERMINAL))
    agents_write_record(terminal: TERMINAL, session_id: CLAUDE_ID)

    [ { "CLAUDECODE" => "1" }, { "CODEX_THREAD_ID" => "x" } ].each do |env|
      _stdout, stderr, status = agents_cli("restore", env: env)

      assert_equal(1, status.exitstatus)
      assert_match(/inside an agent/, stderr)
    end
    assert_empty(agents_calls)
  end

  def test_restore_skips_a_tampered_record
    world(TERMINAL => shell(TERMINAL), t6: shell("t6"))
    agents_write_record(terminal: TERMINAL, session_id: "1; touch pwned")
    agents_write_record(terminal: "t6", session_id: CODEX_ID, kind: "codex", cwd: "/tmp/a b")

    stdout, _stderr, status = agents_cli("restore")

    assert_predicate(status, :success?)
    assert_match(/restored 1 agents/, stdout)
    assert_equal([ [ "default", "t6", "cd /tmp/a\\ b && codex resume #{CODEX_ID}" ] ], agents_sends)
  end

  def test_rejects_bad_arguments_before_any_call
    [ [], %w[bogus], %w[record], %w[record gemini], %w[restore now] ].each do |arguments|
      _stdout, stderr, status = agents_cli(*arguments)

      assert_equal(1, status.exitstatus, arguments.inspect)
      assert_match(/usage/, stderr)
    end
    assert_empty(agents_calls)
  end

  private

  # Sets the default core's terminals (an id => answer pair, or id: answer) and the ps table (ps:).
  def world(*pairs, ps: [], **named)
    answers = pairs.to_h.merge(named.transform_keys(&:to_s))
    agents_world_write("cores" => { "default" => core(answers.values) }, "ps" => ps)
  end

  def claude_pane(argv: %w[claude])
    world(TERMINAL => agent(TERMINAL, argv, cwd: @cwd), ps: hook_chain)
  end

  def pane_env
    { "HC_TERMINAL_ID" => TERMINAL, "HC_TERMINAL_SOCKET" => "/state/herdr-core/default/default.sock",
      "CLAUDE_CODE_ENTRYPOINT" => "cli" }
  end

  def record_claude(stdin: agents_session_payload(CLAUDE_ID), env: {})
    agents_cli("record", "claude", stdin: stdin, env: pane_env.merge(env))
  end
end
