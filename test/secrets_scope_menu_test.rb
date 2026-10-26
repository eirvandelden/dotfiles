#!/usr/bin/env ruby
require "minitest/autorun"
require "pty"
require "expect"
require_relative "isolated_git"
require_relative "codex_shim_support"

# A bare `unlock` or `secrets` on a terminal shows the scope menu on stderr:
# cancel, personal, work, both. These tests run zsh on a pseudo-terminal and
# answer the prompt, since the menu only shows when stdin is a terminal.
class SecretsScopeMenuTest < Minitest::Test
  include CodexShimSupport

  PROMPT = /scope\? /

  def setup
    setup_codex_fixtures
  end

  def teardown
    teardown_codex_fixtures
  end

  def test_a_bare_unlock_on_a_terminal_lists_cancel_personal_work_both_and_loads_the_choice
    output = run_on_terminal('unlock; print -r -- "pat=${FIZZY_PAT-unset} work=${MCP_EMAIL_SERVER_AUTH_TOKEN-unset}"', "4")

    assert_match(/1\) cancel\s+2\) personal\s+3\) work\s+4\) both/, output)
    assert_includes output, "pat=a-secret-value work=a-secret-value"
  end

  def test_choosing_work_loads_only_the_work_scope
    output = run_on_terminal('unlock; print -r -- "pat=${FIZZY_PAT-unset} work=${MCP_EMAIL_SERVER_AUTH_TOKEN-unset}"', "3")

    assert_includes output, "pat=unset work=a-secret-value"
  end

  def test_choosing_cancel_changes_neither_the_environment_nor_path
    output = run_on_terminal('unlock && print ran; print -r -- "status=$? pat=${FIZZY_PAT-unset} path=$PATH"', "1")

    assert_includes output, "unlock: cancelled"
    assert_includes output, "status=1 pat=unset"
    refute_includes output, "ran\r\n"
    refute_includes output, SHIM_DIR
  end

  def test_end_of_input_at_the_menu_cancels
    output = run_on_terminal('unlock; print -r -- "status=$? pat=${FIZZY_PAT-unset}"', "\x04")

    assert_includes output, "unlock: cancelled"
    assert_includes output, "status=1 pat=unset"
  end

  def test_an_invalid_choice_asks_again
    output = run_on_terminal('unlock; print -r -- "pat=${FIZZY_PAT-unset}"', "9", "2")

    assert_equal 2, output.scan(PROMPT).length
    assert_includes output, "pat=a-secret-value"
  end

  def test_a_bare_unlock_on_a_terminal_shows_the_menu_once
    output = run_on_terminal("unlock", "2")

    assert_equal 1, output.scan(PROMPT).length
  end

  def test_unlock_personal_on_a_terminal_skips_the_menu
    output = run_on_terminal('unlock personal; print -r -- "pat=${FIZZY_PAT-unset} work=${MCP_EMAIL_SERVER_AUTH_TOKEN-unset}"')

    refute_match PROMPT, output
    assert_includes output, "pat=a-secret-value work=unset"
  end

  def test_unlock_work_on_a_terminal_skips_the_menu
    output = run_on_terminal('unlock work; print -r -- "pat=${FIZZY_PAT-unset} work=${MCP_EMAIL_SERVER_AUTH_TOKEN-unset}"')

    refute_match PROMPT, output
    assert_includes output, "pat=unset work=a-secret-value"
  end

  def test_eval_secrets_on_a_terminal_shows_the_menu_on_stderr_and_evals_only_exports
    output = run_on_terminal('eval "$(secrets)"; print -r -- "status=$? pat=${FIZZY_PAT-unset}"', "2")

    assert_includes output, "2) personal"
    assert_includes output, "status=0 pat=a-secret-value"
  end

  private

  # Runs the script in zsh on a pseudo-terminal, sending one answer per prompt.
  # Returns everything zsh wrote. A missing prompt or a hung shell fails the
  # test after 5 seconds instead of blocking the suite.
  def run_on_terminal(script, *answers)
    output = +""
    PTY.spawn(shell_env, "zsh", "-f", "-c", "source #{LOADER}\n#{script}") do |reader, writer, pid|
      answers.each do |answer|
        output << expect_prompt(reader, pid)
        writer.print("#{answer}\r")
      end
      output << drain(reader, pid)
      Process.wait(pid)
    end
    output
  end

  def expect_prompt(reader, pid)
    reader.expect(PROMPT, 5)&.first || stop_shell(pid, "no prompt within 5 seconds")
  end

  def drain(reader, pid)
    output = +""
    loop do
      stop_shell(pid, "still running after 5 seconds: #{output}") unless reader.wait_readable(5)
      output << reader.read_nonblock(4096)
    end
  rescue EOFError, Errno::EIO
    output
  end

  def stop_shell(pid, message)
    Process.kill("KILL", pid)
    Process.wait(pid)
    flunk "zsh #{message}"
  end
end
