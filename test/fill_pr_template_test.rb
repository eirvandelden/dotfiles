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

  PLAN_WITHOUT_PROOF = <<~MARKDOWN
    # Plan: Claims status export

    Status: accepted.

    ## Files that change

    `app/models/claim.rb`: adds `#export_status`.

    ## Order of work

    1. Write the acceptance test, watch it fail.
    2. Add `#export_status`.
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

  def test_a_choice_list_testing_heading_gets_the_plans_proof_appended
    output = run_fill(<<~MARKDOWN)
      ## Description

      TODO

      ## Testing

      - [ ] Unit tests added
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(/- \[ \] Unit tests added/, output)
    assert_match(/## Proof\n\n.*test_shows_export_status/m, output)
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

    filled_section = output[/## How has this been tested\?\n\n(.*?)\n\n##/m, 1]
    assert_match(/test_shows_export_status/, filled_section)
    assert_no_match(%r{app/models/claim\.rb}, filled_section)
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

  def test_a_screenshots_slash_showcase_heading_keeps_its_own_text
    output = run_fill(<<~MARKDOWN)
      ## Screenshots / showcase

      _attach screenshots here_
    MARKDOWN

    assert_match(%r{## Screenshots / showcase\n\n_attach screenshots here_}, output)
  end

  def test_a_latest_release_notes_heading_keeps_its_own_text
    output = run_fill(<<~MARKDOWN)
      ## Latest release notes

      _list the changes_
    MARKDOWN

    assert_match(/## Latest release notes\n\n_list the changes_/, output)
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

  def test_a_template_with_no_matching_headings_gets_four_sections_appended
    output = run_fill(<<~MARKDOWN)
      ## Screenshots

      _attach screenshots here_
    MARKDOWN

    assert_match(/\A## Screenshots\n\n_attach screenshots here_/, output)
    assert_match(/## Summary/, output)
    assert_match(/## Why/, output)
    assert_match(/## Implementation/, output)
    assert_match(/## Proof/, output)
    assert_match(/Claims adjusters cannot see export status/, output)
  end

  def test_no_template_produces_four_sections_from_intent_and_plan_alone
    output = run_fill(nil)

    assert_match(/\A## Summary/, output)
    assert_match(/## Why/, output)
    assert_match(/## Implementation/, output)
    assert_match(/## Proof/, output)
    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(%r{app/models/claim\.rb}, output)
    assert_match(/test_shows_export_status/, output)
  end

  def test_a_how_to_test_sub_heading_that_gets_absorbed_still_gets_the_proof_appended
    output = run_fill(<<~MARKDOWN)
      ## Description

      TODO

      ### How to test

      TODO
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(/## Proof\n\n.*test_shows_export_status/m, output)
  end

  def test_a_testing_notes_sub_heading_kept_verbatim_by_a_choice_list_sibling_still_gets_the_proof_appended
    output = run_fill(<<~MARKDOWN)
      ## Description

      TODO

      ### Type of change

      - [ ] Bug fix
      - [ ] Feature

      ### Testing notes

      _describe how you tested this_

      ## Why

      TODO
    MARKDOWN

    assert_match(/### Testing notes\n\n_describe how you tested this_/, output)
    assert_match(/## Proof\n\n.*test_shows_export_status/m, output)
  end

  def test_a_second_heading_of_an_already_filled_category_keeps_its_template_text
    output = run_fill(<<~MARKDOWN)
      ## Summary

      TODO

      ## Description

      _still the template text_
    MARKDOWN

    assert_match(/Claims adjusters cannot see export status/, output)
    assert_match(/## Description\n\n_still the template text_/, output)
  end

  def test_a_missing_proof_in_the_plan_is_not_appended_as_an_empty_heading
    output = run_fill(<<~MARKDOWN, plan: PLAN_WITHOUT_PROOF)
      ## Screenshots

      _attach screenshots here_
    MARKDOWN

    assert_match(/## Implementation/, output)
    assert_no_match(/## Proof/, output)
  end

  private

  def run_fill(template, plan: PLAN)
    intent_path = write("intent.md", INTENT)
    plan_path = write("plan.md", plan)
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
