#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "../agents/.agents/skills/plan/scripts/plan_metadata"

# PlanMetadata reads only the header paragraph straight under "# Plan: <title>", so a Markdown
# example further down never grants acceptance or autonomy.
class PlanMetadataTest < Minitest::Test
  def test_accepts_a_dated_status_and_reads_autonomy
    text = plan("Author: E. Status: accepted (2026-11-24). Type: feature. Delivery: autonomous.")

    assert(PlanMetadata.accepted?(text))
    assert(PlanMetadata.autonomous?(text))
  end

  def test_accepts_an_undated_status_with_fields_in_any_order
    text = plan("Author: E. Delivery: autonomous. Status: accepted.")

    assert(PlanMetadata.accepted?(text))
    assert(PlanMetadata.autonomous?(text))
  end

  def test_reads_codex_review_inline_and_fields_on_their_own_lines
    assert(PlanMetadata.autonomous?(plan("Author: E. Status: accepted. Delivery: autonomous. Codex review: yes.")))
    assert(PlanMetadata.autonomous?(plan("Author: E. Status: accepted. Type: feature.\nCodex review: no\nDelivery: autonomous")))
  end

  def test_a_draft_is_not_accepted
    refute(PlanMetadata.accepted?(plan("Status: draft. Delivery: autonomous.")))
  end

  def test_a_step_by_step_plan_is_not_autonomous
    refute(PlanMetadata.autonomous?(plan("Status: accepted. Delivery: step-by-step.")))
  end

  def test_a_conflicting_later_delivery_or_status_refuses
    refute(PlanMetadata.autonomous?(plan("Status: accepted. Delivery: step-by-step.\nDelivery: autonomous")))
    refute(PlanMetadata.accepted?(plan("Status: accepted. Delivery: autonomous.\nStatus: draft.")))
  end

  def test_a_delivery_choice_that_only_starts_with_autonomous_is_not_autonomous
    refute(PlanMetadata.autonomous?(plan("Status: accepted. Delivery: autonomous-example.")))
  end

  def test_metadata_in_the_body_grants_nothing
    [ "## Constraints\n\nDelivery: autonomous\n", "```text\nDelivery: autonomous\n```\n", "# Notes\nDelivery: autonomous\n" ].each do |body|
      refute(PlanMetadata.autonomous?("# Plan: x\n\nStatus: accepted.\n\n#{body}"), body)
    end
  end

  def test_metadata_without_a_plan_title_grants_nothing
    [ "```text\nStatus: accepted. Delivery: autonomous.\n```\n", "> note\nStatus: accepted.\n", "# Intent: x\n\nStatus: accepted.\n",
     "# Example\n\nStatus: accepted.\n", "# Plan: x\n\n> Status: accepted.\n", "# Plan: x\n\n    Status: accepted.\n", "" ].each do |text|
      refute(PlanMetadata.accepted?(text), text)
    end
  end

  def test_status_text_inside_another_field_grants_nothing
    refute(PlanMetadata.accepted?(plan("Type: feature; example Status: accepted. Delivery: autonomous.")))
  end

  def test_metadata_after_body_text_or_a_non_plan_title_grants_nothing
    [ "An example follows.\n\nStatus: accepted. Delivery: autonomous.\n", "# Example\n\nStatus: accepted. Delivery: autonomous.\n" ].each do |text|
      refute(PlanMetadata.accepted?(text), text)
      refute(PlanMetadata.autonomous?(text), text)
    end
  end

  def test_a_delivery_line_after_a_fenced_example_or_setext_heading_grants_nothing
    [ "```text\nDelivery: autonomous\n```\n", "Constraints\n-----------\nDelivery: autonomous\n", "Examples follow:\nDelivery: autonomous\n" ].each do |body|
      refute(PlanMetadata.autonomous?("# Plan: x\n\nStatus: accepted.\n#{body}"), body)
    end
  end

  def test_a_second_title_heading_ends_the_header
    refute(PlanMetadata.autonomous?("# Plan: x\n\nStatus: accepted.\n# Notes\nDelivery: autonomous\n"))
  end

  def test_a_draft_status_that_quotes_an_accepted_one_stays_a_draft
    refute(PlanMetadata.accepted?(plan("Status: draft. Delivery: autonomous. Example Status: accepted")))
  end

  def test_an_accepted_status_stays_accepted_when_the_body_quotes_a_draft_one
    text = "# Plan: x\n\nStatus: accepted.\n\nThe old line read Status: draft.\n"

    assert(PlanMetadata.accepted?(text))
  end

  private

  def plan(header)
    "# Plan: x\n\n#{header}\n\n## Problem\n\nBody.\n"
  end
end
