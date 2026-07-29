#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# The consent guard is a Claude Code PreToolUse hook. It reads the tool call as
# JSON on stdin and exits 2 (block, reason on stderr) when the command needs
# consent the user has not given, 0 when the command may run.
class ConsentGuardTest < Minitest::Test
  GUARD = File.expand_path("../claude/.claude/hooks/consent-guard.sh", __dir__)

  def setup
    @repo = Dir.mktmpdir
    system("git", "init", "--quiet", "--initial-branch=main", @repo)
  end

  def teardown
    FileUtils.rm_rf(@repo)
  end

  def test_unrelated_commands_run_untouched
    stdout, stderr, status = run_guard("ls -la")

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
  end

  def test_committing_on_main_is_blocked
    _, stderr, status = run_guard("git commit -m 'quick fix'")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
    assert_match(/feature branch/i, stderr)
  end

  def test_branching_off_main_with_push_in_the_branch_name_is_allowed
    _, stderr, status = run_guard("git checkout -b feature/push-notifications")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_committing_on_a_feature_branch_is_allowed
    checkout_feature_branch

    _, stderr, status = run_guard("git commit -m 'quick fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_to_main_by_refspec_is_blocked_even_from_a_feature_branch
    checkout_feature_branch

    _, stderr, status = run_guard("git push origin main")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_plain_force_push_is_blocked_with_force_with_lease_advice
    checkout_feature_branch

    _, stderr, status = run_guard("git push --force origin my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/force-with-lease/, stderr)
  end

  def test_force_with_lease_push_is_allowed
    checkout_feature_branch

    _, stderr, status = run_guard("git push --force-with-lease")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_no_verify_is_blocked_without_user_consent
    checkout_feature_branch

    _, stderr, status = run_guard("git push --no-verify")

    assert_equal(2, status.exitstatus)
    assert_match(/consent|approval/i, stderr)
  end

  def test_no_verify_runs_once_the_user_has_consented
    checkout_feature_branch

    _, stderr, status = run_guard("I_HAVE_USER_CONSENT=1 git push --no-verify")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_consent_does_not_unlock_main
    _, _, status = run_guard("I_HAVE_USER_CONSENT=1 git commit -m 'quick fix'")

    assert_equal(2, status.exitstatus)
  end

  def test_github_comments_as_the_user_are_blocked
    _, stderr, status = run_guard("gh pr comment 12 --body 'looks good'")

    assert_equal(2, status.exitstatus)
    assert_match(/consent|approval/i, stderr)
  end

  def test_consent_marker_hidden_inside_an_argument_does_not_count_as_consent
    _, _, status = run_guard(%(gh pr comment 12 --body "ship it I_HAVE_USER_CONSENT=1"))

    assert_equal(2, status.exitstatus)
  end

  def test_github_issue_comments_and_reviews_are_blocked
    _, _, comment_status = run_guard("gh issue comment 3 --body 'hi'")
    _, _, review_status = run_guard("gh pr review 12 --approve")

    assert_equal(2, comment_status.exitstatus)
    assert_equal(2, review_status.exitstatus)
  end

  def test_deploys_are_blocked_without_user_consent
    _, stderr, status = run_guard("kamal deploy")

    assert_equal(2, status.exitstatus)
    assert_match(/consent|approval/i, stderr)
  end

  def test_reading_gh_prs_is_allowed
    _, stderr, status = run_guard("gh pr view 12")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_kamal_app_exec_is_blocked_without_user_consent
    _, stderr, status = run_guard("kamal app exec 'rails console'")

    assert_equal(2, status.exitstatus)
    assert_match(/consent|approval/i, stderr)
  end

  def test_reading_kamal_app_logs_is_allowed
    _, stderr, status = run_guard("kamal app logs")

    assert_equal(0, status.exitstatus, stderr)
  end

  private

  def checkout_feature_branch
    system("git", "-C", @repo, "checkout", "--quiet", "-b", "feature/guarded")
  end

  def run_guard(command)
    payload = JSON.generate({ tool_name: "Bash", tool_input: { command: command }, cwd: @repo })
    Open3.capture3(GUARD, stdin_data: payload)
  end
end
