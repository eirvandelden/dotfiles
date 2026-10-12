#!/usr/bin/env ruby
require "minitest/autorun"

# Reviews check the design as well as the code: a Design pass joins Bugs, Security and Compliance.
class DesignReviewPassTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_the_reviewer_runs_a_design_pass
    assert_match(/\bDesign pass\b|\bDesign\b.*pass/i, reviewer)
  end

  def test_the_reviewer_still_runs_bugs_security_and_compliance
    assert_match(/Bugs, Security,? (and )?Compliance/, reviewer)
  end

  def test_the_design_pass_names_all_four_findings
    pass = reviewer[/^.*Design.*(?:\n(?!\d+\. ).*)*/] || flunk("no Design pass in reviewer.md")

    assert_match(/public method.*(sign|RBS)/i, pass)
    assert_match(/Law of Demeter/i, pass)
    assert_match(/N\+1/, pass)
    assert_match(/glossary.*avoid|avoid.*glossary/i, pass)
  end

  def test_the_review_template_lists_the_design_pass
    template = File.read(File.join(ROOT, "claude/.claude/skills/new-repo-setup/references/REVIEW.md"))

    assert_match(/design/i, template)
  end

  def test_the_review_pane_prompt_names_the_design_pass
    script = File.read(File.join(ROOT, "herdr/.config/herdr/scripts/start-review.sh"))

    assert_match(/Bugs, Security, Compliance and Design|Design pass/i, script)
  end

  private

  def reviewer
    File.read(File.join(ROOT, "claude/.claude/agents/reviewer.md"))
  end
end
