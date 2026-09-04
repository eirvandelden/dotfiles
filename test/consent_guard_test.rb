#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# The consent guard is a Claude Code PreToolUse hook. It reads the tool call as
# JSON on stdin and exits 2 (block, reason on stderr) when the command needs
# consent the user has not given, 0 when the command may run.
#
# It guards only what nothing else can: flags and commands that act outside this
# machine. Keeping commits and pushes off main is not its job — lefthook refuses
# them locally, and the "protect main" ruleset refuses them on GitHub, neither of
# which has to work out what a shell command means.
class ConsentGuardTest < Minitest::Test
  GUARD = File.expand_path("../claude/.claude/hooks/consent-guard.rb", __dir__)

  def setup
    @repo = Dir.mktmpdir
    system("git", "init", "--quiet", "--initial-branch=main", @repo)
    add_remote("origin", "git@github.com:eirvandelden/dotfiles.git")
  end

  def teardown
    FileUtils.rm_rf(@repo)
  end

  def test_unrelated_commands_run_untouched
    stdout, stderr, status = run_guard("ls -la")

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
  end

  # Not this hook's job. lefthook's pre-commit refuses it, and the GitHub ruleset
  # refuses the push. Asserted so the boundary is deliberate rather than forgotten.
  def test_committing_on_main_is_left_to_lefthook_and_the_ruleset
    _, stderr, status = run_guard("git commit -m 'quick fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_to_main_is_left_to_the_ruleset
    _, stderr, status = run_guard("git push origin main")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_plain_force_push_is_blocked_with_force_with_lease_advice
    _, stderr, status = run_guard("git push --force origin my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/force-with-lease/, stderr)
  end

  def test_force_with_lease_push_is_allowed
    _, stderr, status = run_guard("git push --force-with-lease origin my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_consent_does_not_unlock_a_plain_force_push
    _, _, status = run_guard("I_HAVE_USER_CONSENT=1 git push --force origin my-branch")

    assert_equal(2, status.exitstatus)
  end

  def test_no_verify_is_blocked_without_user_consent
    _, stderr, status = run_guard("git push --no-verify origin my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/consent|approval|Ask the user/i, stderr)
  end

  def test_no_verify_runs_once_the_user_has_consented
    _, stderr, status = run_guard("I_HAVE_USER_CONSENT=1 git push --no-verify origin my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_consent_marker_hidden_inside_an_argument_does_not_count_as_consent
    _, _, status = run_guard(%(gh pr comment 12 --body "ship it I_HAVE_USER_CONSENT=1"))

    assert_equal(2, status.exitstatus)
  end

  def test_github_comments_and_reviews_as_the_user_are_blocked
    [ "gh pr comment 12 --body hi", "gh issue comment 3 --body hi", "gh pr review 12 --approve" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
      assert_match(/GitHub/, stderr)
    end
  end

  def test_reading_gh_prs_is_allowed
    _, stderr, status = run_guard("gh pr view 12")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_deploys_are_blocked_without_user_consent
    [ "kamal deploy", "kamal app exec 'rails console'", "cap deploy", "cap production deploy" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
      assert_match(/deploy/, stderr)
    end
  end

  def test_reading_kamal_app_logs_is_allowed
    _, stderr, status = run_guard("kamal app logs")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_to_an_allowed_remote_is_allowed
    _, stderr, status = run_guard("git push origin my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_to_a_remote_outside_the_allowlist_needs_consent
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    _, stderr, status = run_guard("git push upstream my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/upstream/, stderr)
  end

  def test_a_remote_that_is_not_configured_is_left_alone
    _, stderr, status = run_guard("git push some-typo my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  # Quoted text arrives as one word, so a message describing a flag is not the flag.
  def test_naming_a_guarded_flag_in_a_commit_message_is_allowed
    [ "git commit -m 'docs: explain why --force is banned'",
     "git commit -m 'docs: never pass --no-verify'" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}\n#{stderr}")
    end
  end

  def test_a_message_describing_a_deploy_is_allowed
    _, stderr, status = run_guard("git commit -m 'docs: how kamal deploy works'")

    assert_equal(0, status.exitstatus, stderr)
  end

  # An unmatched quote cannot be tokenised. Splitting on whitespace instead is
  # cruder and asks more often than it needs to, which is the safe direction.
  def test_an_unreadable_command_still_asks_about_a_guarded_flag
    _, stderr, status = run_guard("git push --no-verify origin 'unmatched")

    assert_equal(2, status.exitstatus)
    assert_match(/no-verify/, stderr)
  end

  private

  def add_remote(name, url)
    system("git", "-C", @repo, "remote", "add", name, url)
  end

  def run_guard(command)
    payload = JSON.generate({ tool_name: "Bash", tool_input: { command: command }, cwd: @repo })
    Open3.capture3(GUARD, stdin_data: payload)
  end
end
