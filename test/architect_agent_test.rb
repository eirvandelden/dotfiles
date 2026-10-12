#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

# The plan stage runs two or three architects in parallel, each with its own design goal.
class ArchitectAgentTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  AGENT = File.join(ROOT, "claude/.claude/agents/architect.md")
  GENERATOR = File.join(ROOT, "bin/generate-codex-agents")
  TOML = File.join(ROOT, "codex/.codex/agents/architect.toml")

  def test_the_plan_runs_two_or_three_architects_with_different_goals
    step = plan_skill[/^\d+\. .*\barchitects\b.*(?:\n(?!\d+\. ).*)*/i] || flunk("no plan step runs architects")

    assert_match(/two or three/i, step)
    assert_match(/parallel|at once/i, step)
    assert_match(/different (design )?goal/i, step)
  end

  def test_the_architect_is_read_only_and_generated_for_codex
    tools = Array(frontmatter["tools"])

    assert_equal(%w[Read Grep Glob], tools)
    assert(File.exist?(TOML), "#{TOML} does not exist")
    assert_equal(generated_toml, File.read(TOML), "architect.toml is stale")
    assert_includes(File.read(TOML), %(sandbox_mode = "read-only"))
  end

  def test_the_architect_agent_has_no_bash
    refute_includes(Array(frontmatter["tools"]), "Bash")
  end

  def test_the_architect_agent_is_read_only
    assert_match(/read-only/i, agent_text)
    assert_match(/do not (write|edit|change)/i, agent_text)
  end

  def test_the_architect_takes_one_design_goal
    assert_match(/one design goal/i, agent_text)
  end

  def test_the_architect_returns_the_design_section_format
    [ "### Domain terms", "### Diagrams", "### Signatures", "### Complexity", "### Invariants" ].each do |heading|
      assert_includes(agent_text, heading)
    end
  end

  def test_the_generated_toml_matches
    assert_equal(generated_toml, File.read(TOML))
  end

  private

  def agent_text
    flunk("#{AGENT} does not exist") unless File.exist?(AGENT)
    File.read(AGENT)
  end

  def frontmatter
    YAML.safe_load(agent_text[/\A---\n(.*?)\n---\n/m, 1])
  end

  def plan_skill
    File.read(File.join(ROOT, "claude/.claude/skills/plan/SKILL.md"))
  end

  def generated_toml
    agent_text
    Dir.mktmpdir do |dir|
      claude_dir = File.join(dir, "claude")
      FileUtils.mkdir_p(claude_dir)
      FileUtils.cp(AGENT, claude_dir)
      _, stderr, status = Open3.capture3(GENERATOR, claude_dir, File.join(dir, "codex"))
      assert(status.success?, stderr)
      File.read(File.join(dir, "codex", "architect.toml"))
    end
  end
end
