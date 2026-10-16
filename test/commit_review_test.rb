#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "delivery_harness"

# `commit-review` commits docs/changes/<slug>/review.md only when the review has converged: it has a
# round and no open finding. An open round stays in the working tree, and the script never pushes.
class CommitReviewTest < Minitest::Test
  include DeliveryHarness

  SLUG = "my-change".freeze
  COMMIT_REVIEW = File.join(DeliveryHarness::REPO_ROOT, "agents/.agents/skills/review/scripts/commit-review")
  OPEN = "- [ ] Important: Widget leaks memory — `lib/widget.rb:1` →".freeze
  CLOSED = "- [ ] Important: Widget leaks memory — `lib/widget.rb:1` → fixed (Plug the leak)".freeze

  def setup
    setup_harness
    build_repo
    commit_file("docs/changes/#{SLUG}/intent.md", intent_text, "Add intent")
  end

  def teardown
    teardown_harness
  end

  def test_three_rounds_to_agreement_add_one_review_commit
    before = commit_count
    write_review(round(1, OPEN), round(2, "- [ ] Nit: Naming — `lib/widget.rb:2` →"))
    assert_equal(1, commit_review.last.exitstatus)
    write_review(round(1, CLOSED), round(2, "- [ ] Nit: Naming — `lib/widget.rb:2` → dismissed: house style"), round(3, "No findings."))

    _, stderr, status = commit_review

    assert(status.success?, stderr)
    assert_equal(before + 1, commit_count)
    assert_equal("docs/changes/#{SLUG}/review.md\n", git("show", "--name-only", "--format=", "HEAD"))
  end

  def test_an_open_round_leaves_review_md_uncommitted
    before = commit_count
    write_review(round(1, OPEN))

    _, stderr, status = commit_review

    assert_equal(1, status.exitstatus)
    assert_includes(stderr, "Widget leaks memory")
    assert_equal(before, commit_count)
    assert_match(%r{\?\? docs/changes/#{SLUG}/review.md}, git("status", "--porcelain"))
  end

  def test_refuses_a_review_md_without_a_round
    write_review("No round here.")

    _, stderr, status = commit_review

    assert_equal(1, status.exitstatus)
    assert_includes(stderr, "no round")
  end

  def test_commits_only_review_md_when_other_files_are_staged
    write_review(round(1, "No findings."))
    File.write(File.join(@repo, "other.txt"), "x\n")
    git("add", "other.txt")

    _, stderr, status = commit_review

    assert(status.success?, stderr)
    assert_equal("docs/changes/#{SLUG}/review.md\n", git("show", "--name-only", "--format=", "HEAD"))
    assert_equal("A  other.txt\n", git("status", "--porcelain"))
  end

  def test_a_second_run_has_nothing_to_commit
    write_review(round(1, "No findings."))
    commit_review
    before = commit_count

    stdout, _, status = commit_review

    assert(status.success?)
    assert_includes(stdout, "Nothing to commit")
    assert_equal(before, commit_count)
  end

  def test_the_commit_subject_names_the_slug
    write_review(round(1, "No findings."))

    commit_review

    assert_equal("Review for #{SLUG}", git("log", "-1", "--format=%s").strip)
  end

  def test_it_never_pushes
    write_review(round(1, "No findings."))

    commit_review

    refute_includes(origin_branches, SLUG)
  end

  private

  def round(number, *findings)
    "## Round #{number} — 2026-10-15T10:00:00Z — abc1234\n\n#{findings.join("\n")}\n"
  end

  def write_review(*rounds)
    path = File.join(@repo, "docs/changes/#{SLUG}/review.md")
    File.write(path, "# Review\n\n#{rounds.join("\n")}")
  end

  def commit_review
    stdout, stderr, status = run_script(COMMIT_REVIEW)
    [ stdout, stderr, status ]
  end

  def commit_count
    git("rev-list", "--count", "HEAD").to_i
  end
end
