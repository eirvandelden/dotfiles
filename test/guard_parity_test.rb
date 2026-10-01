#!/usr/bin/env ruby
require "minitest/autorun"
require "json"

# The consent guard and the test guard run in both tools from one script each under
# claude/.claude/hooks/. Claude calls them from settings.json, Codex from the inline [hooks]
# table in its config.toml. Codex's rules/default.rules is the second layer under the hook:
# Codex appends an `allow` rule there on every "always allow" approval, and that cannot be
# turned off, so this test is what keeps an approval from quietly loosening a guarded command
# or leaking a machine path into this public repository.
class GuardParityTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  RULES = File.join(REPO_ROOT, "codex/.codex/rules/default.rules")

  GUARDED_COMMANDS = [
    %w[git push --force], %w[git commit --no-verify], %w[git push --no-verify],
    %w[gh pr comment], %w[gh pr review], %w[gh issue comment],
    %w[kamal deploy], %w[kamal app exec], %w[cap deploy]
  ].freeze
  MACHINE_PATHS = %w[/Users/ /private/ /opt/ /Applications/].freeze

  def test_no_allow_rule_begins_with_a_guarded_command
    allow_patterns = rules.select { |rule| rule[:decision] == "allow" }.map { |rule| rule[:pattern] }

    GUARDED_COMMANDS.each do |guarded|
      offender = allow_patterns.find { |pattern| pattern.first(guarded.length) == guarded }
      assert_nil(offender, "an allow rule loosens the guarded #{guarded.join(' ')}: #{offender.inspect}")
    end
  end

  def test_every_guarded_command_has_a_prompt_or_forbidden_rule_under_the_hook
    GUARDED_COMMANDS.each do |guarded|
      covered = rules.any? do |rule|
        rule[:decision] != "allow" && guarded.first(rule[:pattern].length) == rule[:pattern]
      end
      assert(covered, "no prompt or forbidden rule covers #{guarded.join(' ')}")
    end
  end

  def test_a_plain_force_push_is_forbidden_rather_than_prompted
    force_push = rules.find { |rule| rule[:pattern] == %w[git push --force] }

    assert_equal("forbidden", force_push&.fetch(:decision))
  end

  def test_no_rule_names_a_machine_path
    leaking = File.readlines(RULES).grep_v(/\A\s*#/).select { |line| MACHINE_PATHS.any? { |path| line.include?(path) } }

    assert_empty(leaking, "rules name a machine path")
  end

  private

  # Every prefix_rule as { pattern:, decision: }. The rules language is not JSON, but its rules only use
  # string lists, which read as JSON.
  def rules
    @rules ||= File.read(RULES).scan(/prefix_rule\(\s*pattern\s*=\s*(\[.*?\])\s*,\s*decision\s*=\s*"(\w+)"/m)
                   .map { |pattern, decision| { pattern: JSON.parse(pattern), decision: decision } }
  end
end
