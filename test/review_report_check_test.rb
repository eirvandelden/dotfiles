#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Deterministic pre-push backstop (playbook's "skill makes violations rare, hook makes them
# impossible" pairing): refuses a push whose change folder has no review.md at least as new,
# in commits, as the last change to anything outside the folder. Freshness is defined in git
# terms, not mtime.
class ReviewReportCheckTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/review-report-fresh", __dir__)

  def setup
    @repo = Dir.mktmpdir
    git("init", "--quiet", "--initial-branch=main")
    write_and_commit("app/existing.rb", "class Existing; end\n", "initial")
    git("checkout", "--quiet", "-b", "claims-status")
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@gh_bin) if @gh_bin
  end

  def test_a_branch_with_no_change_folder_passes
    write_and_commit("app/claims.rb", "class Claims; end\n", "add claims")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  def test_a_change_folder_with_no_code_commits_of_its_own_passes
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  def test_a_change_folder_passes_when_origin_head_is_dangling
    git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  def test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    git("checkout", "--quiet", "main")
    write_and_commit("app/other.rb", "class Other; end\n", "advance main")
    git("checkout", "--quiet", "claims-status")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  def test_a_review_committed_after_the_last_code_commit_passes
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    write_and_commit("app/claims.rb", "class Claims; end\n", "touch code")
    write_and_commit("docs/changes/claims-status/review.md", "# Round 1\n", "add review")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  def test_a_code_commit_after_the_review_fails
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    write_and_commit("docs/changes/claims-status/review.md", "# Round 1\n", "add review")
    write_and_commit("app/claims.rb", "class Claims; end\n", "touch code again")

    _, stderr, status = run_script

    refute(status.success?)
    assert_match(/touch code again/, stderr)
    assert_match(/add review/, stderr)
  end

  def test_a_fresh_review_with_uncommitted_code_outside_the_folder_fails
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    write_and_commit("docs/changes/claims-status/review.md", "# Round 1\n", "add review")
    write("app/claims.rb", "class Claims; end\n")

    _, stderr, status = run_script

    refute(status.success?)
    assert_match(%r{app/claims\.rb}, stderr)
  end

  def test_a_code_commit_on_the_branch_itself_still_requires_a_review
    write_and_commit("docs/changes/claims-status/intent.md", "# Intent\n", "add intent")
    write_and_commit("app/claims.rb", "class Claims; end\n", "touch code")

    _, stderr, status = run_script

    refute(status.success?)
    assert_match(/touch code/, stderr)
    assert_match(/no review\.md/i, stderr)
    assert_match(%r{/review}, stderr)
  end

  def test_an_uncommitted_edit_inside_the_folder_only_passes
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    write_and_commit("app/claims.rb", "class Claims; end\n", "touch code")
    write_and_commit("docs/changes/claims-status/review.md", "# Round 1\n", "add review")
    write("docs/changes/claims-status/review.md", "# Round 1\n\n# Round 2\n")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  # The pre-push hook passes --skip-without-pr: a work-in-progress push needs no review
  # until a pull request exists. finish runs the script without it and stays strict.
  def test_skip_without_pr_lets_a_stale_review_through_while_no_pull_request_is_open
    stale_change_folder
    stub_gh(open_pull_requests: "0")

    _, stderr, status = run_script("--skip-without-pr")

    assert(status.success?, stderr)
    assert_match(/pr list --head claims-status --state open/, File.read(@gh_log))
  end

  def test_skip_without_pr_still_refuses_a_stale_review_once_a_pull_request_is_open
    stale_change_folder
    stub_gh(open_pull_requests: "1")

    _, _, status = run_script("--skip-without-pr")

    refute(status.success?)
  end

  def test_skip_without_pr_refuses_a_stale_review_when_gh_cannot_tell
    stale_change_folder
    stub_gh(fail: true)

    _, stderr, status = run_script("--skip-without-pr")

    refute(status.success?)
    assert_match(/could not tell/i, stderr)
  end

  def test_skip_without_pr_never_calls_gh_without_a_change_folder
    write_and_commit("app/claims.rb", "class Claims; end\n", "add claims")
    stub_gh(open_pull_requests: "0")

    _, stderr, status = run_script("--skip-without-pr")

    assert(status.success?, stderr)
    refute_path_exists(@gh_log)
  end

  def test_without_the_flag_gh_is_never_called
    stale_change_folder
    stub_gh(open_pull_requests: "0")

    _, _, status = run_script

    refute(status.success?)
    refute_path_exists(@gh_log)
  end

  def test_the_pre_push_hook_runs_the_check_with_skip_without_pr
    lefthook = File.read(File.expand_path("../lefthook.yml", __dir__))

    assert_match(%r{run: ~/\.config/git/worktree-tools/review-report-fresh --skip-without-pr$}, lefthook)
  end

  private

  def stale_change_folder
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    write_and_commit("docs/changes/claims-status/review.md", "# Round 1\n", "add review")
    write_and_commit("app/claims.rb", "class Claims; end\n", "touch code again")
  end

  # A gh on PATH that logs its arguments and prints the open pull request count.
  def stub_gh(open_pull_requests: nil, fail: false)
    @gh_bin = Dir.mktmpdir
    @gh_log = File.join(@gh_bin, "gh.log")
    File.write(File.join(@gh_bin, "gh"), <<~SH)
      #!/bin/sh
      echo "$@" >> #{@gh_log}
      #{fail ? 'exit 1' : ''}
      echo '#{open_pull_requests}'
    SH
    FileUtils.chmod(0o755, File.join(@gh_bin, "gh"))
  end

  def write(relative_path, content)
    path = File.join(@repo, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def write_and_commit(relative_path, content, message)
    write(relative_path, content)
    git("add", relative_path)
    git("commit", "--quiet", "-m", message)
  end

  def git(*arguments)
    system("git", "-C", @repo, "-c", "commit.gpgsign=false", "-c", "user.email=test@example.com",
           "-c", "user.name=Test", *arguments) || raise("git #{arguments.join(' ')} failed")
  end

  def run_script(*arguments)
    environment = @gh_bin ? { "PATH" => "#{@gh_bin}:#{ENV.fetch('PATH')}" } : {}
    Open3.capture3(environment, SCRIPT, *arguments, chdir: @repo)
  end
end
