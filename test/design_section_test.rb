#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# The plan stage opens every plan with a design discussion. The skill text is the behaviour:
# an agent writes the template it finds there and stops where the skill says to stop.
class DesignSectionTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SUBSECTIONS = [ "Domain terms", "Diagrams", "Signatures", "Complexity", "Invariants", "Alternatives" ].freeze

  def test_the_plan_template_puts_the_design_section_before_the_files_that_change
    positions = [ /^\s*## Design\s*$/, /^\s*## Design decisions\s*$/, /^\s*## Files that change\s*$/ ].map do |heading|
      plan_skill.index(heading) || flunk("no #{heading.inspect} in the plan template")
    end

    assert_equal(positions.sort, positions)
  end

  def test_the_design_section_asks_for_terms_a_class_diagram_signatures_and_complexity
    SUBSECTIONS.each do |name|
      assert_match(/^\s*### #{name}\s*$/, plan_skill, "the plan template lacks ### #{name}")
    end
    assert_match(/class diagram/i, plan_skill)
    assert_match(/mermaid/i, plan_skill)
    assert_match(/inline RBS/i, plan_skill)
  end

  def test_each_design_subsection_shrinks_to_one_line_that_says_why
    assert_includes(plan_skill, "Not affected:")
    assert_match(/one line/i, plan_skill)
  end

  def test_the_plan_waits_for_the_design_to_be_agreed_after_showing_alternatives
    step = here_steps.find { |text| text.match?(/alternatives/i) } || flunk("no step shows alternatives")

    assert_match(/two or three/i, step)
    assert_match(/\barchitects\b/i, step)
    assert_match(/reject/i, step)
    assert_includes(step, "\"agreed\"")
    assert_operator(here_steps.index(step), :<, here_steps.index { |text| text.match?(/Write `<folder>\/plan\.md`/) })
  end

  def test_a_query_count_claim_names_its_test_in_proof
    assert_match(/^\s*- Query count: .*→/, plan_skill)
    assert_match(/query-count test/i, plan_skill)
  end

  def test_an_invariant_names_its_enforcement_and_its_test
    assert_match(/^\s*- Invariant: .*enforced by .*→/, plan_skill)
  end

  def test_the_software_design_skill_covers_deep_modules_messages_crc_connascence_and_solid
    path = File.join(ROOT, "agents/.agents/skills/software-design/SKILL.md")
    flunk("#{path} does not exist") unless File.exist?(path)
    text = File.read(path)

    [ /deep modules?/i, /messages/i, /CRC/, /connascence/i, /SOLID/, /service object/i ].each do |keyword|
      assert_match(keyword, text)
    end
  end

  private

  def plan_skill
    File.read(File.join(ROOT, "claude/.claude/skills/plan/SKILL.md"))
  end

  def here_steps
    here = plan_skill[/^### `here` backend\n(.*?)(?=^## )/m, 1] || flunk("no here backend section")
    here.scan(/^\d+\. .*(?:\n(?!\d+\. ).*)*/)
  end
end
