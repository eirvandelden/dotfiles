#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"
require_relative "isolated_git"

# Playbook rule 27 (agent questions) is mirrored in core-values.yml, which the SessionStart hook injects.
class QuestionRuleMirrorTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  PLAYBOOK = File.join(ROOT, "agents.md")
  CORE_VALUES = File.join(ROOT, "claude/.claude/core-values.yml")
  SETTINGS = File.join(ROOT, "claude/.claude/settings.json")
  HOOK = File.join(ROOT, "claude/.claude/hooks/core-values.rb")

  def test_core_values_carry_every_line_of_rule_27
    mirrored = YAML.safe_load_file(CORE_VALUES).dig("sections", "questions")

    refute_empty(rule_27_bullets)
    assert_equal(rule_27_bullets, mirrored)
  end

  def test_the_session_start_hook_prints_the_question_rule
    commands = JSON.parse(File.read(SETTINGS)).dig("hooks", "SessionStart").flat_map { |entry| entry["hooks"] }
    assert(commands.any? { |hook| hook["command"].end_with?("core-values.rb\" full") })

    stdout, stderr, status = run_hook

    assert_equal(0, status.exitstatus, stderr)
    assert_includes(stdout, "questions:")
    assert_includes(stdout, rule_27_bullets.first)
  end

  private

  # The bullets under rule 27, as the YAML mirror writes them: markdown backticks stay, the dash goes.
  def rule_27_bullets
    lines = File.readlines(PLAYBOOK, chomp: true)
    start = lines.index { |line| line.start_with?("27. Agent questions") }
    return [] unless start

    lines.drop(start + 1).take_while { |line| line.start_with?("    - ") }.map { |line| line.delete_prefix("    - ") }
  end

  def run_hook
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, ".claude"))
      FileUtils.ln_s(CORE_VALUES, File.join(home, ".claude", "core-values.yml"))
      Open3.capture3({ "HOME" => home }, HOOK, "full")
    end
  end
end
