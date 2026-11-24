#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "../agents/.agents/skills/plan/scripts/plan_critique"

# PlanCritique decides when the critique of an autonomous plan is closed: every finding ends in
# "fixed (<subject>)" or "dismissed: <reason>", or its round says "No findings.".
class PlanCritiqueTest < Minitest::Test
  CLOSED = <<~MD
    ## Critique

    ### Round 1 (codex)

    - The plan skips the rollback path → fixed (added step 4)
    - Naming is vague → dismissed: the name matches the existing module
  MD

  def test_a_fully_closed_critique_is_closed
    assert(PlanCritique.closed?("Body.\n\n#{CLOSED}"))
  end

  def test_a_round_that_states_no_findings_is_closed
    assert(PlanCritique.closed?("## Critique\n\n### Round 1 (codex)\n\nNo findings.\n"))
  end

  def test_a_closed_finding_with_an_explaining_sub_bullet_is_closed
    assert(PlanCritique.closed?("#{CLOSED}  - The rollback runs before the migration\n"))
  end

  def test_no_critique_section_is_not_closed
    assert_problem("", /no Critique section/)
  end

  def test_a_critique_without_a_round_is_not_closed
    assert_problem("## Critique\n\nLooks fine.\n", /no Round heading/)
  end

  {
    "an open finding" => "- Missing a test →\n",
    "a finding without a closure slot" => "- Missing a test\n",
    "a dismissal without a reason" => "- Naming is vague → dismissed:\n",
    "a fix without a subject" => "- Missing a test → fixed ()\n",
    "a quoted closed slot that ends open" => "- \"→ fixed (x)\" is the wrong format →\n",
    "an indented finding without a closed parent" => "  - Missing a test →\n",
    "an open numbered finding" => "1. Missing a test →\n",
    "an open plus finding" => "+ Missing a test →\n",
    "an open finding written as a paragraph" => "Missing a test →\n",
    "an open finding in a block quote" => "> - Missing a test →\n",
    "a round without any finding" => "",
    "a finding without text" => "- → fixed (renamed)\n",
    "a trailing bare arrow without a newline" => "- Missing a test → fixed (added) →",
    "a finding hidden behind a fenced heading" =>
      "- Naming → fixed (renamed)\n\n```\n## Notes\n```\n\n- Missing a test →\n"
  }.each do |name, round|
    define_method("test_#{name.tr(' ', '_')}_is_not_closed") do
      assert_problem("## Critique\n\n### Round 1 (codex)\n\n#{round}", /open critique findings|no finding/)
    end
  end

  def test_a_second_critique_section_is_not_closed
    assert_problem("#{CLOSED}\n## Critique\n\n### Round 2 (codex)\n\n- Naming → fixed (renamed)\n", /open critique/)
  end

  def test_a_section_after_the_critique_is_not_closed
    assert_problem("#{CLOSED}\n---\nDomain skills applied: None.\n", /open critique/)
  end

  private

  def assert_problem(text, pattern)
    refute(PlanCritique.closed?(text))
    assert_match(pattern, PlanCritique.problems(text).join)
  end
end
