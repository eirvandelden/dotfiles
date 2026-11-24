#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "playbook"

# Etienne approves a plan with "accepted" or "agreed", or in interactive Claude by approving
# ExitPlanMode. The Status: line stays "accepted" either way.
class ApprovalWordTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)

  def test_the_plan_skill_moves_on_when_agreed_or_agree_the_plan
    accept = accept_section

    assert_includes(accept, "\"agreed\"")
    assert_includes(accept, "\"agree the plan\"")
  end

  def test_the_plan_skill_does_not_move_on_for_looks_good_ok_or_sounds_right
    accept = accept_section
    skill = skill_text("plan")

    assert_includes(accept, "not \"looks good\", not \"ok\"")
    assert_includes(skill, "Treating \"sounds right\" as \"accepted\" — only the acceptance in step 7 flips the status.")
  end

  def test_the_plan_skill_writes_status_accepted_with_a_date_on_acceptance
    assert_includes(accept_section, "`Status: accepted (<date>)`")
  end

  def test_the_playbook_names_accepted_first_and_agreed_as_the_alternative
    rule = rule_17
    accepted_at = rule.index("\"accepted\"") || flunk("no \"accepted\" in rule 17")
    agreed_at = rule.index("\"agreed\"") || flunk("no \"agreed\" in rule 17")

    assert_operator(accepted_at, :<, agreed_at)
  end

  def test_the_playbook_names_the_plan_phrases_and_exit_plan_mode
    rule = rule_17

    assert_includes(rule, "\"accept the plan\"")
    assert_includes(rule, "\"agree the plan\"")
    assert_includes(rule, "`ExitPlanMode`")
  end

  private

  def rule_17
    Playbook.text[/^17\. .*?(?=^18\. )/m] || flunk("no rule 17")
  end

  def skill_text(name)
    File.read(File.join(REPO_ROOT, "agents/.agents/skills/#{name}/SKILL.md"))
  end

  def accept_section
    skill_text("plan")[/^#### 7\. Accept\n(.*?)(?=^## )/m, 1] || flunk("no step 7 in plan")
  end
end
