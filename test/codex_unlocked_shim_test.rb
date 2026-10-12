#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "codex_shim_support"

# The `codex` shim in zsh/.config/zsh/unlocked-bin sorts each launch into a
# session (gets --no-daemon), a daemon command (runs without any mapped secret)
# or anything else (runs unchanged), then execs the real Codex.
class CodexUnlockedShimTest < Minitest::Test
  include CodexShimSupport

  def setup
    setup_codex_fixtures
  end

  def teardown
    teardown_codex_fixtures
  end

  def test_a_bare_launch_runs_the_real_codex_with_no_daemon_first
    run_shim

    assert_equal [ "--no-daemon" ], single_call[:args]
  end

  def test_a_prompt_starts_a_session_with_no_daemon
    run_shim("fix the build")

    assert_equal [ "--no-daemon", "fix the build" ], single_call[:args]
  end

  def test_resume_and_fork_start_a_session_with_no_daemon
    run_shim("resume", "--last")
    run_shim("fork")

    assert_equal [ %w[--no-daemon resume --last], %w[--no-daemon fork] ], codex_calls.map { |call| call[:args] }
  end

  def test_headroom_config_prefix_still_starts_a_session_with_no_daemon
    run_shim("--config", "openai_base_url=http://127.0.0.1:8787/v1")

    assert_equal %w[--no-daemon --config openai_base_url=http://127.0.0.1:8787/v1], single_call[:args]
  end

  def test_an_option_value_is_never_taken_for_a_subcommand
    [ %w[-m exec], %w[-C agents], %w[-c x=agents], %w[--profile queue] ].each { |args| run_shim(*args) }

    assert(codex_calls.all? { |call| call[:args].first == "--no-daemon" })
    assert(codex_calls.all? { |call| call[:env]["FIZZY_PAT"] == "set" })
  end

  def test_an_explicit_no_daemon_is_not_repeated
    run_shim("--no-daemon", "resume")

    assert_equal %w[--no-daemon resume], single_call[:args]
  end

  def test_exec_and_other_subcommands_run_unchanged_with_the_secrets
    %w[exec mcp login features review].each { |subcommand| run_shim(subcommand, "-x") }

    assert_equal %w[exec mcp login features review], codex_calls.map { |call| call[:args].first }
    assert(codex_calls.all? { |call| call[:args].last == "-x" && call[:env]["FIZZY_PAT"] == "set" })
  end

  def test_agents_queue_app_server_remote_control_and_update_run_without_any_mapped_variable
    commands = %w[agents queue app-server remote-control update]
    commands.each { |command| run_shim(command, "--flag") }

    assert_equal commands, codex_calls.map { |call| call[:args].first }
    codex_calls.each do |call|
      assert_equal(%w[unset unset unset], MAPPED.map { |name| call[:env][name] })
      assert_equal "--flag", call[:args].last
    end
  end

  def test_a_daemon_command_runs_without_the_shim_on_path
    run_shim("agents")

    refute_includes single_call[:path], SHIM_DIR
    assert_includes single_call[:path], @fake_bin
  end

  # unlock exports UNLOCKED_BIN so child login shells put the shim back first.
  # A daemon must not carry it to the locked sessions it serves.
  def test_a_session_keeps_the_unlocked_bin_marker_and_a_daemon_command_drops_it
    run_shim(extra_env: { "UNLOCKED_BIN" => SHIM_DIR })
    run_shim("agents", extra_env: { "UNLOCKED_BIN" => SHIM_DIR })

    assert_equal %w[set unset], codex_calls.map { |call| call[:env]["UNLOCKED_BIN"] }
  end

  def test_a_remote_launch_runs_unchanged_without_the_secrets
    run_shim("--remote", "ws://127.0.0.1:1")

    assert_equal %w[--remote ws://127.0.0.1:1], single_call[:args]
    assert_equal(%w[unset unset unset], MAPPED.map { |name| single_call[:env][name] })
  end

  def test_variables_not_in_a_mapping_file_survive_a_daemon_command
    run_shim("agents", extra_env: { "UNMAPPED_VAR" => "x" })

    assert_equal "set", single_call[:env]["UNMAPPED_VAR"]
  end

  def test_a_missing_mapping_file_strips_nothing_and_does_not_fail
    File.delete(File.join(@config, "1password.work.env"))

    _, stderr, status = run_shim("agents")

    assert_equal(0, status.exitstatus, stderr)
    assert_equal %w[unset unset set], MAPPED.map { |name| single_call[:env][name] }
  end

  # A stowed shim sits behind a symlinked directory. If the skip broke, the shim
  # would exec itself forever, so the run has a deadline instead of hanging.
  def test_the_shim_skips_its_own_directory_behind_a_symlink_to_find_the_real_codex
    linked_dir = File.join(@tmpdir, "linked-unlocked-bin")
    File.symlink(SHIM_DIR, linked_dir)

    status = run_with_deadline(File.join(linked_dir, "codex"), { "PATH" => "#{linked_dir}:#{@fake_bin}:/usr/bin:/bin" })

    assert_equal 0, status.exitstatus
    assert_equal [ "--no-daemon" ], single_call[:args]
  end

  def test_no_real_codex_fails_with_exit_127_and_names_the_shim_directory
    File.delete(File.join(@fake_bin, "codex"))

    _, stderr, status = run_shim

    assert_equal 127, status.exitstatus
    assert_includes stderr, "codex: no codex found on PATH besides #{SHIM_DIR}"
  end

  def test_the_real_codexs_exit_status_comes_back_unchanged
    _, _, status = run_shim(extra_env: { "FAKE_CODEX_STATUS" => "42" })

    assert_equal 42, status.exitstatus
  end

  private

  def run_shim(*args, extra_env: {})
    Open3.capture3(shim_env.merge(extra_env), SHIM, *args, unsetenv_others: true)
  end

  def run_with_deadline(command, extra_env, seconds: 10)
    pid = Process.spawn(shim_env.merge(extra_env), command, unsetenv_others: true, out: File::NULL, err: File::NULL)
    deadline = Time.now + seconds
    loop do
      _, status = Process.wait2(pid, Process::WNOHANG)
      return status if status
      break if Time.now > deadline

      sleep 0.05
    end
    Process.kill("KILL", pid)
    Process.wait(pid)
    flunk "the shim did not finish within #{seconds}s; it probably runs itself"
  end

  def shim_env
    shell_env.merge(
      "PATH" => "#{SHIM_DIR}:#{@fake_bin}:/usr/bin:/bin",
      "FIZZY_PAT" => "v",
      "NODE_AUTH_TOKEN" => "v",
      "MCP_EMAIL_SERVER_AUTH_TOKEN" => "v",
      "HOME" => @tmpdir
    )
  end
end
