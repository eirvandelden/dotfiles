#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require_relative "lefthook_binary"

# The skill-parity pre-push job must run when a push touches only a Claude skill
# link, because each claude/.claude/skills/<name> is a top-level link, not a folder.
class SkillParityHookTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  NATIVE_LEFTHOOK = LefthookBinary.locate

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK
  end

  def test_a_pushed_claude_skill_link_runs_the_parity_job
    output = run_parity_job("claude/.claude/skills/sync")

    refute_match(/skill-parity \(skip\)/, output)
  end

  def test_a_pushed_agents_skill_file_runs_the_parity_job
    output = run_parity_job("agents/.agents/skills/sync/SKILL.md")

    refute_match(/skill-parity \(skip\)/, output)
  end

  private

  def run_parity_job(file)
    stdout, stderr, _status = Open3.capture3(
      { "LEFTHOOK_EXCLUDE" => nil },
      NATIVE_LEFTHOOK.to_s, "run", "pre-push", "--file", file, "--command", "skill-parity",
      chdir: REPO_ROOT
    )
    stdout + stderr
  end
end
