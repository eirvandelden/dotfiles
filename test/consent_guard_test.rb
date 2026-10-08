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
    # A home of its own, so the guard reads the allowlist this test wrote and
    # never the one installed on the machine running the suite.
    @home = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@home, ".claude"))
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@home)
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

  def test_destructive_database_commands_are_blocked_without_user_consent
    [ "bin/rails db:drop", "rails db:reset", "bundle exec rails db:schema:load", "bin/rails db:drop:all" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
      assert_match(/rule 9/, stderr)
    end
  end

  def test_destructive_database_commands_run_once_the_user_has_consented
    _, stderr, status = run_guard("I_HAVE_USER_CONSENT=1 bin/rails db:drop")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_routine_database_commands_are_allowed
    [ "bin/rails db:migrate", "bin/rails db:migrate:status", "bin/rails db:prepare",
      "bin/rails db:migrate:down VERSION=1" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_a_commit_message_naming_db_drop_is_allowed
    _, stderr, status = run_guard("git commit -m 'never run rails db:drop here'")

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

  # A word that is neither a configured remote nor a URL is a local path to git,
  # so the push stays on this machine.
  def test_a_remote_that_is_not_configured_is_left_alone
    _, stderr, status = run_guard("git push some-typo my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_to_a_url_outside_the_allowlist_needs_consent
    [ "git@github.com:someone-else/dotfiles.git", "https://github.com/someone-else/dotfiles.git" ].each do |url|
      _, stderr, status = run_guard("git push #{url} my-branch")

      assert_equal(2, status.exitstatus, url)
      assert_match(/someone-else/, stderr)
    end
  end

  def test_pushing_to_an_allowed_url_is_allowed
    _, stderr, status = run_guard("git push git@github.com:eirvandelden/dotfiles.git my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_pushing_with_no_target_is_allowed
    _, stderr, status = run_guard("git push")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_git_stash_push_is_not_a_push
    [ "git stash push -u -m 'wip-tag'", "git stash push claude/.claude/settings.json" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_a_push_followed_by_another_command_is_allowed
    [ "git push --force-with-lease && gh pr create --fill", "git push --force-with-lease; gh pr create --fill" ]
      .each do |command|
        _, stderr, status = run_guard(command)

        assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
      end
  end

  def test_every_push_in_a_compound_command_is_checked
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    _, stderr, status = run_guard("git push origin a && git push upstream b")

    assert_equal(2, status.exitstatus)
    assert_match(/upstream/, stderr)
  end

  def test_a_push_hidden_behind_shell_syntax_is_still_checked
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    [ "git push origin a; git push upstream b", "true&&git push upstream b", "git push origin a\ngit push upstream b",
      "env FOO=1 git push upstream b", "sudo git push upstream b", "/usr/bin/git push upstream b",
      "git --git-dir .git push upstream b", "{ git push upstream b; }" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
      assert_match(/upstream/, stderr)
    end
  end

  def test_local_paths_after_a_push_are_allowed
    [ "git push 2>&1 | tee /tmp/push.log", "git push > /tmp/out", "git push origin a && cd ../other",
      "git stash push -- ./file.rb" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_a_scp_like_url_without_a_user_needs_consent
    _, stderr, status = run_guard("git push github.com:someone-else/x.git b")

    assert_equal(2, status.exitstatus)
    assert_match(/someone-else/, stderr)
  end

  def test_an_insteadof_alias_is_resolved_before_matching
    system("git", "-C", @repo, "config", "url.git@github.com:someone-else/.insteadOf", "evil:")

    _, stderr, status = run_guard("git push evil:repo.git b")

    assert_equal(2, status.exitstatus)
    assert_match(/evil:repo/, stderr)
  end

  def test_a_refspec_after_a_push_is_allowed
    _, stderr, status = run_guard("git push origin main:main")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_words_of_a_later_command_are_not_push_targets
    [ "git push origin b && open https://example.com/pr/1", "git push origin b && curl -s https://api.example.com/x",
      "git push origin b && bin/rails test foo_test.rb:12", "git push origin b; echo see x.rb:12" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_a_host_and_path_target_without_a_dot_needs_consent
    [ "git push myhost:someone-else/x.git b", "git push localhost:x.git b" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_a_refspec_with_a_dot_is_allowed
    [ "git push origin release-1.2:release-1.2", "git push origin v1.2.3:v1.2.3" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_a_remote_push_url_outside_the_allowlist_needs_consent
    add_remote("mirror", "git@github.com:eirvandelden/dotfiles.git")
    system("git", "-C", @repo, "remote", "set-url", "--push", "mirror", "git@github.com:someone-else/dotfiles.git")

    _, stderr, status = run_guard("git push mirror b")

    assert_equal(2, status.exitstatus)
    assert_match(/mirror/, stderr)
  end

  def test_a_remote_after_a_flag_value_is_still_checked
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    _, stderr, status = run_guard("git push -o ci.skip upstream b")

    assert_equal(2, status.exitstatus)
    assert_match(/upstream/, stderr)
  end

  def test_a_stash_message_that_looks_like_a_host_is_allowed
    [ "git stash push -m 'feat: add x'", "git stash push -m 'WIP: x' -- a.rb",
      "git push -o 'note: x' origin b" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_an_option_value_does_not_hide_the_repository
    [ "git push -o ci.skip git@github.com:someone-else/x.git b",
      "git push --push-option ci.skip git@github.com:someone-else/x.git b",
      "git push --receive-pack git-receive-pack git@github.com:someone-else/x.git b",
      "git push -o ci.skip myhost:x.git b", "git push --repo=git@github.com:someone-else/x.git b",
      "git push --repo git@github.com:someone-else/x.git b",
      "git push --repo=origin git@github.com:someone-else/x.git b",
      "git push --repo origin git@github.com:someone-else/x.git b",
      "git push file:/tmp/x b" ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_a_url_that_only_contains_an_allowed_path_needs_consent
    _, stderr, status = run_guard("git push https://evil.example/github.com/eirvandelden/x.git my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/evil\.example/, stderr)
  end

  def test_a_push_with_dash_c_resolves_the_remote_in_that_repository
    other = Dir.mktmpdir
    system("git", "init", "--quiet", other)
    system("git", "-C", other, "remote", "add", "fork", "git@github.com:eirvandelden/other.git")

    _, stderr, status = run_guard("git -C #{other} push fork my-branch")

    assert_equal(0, status.exitstatus, stderr)
  ensure
    FileUtils.rm_rf(other)
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

  # The employer's repositories are named in a file the public repository does
  # not carry, so a public checkout spells out no employer.
  def test_pushing_to_a_remote_the_allowlist_file_names_is_allowed
    allow_remotes("employer/their-app")
    add_remote("work", "git@github.com:employer/their-app.git")

    _, stderr, status = run_guard("git push work my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_the_allowlist_file_does_not_open_up_a_sibling_repository
    allow_remotes("employer/their-app")
    add_remote("work", "git@github.com:employer/another-app.git")

    _, stderr, status = run_guard("git push work my-branch")

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_an_allowlist_entry_ending_in_a_slash_covers_every_repository_of_that_owner
    allow_remotes("employer/")
    add_remote("work", "git@github.com:employer/another-app.git")

    _, stderr, status = run_guard("git push work my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_comments_and_blank_lines_in_the_allowlist_file_are_ignored
    allow_remotes("# the work repositories", "", "employer/their-app")
    add_remote("work", "git@github.com:employer/their-app.git")

    _, stderr, status = run_guard("git push work my-branch")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_the_refusal_points_at_the_allowlist_file_instead_of_naming_repositories
    add_remote("upstream", "git@github.com:someone-else/dotfiles.git")

    _, stderr, = run_guard("git push upstream my-branch")

    assert_match(/consent-guard-allowed-remotes\.txt/, stderr)
  end

  # Codex sends the same contract with more fields around it (probed 2026-10-01, codex-cli 0.159.3):
  # tool_name "Bash", the command in tool_input.command, plus session, turn and model fields.
  def test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload
    [ "git push --force origin x", "git push --no-verify origin x", "gh pr comment 12 --body hi",
      "kamal deploy" ].each do |command|
      _, claude_stderr, claude_status = run_guard(command)
      _, codex_stderr, codex_status = run_codex_guard(command)

      assert_equal(2, codex_status.exitstatus, command)
      assert_equal([ claude_status.exitstatus, claude_stderr ], [ codex_status.exitstatus, codex_stderr ], command)
    end
  end

  def test_a_codex_payload_lets_force_with_lease_through
    _, stderr, status = run_codex_guard("git push --force-with-lease origin x")

    assert_equal(0, status.exitstatus, stderr)
  end

  # Only /finish opens a pull request, and it removes docs/changes/<slug>/ first.
  def test_creating_a_pull_request_while_the_change_folder_exists_is_refused_naming_finish
    start_change("pr-only-via-finish")

    _, stderr, status = run_guard("gh pr create --fill")

    assert_equal(2, status.exitstatus, stderr)
    assert_match(%r{/finish}, stderr)
  end

  def test_creating_a_pull_request_once_finish_removed_the_change_folder_is_allowed
    start_change("pr-only-via-finish")
    system("git", "-C", @repo, "rm", "-rfq", "--cached", "docs")
    FileUtils.rm_rf(File.join(@repo, "docs"))

    _, stderr, status = run_guard("gh pr create --fill")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_creating_a_pull_request_on_main_is_allowed
    _, stderr, status = run_guard("gh pr create --fill")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_change_folder_in_a_cd_target_is_found
    other, run_from = other_checkout

    _, stderr, status = run_guard("cd #{other} && gh pr create", cwd: run_from)

    assert_equal(2, status.exitstatus, stderr)
  ensure
    FileUtils.rm_rf([ other, run_from ].compact)
  end

  def test_a_cd_target_glued_to_a_semicolon_is_found
    other, run_from = other_checkout

    _, stderr, status = run_guard("cd #{other}; gh pr create", cwd: run_from)

    assert_equal(2, status.exitstatus, stderr)
  ensure
    FileUtils.rm_rf([ other, run_from ].compact)
  end

  def test_a_cd_target_on_the_line_before_is_found
    other, run_from = other_checkout

    _, stderr, status = run_guard("cd #{other}\ngh pr create", cwd: run_from)

    assert_equal(2, status.exitstatus, stderr)
  ensure
    FileUtils.rm_rf([ other, run_from ].compact)
  end

  def test_creating_a_pull_request_inside_bash_dash_c_is_refused
    start_change("pr-only-via-finish")

    _, stderr, status = run_guard(%(bash -c "gh pr create --fill"))

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_consent_does_not_unlock_creating_a_pull_request_with_a_change_folder
    start_change("pr-only-via-finish")

    _, _, status = run_guard("I_HAVE_USER_CONSENT=1 gh pr create --fill")

    assert_equal(2, status.exitstatus)
  end

  def test_a_quoted_message_naming_gh_pr_create_is_allowed
    start_change("pr-only-via-finish")

    _, stderr, status = run_guard(%(git commit -m "finish runs gh pr create"))

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_codex_payload_creating_a_pull_request_with_a_change_folder_is_refused
    start_change("pr-only-via-finish")

    _, stderr, status = run_codex_guard("gh pr create --fill")

    assert_equal(2, status.exitstatus, stderr)
    assert_match(%r{/finish}, stderr)
  end

  def test_merging_a_pull_request_whose_head_has_docs_changes_is_refused
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "Tree")

    _, stderr, status = run_guard("gh pr merge 186 --squash")

    assert_equal(2, status.exitstatus, stderr)
    assert_match(%r{/finish}, stderr)
  end

  def test_merging_a_pull_request_whose_head_has_no_docs_changes_is_allowed
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "absent")

    _, stderr, status = run_guard("gh pr merge 185 --squash")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_merging_is_allowed_when_gh_cannot_tell
    stub_gh(fail: true)

    _, stderr, status = run_guard("gh pr merge 186")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_merging_asks_gh_about_the_named_pull_request_and_repository
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "absent")

    run_guard("gh pr merge --squash -t 'a title' 186 --repo eirvandelden/dotfiles")

    view = File.readlines(@gh_log).find { |line| line.start_with?("pr view") }
    assert_includes(view, "pr view 186 --repo eirvandelden/dotfiles")
  end

  def test_merging_reads_only_the_words_of_the_merge_command
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "absent")

    run_guard("gh pr merge --squash && git checkout main")

    view = File.readlines(@gh_log).find { |line| line.start_with?("pr view") }
    refute_includes(view, "&&")
    refute_includes(view, "checkout")
  end

  def test_a_git_merge_before_the_gh_merge_does_not_name_the_pull_request
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "Tree")

    _, stderr, status = run_guard("git merge origin/main && gh pr merge 186")

    view = File.readlines(@gh_log).find { |line| line.start_with?("pr view") }
    assert_includes(view, "pr view 186")
    assert_equal(2, status.exitstatus, stderr)
  end

  def test_a_trailing_value_flag_does_not_hide_the_selector
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "absent")

    run_guard("gh pr merge 186 --body")

    view = File.readlines(@gh_log).find { |line| line.start_with?("pr view") }
    assert_includes(view, "pr view 186")
  end

  def test_leftover_untracked_files_do_not_keep_the_pull_request_refused
    start_change("pr-only-via-finish")
    system("git", "-C", @repo, "add", "docs")
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null", "-c", "user.name=t", "-c", "user.email=t@t",
           "commit", "--quiet", "-m", "intent")
    system("git", "-C", @repo, "rm", "-rq", "docs/changes/pr-only-via-finish")
    FileUtils.mkdir_p(File.join(@repo, "docs", "changes", "pr-only-via-finish"))
    File.write(File.join(@repo, "docs", "changes", "pr-only-via-finish", ".DS_Store"), "x")

    _, stderr, status = run_guard("gh pr create --fill")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_creating_a_pull_request_from_a_subdirectory_is_refused
    start_change("pr-only-via-finish")
    FileUtils.mkdir_p(File.join(@repo, "sub"))

    _, stderr, status = run_guard("gh pr create --fill", cwd: File.join(@repo, "sub"))

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_a_cd_after_the_merge_does_not_move_the_question
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "Tree")

    _, stderr, status = run_guard("gh pr merge 186 && cd /tmp")

    assert_equal(2, status.exitstatus, stderr)
    refute_includes(File.read("#{@gh_log}.cwd"), "/tmp")
  end

  def test_gh_repo_in_the_environment_is_passed_on_to_the_question
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\tpr-only-via-finish", tree: "absent")

    run_guard("GH_REPO=eirvandelden/dotfiles gh pr merge 186")

    view = File.readlines(@gh_log).find { |line| line.start_with?("pr view") }
    assert_includes(view, "--repo eirvandelden/dotfiles")
  end

  def test_creating_a_pull_request_for_a_head_branch_that_holds_the_folder_is_refused
    start_change("pr-only-via-finish")
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null", "-c", "user.name=t", "-c", "user.email=t@t",
           "commit", "--quiet", "-m", "intent")
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null", "checkout", "--quiet", "main")

    _, stderr, status = run_guard("gh pr create --head pr-only-via-finish --fill")

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_the_head_check_works_from_a_subdirectory
    commit_change_then_leave_branch
    FileUtils.mkdir_p(File.join(@repo, "sub"))

    _, stderr, status = run_guard("gh pr create --head pr-only-via-finish --fill", cwd: File.join(@repo, "sub"))

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_a_glued_short_head_flag_is_read
    commit_change_then_leave_branch

    _, stderr, status = run_guard("gh pr create -Hpr-only-via-finish --fill")

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_a_leftover_folder_of_another_slug_does_not_refuse_the_head_branch
    commit_change_then_leave_branch
    system("git", "-C", @repo, "checkout", "--quiet", "pr-only-via-finish")
    system("git", "-C", @repo, "rm", "-rq", "docs/changes/pr-only-via-finish")
    FileUtils.mkdir_p(File.join(@repo, "docs", "changes", "other"))
    File.write(File.join(@repo, "docs", "changes", "other", "intent.md"), "x")
    system("git", "-C", @repo, "add", "docs")
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null", "-c", "user.name=t", "-c", "user.email=t@t",
           "commit", "--quiet", "-m", "finish")
    system("git", "-C", @repo, "checkout", "--quiet", "main")

    _, stderr, status = run_guard("gh pr create --head pr-only-via-finish --fill")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_subshell_cd_is_a_command_directory
    start_change("pr-only-via-finish")
    outside = Dir.mktmpdir

    _, stderr, status = run_guard("(cd #{@repo} && gh pr create --fill)", cwd: outside)

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_pushd_is_a_command_directory
    start_change("pr-only-via-finish")
    outside = Dir.mktmpdir

    _, stderr, status = run_guard("pushd #{@repo} && gh pr create --fill", cwd: outside)

    assert_equal(2, status.exitstatus, stderr)
  end

  def test_merging_checks_the_folder_of_the_pull_requests_own_branch
    stub_gh(view: "eirvandelden\tdotfiles\tabc123\t186-title", tree: "absent")

    run_guard("gh pr merge 186")

    tree = File.readlines(@gh_log).find { |line| line.start_with?("api graphql") }
    assert_includes(tree, "expression=abc123:docs/changes/186-title")
  end

  private

  def commit_change_then_leave_branch
    start_change("pr-only-via-finish")
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null", "-c", "user.name=t", "-c", "user.email=t@t",
           "commit", "--quiet", "-m", "intent")
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null", "checkout", "--quiet", "main")
  end

  # A repository on <branch> whose working tree holds docs/changes/<branch>/.
  def start_change(branch, repo: @repo)
    system("git", "-C", repo, "-c", "core.hooksPath=/dev/null", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "--quiet",
           "--allow-empty", "-m", "init")
    system("git", "-C", repo, "-c", "core.hooksPath=/dev/null", "checkout", "--quiet", "-b", branch)
    FileUtils.mkdir_p(File.join(repo, "docs", "changes", branch))
    File.write(File.join(repo, "docs", "changes", branch, "intent.md"), "intent")
    system("git", "-C", repo, "add", "docs")
  end

  # A second repository with a change folder, and a directory to run the command from.
  def other_checkout
    other = Dir.mktmpdir
    system("git", "init", "--quiet", "--initial-branch=main", other)
    start_change("pr-only-via-finish", repo: other)
    [ other, Dir.mktmpdir ]
  end

  # A gh on PATH that logs its arguments and answers from the given values.
  def stub_gh(view: nil, tree: nil, fail: false)
    bin = Dir.mktmpdir
    @gh_log = File.join(bin, "gh.log")
    script = File.join(bin, "gh")
    File.write(script, <<~SH)
      #!/bin/sh
      echo "$@" >> #{@gh_log}
      pwd -P >> #{@gh_log}.cwd
      #{fail ? 'exit 1' : ''}
      case "$1 $2" in
        "pr view") printf '%s\\n' '#{view}' ;;
        "api graphql") printf '%s\\n' '#{tree}' ;;
      esac
    SH
    FileUtils.chmod(0o755, script)
    @gh_bin = bin
  end

  def allow_remotes(*entries)
    File.write(File.join(@home, ".claude", "consent-guard-allowed-remotes.txt"), entries.join("\n"))
  end

  def add_remote(name, url)
    system("git", "-C", @repo, "remote", "add", name, url)
  end

  def run_guard(command, cwd: @repo)
    payload = JSON.generate({ tool_name: "Bash", tool_input: { command: command }, cwd: cwd })
    Open3.capture3(guard_environment, GUARD, stdin_data: payload)
  end

  def run_codex_guard(command)
    payload = JSON.generate({ session_id: "s", turn_id: "t", hook_event_name: "PreToolUse", model: "gpt",
                              permission_mode: "default", tool_name: "Bash", tool_input: { command: command },
                              tool_use_id: "exec-1", cwd: @repo })
    Open3.capture3(guard_environment, GUARD, stdin_data: payload)
  end

  def guard_environment
    environment = { "HOME" => @home }
    environment["PATH"] = "#{@gh_bin}:#{ENV.fetch('PATH')}" if @gh_bin
    environment
  end
end
