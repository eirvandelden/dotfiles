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

  def test_a_checkbox_style_templates_prose_headings_get_filled_but_its_checkboxes_stay
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
    assert_match(/- \[ \] Added tests/, output)
    assert_match(/- \[ \] Ran the linter/, output)
  end

  def test_a_description_heading_is_filled_with_the_summary_text
    output = run_fill(<<~MARKDOWN)
      ## Description

      TODO

      ## What type of change is this?

      - [ ] Bug fix
      - [ ] Feature
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(/- \[ \] Bug fix/, output)
    assert_match(/- \[ \] Feature/, output)
  end

  def test_a_what_type_of_change_heading_with_checkboxes_keeps_its_checkboxes
    output = run_fill(<<~MARKDOWN)
      ## Summary

      TODO

      ## What type of change is this?

      - [ ] Bug fix
      - [ ] Feature
    MARKDOWN

    assert_match(/- \[ \] Bug fix/, output)
    assert_match(/- \[ \] Feature/, output)
  end

  def test_a_choice_list_sub_heading_of_a_matched_heading_keeps_its_checkboxes
    output = run_fill(<<~MARKDOWN)
      ## Description

      TODO

      ### Type of change

      - [ ] Bug fix
      - [ ] Feature
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(/### Type of change/, output)
    assert_match(/- \[ \] Bug fix/, output)
    assert_match(/- \[ \] Feature/, output)
  end

  def test_a_choice_list_sub_heading_after_a_prose_sub_heading_still_keeps_its_checkboxes
    output = run_fill(<<~MARKDOWN)
      ## Testing

      TODO

      ### Notes

      _prose to absorb_

      ### Type of change

      - [ ] Bug fix
      - [ ] Feature
    MARKDOWN

    assert_match(/test_shows_export_status/, output)
    assert_no_match(/prose to absorb/, output)
    assert_match(/### Type of change/, output)
    assert_match(/- \[ \] Bug fix/, output)
    assert_match(/- \[ \] Feature/, output)
  end

  def test_a_what_does_this_pr_do_heading_is_filled
    output = run_fill(<<~MARKDOWN)
      ## What does this PR do?

      TODO
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
  end

  def test_a_what_type_of_change_heading_without_checkboxes_is_still_not_filled
    output = run_fill(<<~MARKDOWN)
      ## What type of change

      Pick one: bug fix, feature, chore.
    MARKDOWN

    assert_match(/Pick one: bug fix, feature, chore\./, output)
  end

  def test_a_how_has_this_been_tested_heading_gets_the_plans_proof_not_its_files
    output = run_fill(<<~MARKDOWN)
      ## How has this been tested?

      TODO
    MARKDOWN

    assert_match(/test_shows_export_status/, output)
    assert_no_match(%r{app/models/claim\.rb}, output)
  end

  def test_a_filled_section_ends_with_a_blank_line_before_the_next_heading
    output = run_fill(<<~MARKDOWN)
      ## Why

      _describe the motivation_

      ## Implementation

      _how did you build it_
    MARKDOWN

    assert_match(/without asking engineering\.\n\n## Implementation/, output)
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

  def test_a_sub_heading_under_a_matched_heading_is_not_filled_a_second_time
    output = run_fill(<<~MARKDOWN)
      ## Testing

      TODO

      ### Steps to verify

      TODO
    MARKDOWN

    assert_equal(1, output.scan(/test_shows_export_status/).length)
  end

  def test_a_heading_like_line_inside_a_fenced_code_block_is_not_split_on
    output = run_fill(<<~MARKDOWN)
      ## Summary

      ```sh
      # run this
      echo hello
      ```

      ## Rollout notes

      _flag or migration to coordinate_
    MARKDOWN

    assert_no_match(/# run this\necho hello/, output)
    assert_match(/flag or migration to coordinate/, output)
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
