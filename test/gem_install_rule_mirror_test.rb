#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# Agents install gems with bi, never bundle install. A guard refuses the direct commands, and the
# words that steer agents to bi live in the playbook (agents.md), in core-values.yml (re-injected
# so the rule survives context compaction) and in the owned worktree-first skill.
class GemInstallRuleMirrorTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  PLAYBOOK_PATH = File.join(REPO_ROOT, "agents.md")
  CORE_VALUES_PATH = File.join(REPO_ROOT, "claude/.claude/core-values.yml")
  WORKTREE_FIRST_PATH = File.join(REPO_ROOT, "agents/.agents/skills/worktree-first/SKILL.md")

  def test_the_playbook_tells_agents_to_install_gems_with_bi
    assert_match(/install gems with `bi`/i, File.read(PLAYBOOK_PATH))
    assert_match(/never `bundle install`/i, File.read(PLAYBOOK_PATH))
  end

  def test_the_core_values_repeat_it
    assert_match(/install gems with `?bi`?/i, File.read(CORE_VALUES_PATH))
    assert_match(/never `?bundle install`?/i, File.read(CORE_VALUES_PATH))
  end

  def test_worktree_first_installs_gems_with_bi
    skill = File.read(WORKTREE_FIRST_PATH)

    assert_match(/`bi`/, skill)
    refute_match(/`bundle install`/, skill)
  end
end
