#!/usr/bin/env ruby
require "minitest/autorun"

# Every instruction that says "test first" carries the same mobile exception, so a blanket rule
# elsewhere cannot negate it (docs/changes/hotwire-native-agent-guidance/plan.md, canonical wording).
class MobileTestingExceptionTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  EXCEPTION_PHRASE = "build, lint and simulator or device checks"
  RAILS_PHRASE = "Rails and web code keep the test-first rule"
  INSTRUCTIONS = %w[
    agents.md
    claude/.claude/skills/rails-testing/SKILL.md
    claude/.claude/skills/code-review/SKILL.md
    claude/.claude/skills/plan/SKILL.md
    claude/.claude/skills/implement/SKILL.md
    claude/.claude/agents/test-writer.md
    claude/.claude/agents/implementer.md
  ].freeze

  def test_every_listed_instruction_states_the_mobile_exception
    INSTRUCTIONS.each do |path|
      text = read(path)
      assert(text.include?(EXCEPTION_PHRASE), "#{path} lacks the mobile exception")
      assert(text.include?(RAILS_PHRASE), "#{path} lacks the Rails-unchanged sentence")
    end
  end

  def test_no_file_says_never_generate_code_without_a_test_without_the_exception
    blanket = /never generate code without a corresponding test/i
    INSTRUCTIONS.each do |path|
      text = read(path)
      next unless text.match?(blanket)

      assert(text.include?(EXCEPTION_PHRASE), "#{path} has the blanket rule without the exception")
    end
  end

  def test_rails_testing_still_requires_tests_first_for_rails_code
    text = read("claude/.claude/skills/rails-testing/SKILL.md")
    assert(text.include?("create the test first"), "rails-testing lost its test-first line")
    assert(text.include?(RAILS_PHRASE), "rails-testing lacks the Rails-unchanged sentence")
  end

  def test_plan_skill_defines_the_check_proof_line
    assert(read("claude/.claude/skills/plan/SKILL.md").include?("→ check:"), "plan skill lacks the check: Proof line form")
  end

  private

  def read(path)
    File.read(File.join(REPO_ROOT, path))
  end
end
