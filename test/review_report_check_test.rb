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
    git("commit", "--quiet", "--allow-empty", "-m", "initial")
    git("checkout", "--quiet", "-b", "claims-status")
  end

  def teardown
    FileUtils.rm_rf(@repo)
  end

  def test_a_branch_with_no_change_folder_passes
    write_and_commit("app/claims.rb", "class Claims; end\n", "add claims")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  def test_a_change_folder_with_no_review_fails
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")

    _, stderr, status = run_script

    assert_not(status.success?)
    assert_match(/claims-status/, stderr)
    assert_match(/no review\.md/i, stderr)
    assert_match(%r{/review}, stderr)
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

    assert_not(status.success?)
    assert_match(/touch code again/, stderr)
    assert_match(/add review/, stderr)
  end

  def test_a_fresh_review_with_uncommitted_code_outside_the_folder_fails
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    write_and_commit("docs/changes/claims-status/review.md", "# Round 1\n", "add review")
    write("app/claims.rb", "class Claims; end\n")

    _, stderr, status = run_script

    assert_not(status.success?)
    assert_match(%r{app/claims\.rb}, stderr)
  end

  def test_an_uncommitted_edit_inside_the_folder_only_passes
    write_and_commit("docs/changes/claims-status/plan.md", "# Plan\n", "add plan")
    write_and_commit("app/claims.rb", "class Claims; end\n", "touch code")
    write_and_commit("docs/changes/claims-status/review.md", "# Round 1\n", "add review")
    write("docs/changes/claims-status/review.md", "# Round 1\n\n# Round 2\n")

    _, stderr, status = run_script

    assert(status.success?, stderr)
  end

  private

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

  def run_script
    Open3.capture3(SCRIPT, chdir: @repo)
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end
end
