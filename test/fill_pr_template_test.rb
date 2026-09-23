#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# finish fills the work PR template from intent.md and plan.md before opening
# it for the team, so colleagues see something written for them instead of an
# empty template. A heading is matched by what it asks for, not by its exact
# wording, so any repository's own phrasing still gets filled; a heading
# nothing matches keeps its own text.
class FillPrTemplateTest < Minitest::Test
  SCRIPT = File.expand_path("../claude/.claude/skills/finish/scripts/fill-pr-template", __dir__)

  INTENT = <<~MARKDOWN
    # Intent: Claims status export

    Author: Test. Status: accepted.

    ## Problem

    Claims adjusters cannot see export status without asking engineering.

    ## Proposed outcome

    The export status appears on the claim page within a minute of the run finishing.
  MARKDOWN

  PLAN = <<~MARKDOWN
    # Plan: Claims status export

    Status: accepted.

    ## Files that change

    `app/models/claim.rb`: adds `#export_status`.

    ## Order of work

    1. Write the acceptance test, watch it fail.
    2. Add `#export_status`.

    ## Proof

    - Claims adjusters see export status → `test/system/claim_export_test.rb` `test_shows_export_status`
  MARKDOWN

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_plain_template_gets_its_matching_headings_filled
    output = run_fill(<<~MARKDOWN)
      ## Summary

      _describe what this changes_

      ## Why

      _describe the motivation_

      ## Implementation

      _how did you build it_

      ## Testing

      _how was this verified_
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(/export status appears on the claim page/, output)
    assert_match(%r{app/models/claim\.rb}, output)
    assert_match(/Write the acceptance test/, output)
    assert_match(/test_shows_export_status/, output)
    assert_no_match(/_describe what this changes_/, output)
  end

  def test_a_checkbox_style_template_gets_its_matching_headings_filled_too
    output = run_fill(<<~MARKDOWN)
      ## What does this PR do?

      TODO

      ## Why is this needed?

      TODO

      ## How was this implemented?

      TODO

      ## Test plan

      - [ ] Added tests
      - [ ] Ran the linter
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(%r{app/models/claim\.rb}, output)
    assert_match(/test_shows_export_status/, output)
    assert_no_match(/- \[ \] Added tests/, output)
  end

  def test_a_how_has_this_been_tested_heading_gets_the_plans_proof_not_its_files
    output = run_fill(<<~MARKDOWN)
      ## How has this been tested?

      TODO
    MARKDOWN

    assert_match(/test_shows_export_status/, output)
    assert_no_match(%r{app/models/claim\.rb}, output)
  end

  def test_an_unmatched_heading_among_matched_ones_keeps_its_own_text
    output = run_fill(<<~MARKDOWN)
      ## Summary

      _describe what this changes_

      ## Rollout notes

      _flag or migration to coordinate_

      ## Testing

      _how was this verified_
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(/test_shows_export_status/, output)
    assert_match(/flag or migration to coordinate/, output)
  end

  def test_an_unmatched_heading_keeps_its_template_text
    output = run_fill(<<~MARKDOWN)
      ## Screenshots

      _attach screenshots here_
    MARKDOWN

    assert_match(/attach screenshots here/, output)
  end

  def test_a_template_with_no_matching_headings_gets_a_context_block_prepended
    output = run_fill(<<~MARKDOWN)
      ## Screenshots

      _attach screenshots here_
    MARKDOWN

    assert_match(/\A## Context/, output)
    assert_match(/Claims adjusters cannot see export status/, output)
  end

  def test_no_template_produces_a_context_block_from_intent_and_plan_alone
    output = run_fill(nil)

    assert_match(/\A## Context/, output)
    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(%r{app/models/claim\.rb}, output)
    assert_match(/test_shows_export_status/, output)
  end

  private

  def run_fill(template)
    intent_path = write("intent.md", INTENT)
    plan_path = write("plan.md", PLAN)
    template_path = template.nil? ? "" : write("template.md", template)

    stdout, stderr, status = Open3.capture3(SCRIPT, template_path, intent_path, plan_path)
    assert(status.success?, stderr)
    stdout
  end

  def write(name, content)
    path = File.join(@dir, name)
    File.write(path, content)
    path
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end

  def assert_no_match(pattern, value, message = nil)
    assert_not(pattern.match?(value), message || "Expected #{value.inspect} not to match #{pattern.inspect}")
  end
end
