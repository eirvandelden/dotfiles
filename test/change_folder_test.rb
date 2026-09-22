#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Every change gets a folder named after its branch: docs/changes/<slug>/. This
# script is the one place that derivation happens — the intent, spec, plan and
# implement skills all shell out to it instead of re-deriving the slug.
class ChangeFolderTest < Minitest::Test
  SCRIPT = File.expand_path("../claude/.claude/skills/plan/scripts/change-folder", __dir__)

  def setup
    @repo = Dir.mktmpdir
    git("init", "--quiet", "--initial-branch=main")
    git("commit", "--quiet", "--allow-empty", "-m", "initial")
  end

  def teardown
    FileUtils.rm_rf(@repo)
  end

  def test_a_plain_branch_name_becomes_the_folder_as_is
    git("checkout", "--quiet", "-b", "claims-status")

    stdout, _stderr, status = run_script

    assert(status.success?)
    assert_equal("docs/changes/claims-status", stdout.strip)
  end

  def test_a_branch_with_a_prefix_drops_the_prefix
    git("checkout", "--quiet", "-b", "ai/claims-status")

    stdout, = run_script

    assert_equal("docs/changes/claims-status", stdout.strip)
  end

  def test_a_feature_prefixed_branch_also_drops_its_prefix
    git("checkout", "--quiet", "-b", "feature/claims-status")

    stdout, = run_script

    assert_equal("docs/changes/claims-status", stdout.strip)
  end

  def test_an_issue_numbered_branch_has_no_prefix_to_drop
    git("checkout", "--quiet", "-b", "7716-calendar-occurrence-range-fix")

    stdout, = run_script

    assert_equal("docs/changes/7716-calendar-occurrence-range-fix", stdout.strip)
  end

  def test_main_refuses
    _stdout, stderr, status = run_script

    assert_not(status.success?)
    assert_match(/main/i, stderr)
  end

  def test_master_refuses
    git("checkout", "--quiet", "-b", "master")

    _stdout, stderr, status = run_script

    assert_not(status.success?)
    assert_match(/master/i, stderr)
  end

  def test_detached_head_refuses
    git("checkout", "--quiet", "--detach")

    _stdout, stderr, status = run_script

    assert_not(status.success?)
    assert_match(/detached/i, stderr)
  end

  private

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
