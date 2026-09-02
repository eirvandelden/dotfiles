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
  GUARD = File.expand_path("../claude/.claude/hooks/consent-guard.rb", __dir__)

  def setup
    @repo = Dir.mktmpdir
    @extra_dirs = []
    system("git", "init", "--quiet", "--initial-branch=main", @repo)
    add_remote("origin", "git@github.com:eirvandelden/dotfiles.git")
  end

  def teardown
    FileUtils.rm_rf(@repo)
    @extra_dirs.each { |dir| FileUtils.rm_rf(dir) }
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

  def test_committing_in_a_worktree_on_a_feature_branch_is_allowed
    worktree = worktree_on_feature_branch

    _, stderr, status = run_guard("cd #{worktree} && git commit -m 'quick fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_committing_in_a_worktree_named_by_the_c_option_is_allowed
    worktree = worktree_on_feature_branch

    _, stderr, status = run_guard("git -C #{worktree} commit -m 'quick fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_committing_in_a_worktree_named_from_the_home_directory_is_allowed
    worktree = worktree_on_feature_branch

    _, stderr, status = run_guard("cd ~/#{File.basename(worktree)} && git commit -m 'quick fix'",
                                  home: File.dirname(worktree))

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_committing_in_another_checkout_that_is_on_main_is_still_blocked
    _, stderr, status = run_guard("cd #{another_checkout_on_main} && git commit -m 'quick fix'")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_committing_by_the_c_option_in_a_checkout_on_main_is_blocked
    _, stderr, status = run_guard("git -C #{another_checkout_on_main} commit -m 'quick fix'")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_pushing_to_main_by_refspec_is_blocked_even_from_a_feature_branch
    checkout_feature_branch

    _, stderr, status = run_guard("git push origin main")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  # A commit message is prose, not a command. One describing a pull that ran against the
  # repository being pushed, and naming a master branch, used to read as a push to master.
  def test_a_commit_message_describing_a_push_to_master_is_allowed
    checkout_feature_branch
    message = "fix: refresh the advisory database. The git pull ran against the repository " \
              "being pushed instead, asking it for a master branch it does not have."

    _, stderr, status = run_guard("git commit -m '#{message}'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_commit_message_naming_a_branch_called_main_is_allowed
    checkout_feature_branch

    _, stderr, status = run_guard("git commit -m 'docs: explain why we never git push to main'")

    assert_equal(0, status.exitstatus, stderr)
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

  def test_pushing_with_a_redirect_after_the_arguments_is_allowed
    checkout_feature_branch

    _, stderr, status = run_guard("git push origin my-branch 2>&1 | tail -4")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_with_a_redirect_where_the_remote_would_go_is_allowed
    checkout_feature_branch

    _, stderr, status = run_guard("git push 2>&1")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_after_an_earlier_command_that_mentions_pushing_is_allowed
    checkout_feature_branch

    _, stderr, status = run_guard(%(echo "=== pushing ===" && git push origin my-branch))

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_to_main_is_blocked_when_git_runs_against_another_directory
    checkout_feature_branch

    _, stderr, status = run_guard("git -C #{@repo} push origin main")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_the_remote_is_found_when_git_runs_against_another_directory
    checkout_feature_branch
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    _, stderr, status = run_guard("git -C #{@repo} push upstream my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/upstream/, stderr)
  end

  def test_an_earlier_git_command_does_not_make_a_quoted_word_count_as_the_push
    checkout_feature_branch

    command = %(git add file\necho "=== push ===" && git push origin my-branch)
    _, stderr, status = run_guard(command)

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_remote_outside_the_allowlist_is_still_found_on_a_later_line
    checkout_feature_branch
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    _, stderr, status = run_guard("cd /tmp\ngit status\ngit push upstream my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/upstream/, stderr)
  end

  def test_pushing_to_a_remote_outside_the_allowlist_is_still_blocked
    checkout_feature_branch
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    _, stderr, status = run_guard("git push upstream my-branch 2>&1 | tail -4")

    assert_equal(2, status.exitstatus)
    assert_match(/upstream/, stderr)
  end

  def test_deleting_another_branch_from_a_checkout_on_main_is_allowed
    _, stderr, status = run_guard("git push origin --delete some-merged-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_deleting_many_branches_from_a_checkout_on_main_is_allowed
    _, stderr, status = run_guard("git push origin --delete one two three")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_deleting_main_itself_is_blocked
    _, stderr, status = run_guard("git push origin --delete main")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_pushing_a_named_feature_branch_from_a_checkout_on_main_is_allowed
    _, stderr, status = run_guard("git push origin some-feature")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_the_current_branch_from_a_checkout_on_main_is_blocked
    _, stderr, status = run_guard("git push")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_pushing_head_from_a_checkout_on_main_is_blocked
    _, stderr, status = run_guard("git push origin HEAD")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_the_last_directory_change_before_the_git_command_decides_the_checkout
    worktree = worktree_on_feature_branch

    _, stderr, status = run_guard("cd #{another_checkout_on_main} && cd #{worktree} && git commit -m 'quick fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_directory_change_after_the_git_command_does_not_decide_the_checkout
    worktree = worktree_on_feature_branch

    _, stderr, status = run_guard("git commit -m 'quick fix' && cd #{worktree}")

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_a_read_only_git_command_before_the_directory_change_does_not_hide_a_commit_on_main
    checkout_feature_branch

    command = "git fetch && cd #{another_checkout_on_main} && git commit -m 'quick fix'"
    _, stderr, status = run_guard(command)

    assert_equal(2, status.exitstatus)
    assert_match(/main/, stderr)
  end

  def test_a_read_only_git_command_before_the_directory_change_still_allows_a_worktree_commit
    worktree = worktree_on_feature_branch

    _, stderr, status = run_guard("git fetch && cd #{worktree} && git commit -m 'quick fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_wrapper_word_before_git_does_not_hide_a_commit_on_main
    [ "time", "nice", "sudo", "env", "command" ].each do |wrapper|
      _, stderr, status = run_guard("#{wrapper} git commit -m 'quick fix'")

      assert_equal(2, status.exitstatus, "#{wrapper} should not slip past the guard")
      assert_match(/main/, stderr)
    end
  end

  def test_a_wrapper_word_before_git_still_allows_a_commit_on_a_feature_branch
    checkout_feature_branch

    _, stderr, status = run_guard("time git commit -m 'quick fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_every_branch_at_once_is_blocked
    checkout_feature_branch

    [ "--all", "--mirror" ].each do |flag|
      _, stderr, status = run_guard("git push #{flag} origin")

      assert_equal(2, status.exitstatus, "#{flag} sends main to the remote")
      assert_match(/main|every branch/i, stderr)
    end
  end

  # The four findings below were open while the command was read as text. Reading
  # it the way the shell would closed all of them, so these assert the behaviour
  # that was wanted all along rather than the behaviour that was.

  def test_a_path_in_a_commit_message_does_not_decide_which_checkout_is_judged
    worktree = worktree_on_feature_branch

    _, stderr, status = run_guard("git commit -m 'see git -C #{worktree} for the fix'")

    assert_equal(2, status.exitstatus, "the commit still runs on main, whatever the message mentions")
    assert_match(/main/, stderr)
  end

  def test_a_path_in_a_commit_message_does_not_block_a_valid_commit
    checkout_feature_branch
    elsewhere = another_checkout_on_main

    _, stderr, status = run_guard("git commit -m 'see git -C #{elsewhere} for the fix'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_an_operator_inside_a_quoted_message_stays_part_of_the_message
    checkout_feature_branch

    _, stderr, status = run_guard("git commit -m 'docs: never do this; git push origin main is banned'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_command_that_never_runs_git_is_left_alone
    checkout_feature_branch

    _, stderr, status = run_guard("echo 'note: never do this; git push origin main is banned'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_naming_force_in_a_commit_message_does_not_block_the_commit
    checkout_feature_branch

    _, stderr, status = run_guard("git commit -m 'docs: explain why --force is banned'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_naming_no_verify_in_a_commit_message_does_not_block_the_commit
    checkout_feature_branch

    _, stderr, status = run_guard("git commit -m 'docs: never pass --no-verify'")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_grouping_construct_does_not_hide_the_checkout_or_the_write
    checkout_feature_branch
    elsewhere = another_checkout_on_main

    _, stderr, status = run_guard("(cd #{elsewhere} && git commit -m 'quick fix')")

    assert_equal(2, status.exitstatus, "the write runs in a checkout on main, parentheses or not")
    assert_match(/main/, stderr)
  end

  def test_a_command_with_an_unmatched_quote_is_still_judged_by_the_checkout
    _, stderr, status = run_guard("git commit -m 'unmatched")

    assert_equal(2, status.exitstatus, "an unreadable command must not be waved through")
    assert_match(/main/, stderr)
  end

  private

  def add_remote(name, url)
    system("git", "-C", @repo, "remote", "add", name, url)
  end

  def checkout_feature_branch
    system("git", "-C", @repo, "checkout", "--quiet", "-b", "feature/guarded")
  end

  # core.hooksPath is pointed away from this machine's global hooks: they would
  # otherwise run inside the throwaway repo and stop it from getting a commit.
  def worktree_on_feature_branch
    git_in_repo("-c", "user.email=test@example.com", "-c", "user.name=Test",
                "commit", "--quiet", "--allow-empty", "-m", "initial") ||
      raise("could not create the initial commit")
    parent = Dir.mktmpdir
    @extra_dirs << parent
    checkout = File.join(parent, "checkout")
    git_in_repo("worktree", "add", "--quiet", checkout, "-b", "feature/guarded") ||
      raise("could not create the worktree")
    checkout
  end

  def another_checkout_on_main
    checkout = Dir.mktmpdir
    @extra_dirs << checkout
    system("git", "init", "--quiet", "--initial-branch=main", checkout)
    checkout
  end

  # Signing is turned off as well as hooks: this machine signs commits through
  # the 1Password agent, which fails whenever it is locked, and a throwaway
  # repository has nothing worth signing.
  def git_in_repo(*arguments)
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false", *arguments)
  end

  def run_guard(command, home: nil)
    payload = JSON.generate({ tool_name: "Bash", tool_input: { command: command }, cwd: @repo })
    Open3.capture3(home ? { "HOME" => home } : {}, GUARD, stdin_data: payload)
  end
end
