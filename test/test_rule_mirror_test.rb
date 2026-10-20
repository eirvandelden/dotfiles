#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# Playbook rule 3 (agents.md) is the source of the lean test rule. Every instruction that repeats it
# carries each of its lines verbatim (docs/changes/lean-test-rule/plan.md, canonical wording).
class TestRuleMirror
  RULE_HEADING = /^3\. Tests:\n/
  RULE_END = /^   - Run tests after every change/

  def initialize(playbook_text)
    @playbook_text = playbook_text
  end

  def rule_lines
    body = @playbook_text.split(RULE_HEADING, 2)[1]
    raise "rule 3 not found in the playbook" unless body

    body.split(RULE_END, 2).first.lines.map { |line| line.strip.delete_prefix("- ") }.reject(&:empty?)
  end

  def missing_from(mirror_text)
    rule_lines.reject { |line| mirror_text.include?(line) }
  end
end

class TestRuleMirrorTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  PLAYBOOK = "agents.md"
  MIRRORS = %w[
    agents/.agents/skills/rails-testing/SKILL.md
    agents/.agents/skills/code-review/SKILL.md
    agents/.agents/skills/plan/SKILL.md
    agents/.agents/skills/implement/SKILL.md
    agents/.agents/skills/hotwire-native/SKILL.md
    claude/.claude/agents/test-writer.md
    claude/.claude/agents/implementer.md
    codex/.codex/agents/test-writer.toml
    codex/.codex/agents/implementer.toml
    claude/.claude/core-values.yml
  ].freeze
  LEGACY_PHRASES = [
    /never generate code without a corresponding test/i,
    /mobile exception/i,
    /build, lint and simulator or device checks instead of a test written first/i
  ].freeze

  def test_playbook_rule_3_requires_tests_for_code_and_none_for_configuration
    assert_includes(rule_lines, "Every code change has tests. Configuration has no tests.")
  end

  def test_playbook_rule_3_gives_a_new_feature_an_integration_test_and_unit_tests
    line = rule_lines.grep(/new feature/).first

    assert_match(/integration test that proves it works and keeps working/, line)
    assert_match(/unit tests of its public methods and classes/, line)
  end

  def test_playbook_rule_3_tests_public_methods_and_classes_and_never_private_methods
    line = rule_lines.grep(/private methods/i).first

    assert_match(/Test public methods and classes only/, line)
    assert_match(/Private methods never get tests of their own/, line)
  end

  def test_playbook_rule_3_keeps_the_regression_test_of_a_bug_fix_first
    line = rule_lines.grep(/bug fix/).first

    assert_match(/regression test comes first and fails before the fix/, line)
  end

  def test_no_mirror_keeps_the_blanket_rule_or_the_mobile_exception
    ([ PLAYBOOK ] + MIRRORS).each do |path|
      LEGACY_PHRASES.each do |phrase|
        refute_match(phrase, read(path), "#{path} still carries #{phrase.inspect}")
      end
    end
  end

  def test_every_mirror_carries_the_playbook_test_rule
    mirror = TestRuleMirror.new(read(PLAYBOOK))

    MIRRORS.each do |path|
      assert_empty(mirror.missing_from(read(path)), "#{path} drifted from playbook rule 3")
    end
  end

  def test_drift_check_reports_the_line_a_mirror_lacks
    mirror = TestRuleMirror.new(playbook_fixture)

    assert_equal([ "Second line." ], mirror.missing_from("First line.\n"))
  end

  def test_drift_check_reports_nothing_when_the_mirror_agrees
    mirror = TestRuleMirror.new(playbook_fixture)

    assert_empty(mirror.missing_from("- First line.\n  - Second line.\n"))
  end

  def test_plan_skill_defines_the_check_proof_line
    text = read("agents/.agents/skills/plan/SKILL.md")

    assert_includes(text, "→ check:", "plan skill lacks the check: Proof line form")
    assert_includes(text, "needs no test", "plan skill lacks the no-test criterion wording")
  end

  private

  def rule_lines
    TestRuleMirror.new(read(PLAYBOOK)).rule_lines
  end

  def playbook_fixture
    "3. Tests:\n   - First line.\n   - Second line.\n   - Run tests after every change.\n"
  end

  def read(path)
    File.read(File.join(REPO_ROOT, path))
  end
end
