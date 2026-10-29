#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "codex_shim_support"

# Since Codex 0.160 a plain `codex` hands MCP servers and shell commands to a
# shared daemon that never saw the unlocked secrets. After `unlock`, `codex`
# must run the real Codex in-process (`--no-daemon`), so the session inherits
# the unlocked environment, and must keep the secrets away from the daemon.
class CodexUnlockTest < Minitest::Test
  include CodexShimSupport

  def setup
    setup_codex_fixtures
  end

  def teardown
    teardown_codex_fixtures
  end

  def test_after_unlock_a_codex_session_gets_the_fizzy_token_off_the_shared_daemon
    unlock_then("codex")

    assert_equal [ "--no-daemon" ], single_call[:args]
    assert_equal "set", single_call[:env]["FIZZY_PAT"]
  end

  def test_after_unlock_a_codex_session_gets_the_email_token_off_the_shared_daemon
    unlock_then("codex")

    assert_equal [ "--no-daemon" ], single_call[:args]
    assert_equal "set", single_call[:env]["MCP_EMAIL_SERVER_AUTH_TOKEN"]
  end

  def test_after_unlock_a_codex_session_gets_every_variable_from_both_mapping_files
    unlock_then("codex")

    assert_equal(%w[set set set], MAPPED.map { |name| single_call[:env][name] })
  end

  def test_after_unlock_a_profile_session_runs_off_the_shared_daemon_with_the_secrets
    unlock_then("codex -p terra")

    assert_equal %w[--no-daemon -p terra], single_call[:args]
    assert_equal "set", single_call[:env]["FIZZY_PAT"]
  end

  def test_after_unlock_resume_runs_off_the_shared_daemon_with_the_secrets
    unlock_then("codex resume")

    assert_equal %w[--no-daemon resume], single_call[:args]
    assert_equal "set", single_call[:env]["FIZZY_PAT"]
  end

  def test_after_unlock_exec_runs_unchanged_with_the_secrets
    unlock_then("codex exec 'say hi'")

    assert_equal [ "exec", "say hi" ], single_call[:args]
    assert_equal "set", single_call[:env]["FIZZY_PAT"]
  end

  def test_after_unlock_a_launcher_finds_the_shim_and_its_session_runs_off_the_shared_daemon_with_the_secrets
    url = "http://127.0.0.1:8787/v1"
    _, stderr, status = run_zsh(<<~SH)
      unlock both
      resolved="$(command -v codex)"
      test "$resolved" = "#{SHIM}" || { echo "a launcher would run $resolved" >&2; exit 9; }
      OPENAI_BASE_URL=#{url} "$resolved" --config openai_base_url="#{url}"
    SH

    assert_equal(0, status.exitstatus, stderr)
    assert_equal [ "--no-daemon", "--config", "openai_base_url=#{url}" ], single_call[:args]
    assert_equal "set", single_call[:env]["FIZZY_PAT"]
  end

  def test_unlocked_launches_never_start_stop_or_restart_the_shared_daemon
    unlock_then("codex; codex resume; codex -p terra; codex exec hi")

    words = codex_calls.flat_map { |call| call[:args] }
    assert_equal 4, codex_calls.length
    assert_empty words & %w[app-server daemon start stop restart remote-control]
  end

  def test_daemon_commands_from_an_unlocked_shell_run_without_the_secrets
    unlock_then("codex agents")

    assert_equal [ "agents" ], single_call[:args]
    assert_equal(%w[unset unset unset], MAPPED.map { |name| single_call[:env][name] })
  end

  def test_without_unlock_codex_is_the_real_binary_with_its_arguments_unchanged
    stdout, stderr, status = run_zsh('print -r -- "$(command -v codex)"; codex -p terra')

    assert_equal(0, status.exitstatus, stderr)
    assert_equal "#{@fake_bin}/codex\n", stdout
    assert_equal "", stderr
    assert_equal %w[-p terra], single_call[:args]
    assert_equal(%w[unset unset unset], MAPPED.map { |name| single_call[:env][name] })
  end

  private

  def unlock_then(commands)
    _, stderr, status = run_zsh("unlock both\n#{commands}")
    assert_equal(0, status.exitstatus, stderr)
  end
end
