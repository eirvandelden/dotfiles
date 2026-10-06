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

  def test_pushing_to_a_target_that_is_not_a_remote_needs_consent
    _, stderr, status = run_guard("git push some-typo my-branch")

    assert_equal(2, status.exitstatus)
    assert_match(/some-typo/, stderr)
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

  private

  def allow_remotes(*entries)
    File.write(File.join(@home, ".claude", "consent-guard-allowed-remotes.txt"), entries.join("\n"))
  end

  def add_remote(name, url)
    system("git", "-C", @repo, "remote", "add", name, url)
  end

  def run_guard(command)
    payload = JSON.generate({ tool_name: "Bash", tool_input: { command: command }, cwd: @repo })
    Open3.capture3({ "HOME" => @home }, GUARD, stdin_data: payload)
  end

  def run_codex_guard(command)
    payload = JSON.generate({ session_id: "s", turn_id: "t", hook_event_name: "PreToolUse", model: "gpt",
                              permission_mode: "default", tool_name: "Bash", tool_input: { command: command },
                              tool_use_id: "exec-1", cwd: @repo })
    Open3.capture3({ "HOME" => @home }, GUARD, stdin_data: payload)
  end
end
