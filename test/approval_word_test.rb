#!/usr/bin/env ruby
require "minitest/autorun"

# Etienne approves a stage with "accepted" or "agreed". The Status: line stays "accepted" either way.
class ApprovalWordTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)

  def test_the_intent_skill_moves_on_when_agreed_or_agree_the_intent
    accept = section("intent", "## 4. Accept")

    assert_includes(accept, "\"agreed\"")
    assert_includes(accept, "\"agree the intent\"")
  end

  def test_the_intent_skill_does_not_move_on_for_looks_good_ok_or_sounds_right
    accept = section("intent", "## 4. Accept")
    skill = skill_text("intent")

    assert_includes(accept, "not \"looks good\", not \"ok\"")
    assert_includes(skill, "Treating \"sounds right\" as \"accepted\" — only the words listed in step 4 flip the status.")
  end

  def test_the_spec_skill_flips_status_to_accepted_when_agreed
    accept = section("spec", "### 4. Accept")

    assert_includes(accept, "literal word \"accepted\" or \"agreed\", flip it")
    assert_includes(accept, "`accepted`")
  end

  def test_the_plan_skill_flips_status_to_accepted_when_agreed
    step = skill_text("plan")[/^7\. .*$/] || flunk("no step 7 in plan")

    assert_includes(step, "`Status: accepted` only on the user's literal word \"accepted\" or \"agreed\"")
    assert_includes(step, "On either word")
  end

  def test_the_playbook_names_accepted_first_and_agreed_as_the_alternative
    rule = rule_17
    accepted_at = rule.index("\"accepted\"") || flunk("no \"accepted\" in rule 17")
    agreed_at = rule.index("\"agreed\"") || flunk("no \"agreed\" in rule 17")

    assert_operator(accepted_at, :<, agreed_at)
  end

  def test_the_playbook_names_the_intent_phrases_too
    rule = rule_17

    assert_includes(rule, "\"accept the intent\"")
    assert_includes(rule, "\"agree the intent\"")
  end

  private

  def rule_17
    File.read(File.join(REPO_ROOT, "agents.md"))[/^17\. .*?(?=^18\. )/m] || flunk("no rule 17")
  end

  def skill_text(name)
    File.read(File.join(REPO_ROOT, "claude/.claude/skills/#{name}/SKILL.md"))
  end

  def section(skill, heading)
    skill_text(skill)[/^#{Regexp.escape(heading)}\n(.*?)(?=^#|\z)/m, 1] || flunk("no #{heading} in #{skill}")
  end
end
