#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "../agents/.agents/skills/review/scripts/review_file"

# Review reads the review.md of a change: its last reviewed commit and the commit subject that
# names the first finding.
class ReviewFileTest < Minitest::Test
  def test_reviewed_commit_answers_the_sha_of_the_last_round
    review = Review.new(text(round(1, "abc1234", "No findings."), round(2, "def5678", "No findings.")))

    assert_equal("def5678", review.reviewed_commit)
  end

  def test_reviewed_commit_ignores_a_trailing_reviewer_name
    review = Review.new("# Review\n\n## Round 1 — 2026-10-15T10:00:00Z — abc1234 (claude)\n\nNo findings.\n")

    assert_equal("abc1234", review.reviewed_commit)
  end

  def test_reviewed_commit_answers_nil_without_a_round
    assert_nil(Review.new("# Review\n\nNothing yet.\n").reviewed_commit)
  end

  def test_commit_subject_names_the_first_finding
    review = Review.new(text(round(1, "abc1234", "- [ ] Important: Widget leaks memory — `lib/widget.rb:1` → fixed (Plug)")))

    assert_equal("docs: review findings for Widget leaks memory", review.commit_subject("my-change"))
  end

  def test_commit_subject_takes_a_nit_when_it_comes_first
    review = Review.new(text(round(1, "abc1234", "- [ ] Nit: Naming drifts — `lib/widget.rb:2` → dismissed: house style")))

    assert_equal("docs: review findings for Naming drifts", review.commit_subject("my-change"))
  end

  def test_commit_subject_cuts_a_long_finding_at_a_word_boundary_within_72_characters
    long = "The widget leaks memory when the cache is full and the process keeps running for many days"
    review = Review.new(text(round(1, "abc1234", "- [ ] Important: #{long} — `lib/widget.rb:1` → fixed (Plug)")))

    subject = review.commit_subject("my-change")

    assert_operator(subject.length, :<=, 72)
    assert_equal("docs: review findings for The widget leaks memory when the cache is full", subject)
  end

  def test_commit_subject_names_the_slug_when_no_round_has_a_finding
    review = Review.new(text(round(1, "abc1234", "No findings.")))

    assert_equal("docs: review with no findings for my-change", review.commit_subject("my-change"))
  end

  private

  def round(number, sha, body)
    "## Round #{number} — 2026-10-15T10:00:00Z — #{sha}\n\n#{body}\n"
  end

  def text(*rounds)
    "# Review\n\n#{rounds.join("\n")}"
  end
end
