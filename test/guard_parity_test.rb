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
  CODEX_CONFIG = File.join(REPO_ROOT, "codex/.codex/config.toml")
  CLAUDE_SETTINGS = File.join(REPO_ROOT, "claude/.claude/settings.json")

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

  def test_codex_runs_the_same_consent_guard_command_as_claude_for_shell_commands
    assert_same_hook(claude_hook("Bash", "consent-guard.rb"), codex_hook("^Bash$"), "^Bash$")
  end

  def test_codex_runs_the_same_test_guard_command_as_claude_for_file_edits
    assert_same_hook(claude_hook("Edit|Write|MultiEdit", "test-guard.rb"), codex_hook("^apply_patch$"), "^apply_patch$")
  end

  private

  def assert_same_hook(claude_command, codex_command, matcher)
    refute_nil(claude_command, "claude/.claude/settings.json has no PreToolUse hook for that script")
    refute_nil(codex_command, "codex/.codex/config.toml has no [[hooks.PreToolUse]] entry with matcher #{matcher}")
    assert_equal(claude_command, codex_command)
  end

  # Every prefix_rule as { pattern:, decision: }. The rules language is not JSON, but its rules only use
  # string lists, which read as JSON.
  def rules
    @rules ||= File.read(RULES).scan(/prefix_rule\(\s*pattern\s*=\s*(\[.*?\])\s*,\s*decision\s*=\s*"(\w+)"/m)
                   .map { |pattern, decision| { pattern: JSON.parse(pattern), decision: decision } }
  end

  def claude_hook(matcher, script)
    entry = JSON.parse(File.read(CLAUDE_SETTINGS)).dig("hooks", "PreToolUse").find { |hook| hook["matcher"] == matcher }
    entry.fetch("hooks").map { |hook| hook["command"] }.find { |command| command.include?(script) }
  end

  # The command of the inline [[hooks.PreToolUse]] entry with this matcher. Codex runs it through
  # a shell, so the same "$HOME/..." string Claude uses expands the same way.
  def codex_hook(matcher)
    entries = File.read(CODEX_CONFIG).split(/^\[\[hooks\.PreToolUse\]\]\n/).drop(1)
    entry = entries.find { |text| text[/^matcher = "(.*)"$/, 1] == matcher }
    entry && entry[/^command = '(.*)'$/, 1]
  end
end
