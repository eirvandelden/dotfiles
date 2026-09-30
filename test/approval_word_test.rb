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
    assert_includes(skill, "Treating \"sounds right\" as \"accepted\" — only the literal word \"accepted\" or \"agreed\" flips the status.")
  end

  private

  def skill_text(name)
    File.read(File.join(REPO_ROOT, "claude/.claude/skills/#{name}/SKILL.md"))
  end

  def section(skill, heading)
    skill_text(skill)[/^#{Regexp.escape(heading)}\n(.*?)(?=^#|\z)/m, 1] || flunk("no #{heading} in #{skill}")
  end
end
