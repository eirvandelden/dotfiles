#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "delivery_harness"

# `commit-plan` commits intent.md and plan.md of a change together, once both are accepted, and
# nothing else. It never pushes.
class CommitPlanTest < Minitest::Test
  include DeliveryHarness

  SLUG = "my-change".freeze
  COMMIT_PLAN = File.join(DeliveryHarness::REPO_ROOT, "claude/.claude/skills/plan/scripts/commit-plan")

  def setup
    setup_harness
    build_repo
  end

  def teardown
    teardown_harness
  end

  def test_intent_and_plan_land_in_one_commit
    before = commit_count
    write_intent(intent_text)
    write_plan("Status: accepted.")

    _, stderr, status = commit_plan

    assert(status.success?, stderr)
    assert_equal(before + 1, commit_count)
    assert_equal("docs: intent and plan for #{SLUG}", git("log", "-1", "--format=%s").strip)
    assert_equal(%W[docs/changes/#{SLUG}/intent.md docs/changes/#{SLUG}/plan.md], committed_paths)
  end

  def test_refuses_a_draft_plan
    write_intent(intent_text)
    write_plan("Status: draft.")

    assert_refused_without_commit(/plan\.md.*accepted/)
  end

  def test_refuses_a_draft_intent
    write_intent(intent_text.sub("Status: accepted", "Status: draft"))
    write_plan("Status: accepted.")

    assert_refused_without_commit(/intent\.md.*accepted/)
  end

  def test_commits_plan_alone_when_intent_is_already_committed
    write_intent(intent_text)
    git("add", ".")
    git("commit", "--quiet", "-m", "docs: intent")
    write_plan("Status: accepted.")

    _, stderr, status = commit_plan

    assert(status.success?, stderr)
    assert_equal("docs: plan for #{SLUG}", git("log", "-1", "--format=%s").strip)
    assert_equal(%W[docs/changes/#{SLUG}/plan.md], committed_paths)
  end

  def test_leaves_other_changes_uncommitted
    write_intent(intent_text)
    write_plan("Status: accepted.")
    File.write(File.join(@repo, "README.md"), "changed\n")

    commit_plan

    assert_equal(" M README.md\n", git("status", "--porcelain"))
  end

  def test_commits_only_intent_and_plan_when_other_files_are_staged
    write_intent(intent_text)
    write_plan("Status: accepted.")
    File.write(File.join(@repo, "other.txt"), "x\n")
    git("add", "other.txt")

    _, stderr, status = commit_plan

    assert(status.success?, stderr)
    refute_includes(committed_paths, "other.txt")
    assert_equal("A  other.txt\n", git("status", "--porcelain"))
  end

  def test_it_never_pushes
    write_intent(intent_text)
    write_plan("Status: accepted.")

    commit_plan

    refute_includes(origin_branches, SLUG)
  end

  private

  def assert_refused_without_commit(message)
    before = commit_count
    _, stderr, status = commit_plan

    assert_equal(1, status.exitstatus)
    assert_match(message, stderr)
    assert_equal(before, commit_count)
  end

  def write_intent(text)
    write("intent.md", text)
  end

  def write_plan(status)
    write("plan.md", "# Plan: Ship the widget\n\nFrom `intent.md`. #{status}\n\n## Proof\n\n- Widgets ship\n")
  end

  def write(name, text)
    path = File.join(@repo, "docs/changes/#{SLUG}", name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  def commit_plan
    run_script(COMMIT_PLAN)
  end

  def committed_paths
    git("show", "--name-only", "--format=", "HEAD").split
  end

  def commit_count
    git("rev-list", "--count", "HEAD").to_i
  end
end
