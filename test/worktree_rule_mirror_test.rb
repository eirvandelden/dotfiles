#!/usr/bin/env ruby
require "minitest/autorun"

# "Never type `git worktree add` yourself; use `worktree-create`" must be written in every place an
# agent reads its rules, because the worktree guard hook is a no-op where it cannot run or is not
# yet trusted (Codex), and the written rule is the fallback.
class WorktreeRuleMirrorTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  RULE = /never type `git worktree add` yourself; use `worktree-create`/i

  def test_worktrees_md_says_never_type_git_worktree_add
    assert_match(RULE, File.read(File.join(REPO_ROOT, "claude/.claude/WORKTREES.md")))
  end

  def test_the_worktree_first_skill_says_never_type_git_worktree_add
    assert_match(RULE, File.read(File.join(REPO_ROOT, "agents/.agents/skills/worktree-first/SKILL.md")))
  end

  def test_the_playbook_says_never_type_git_worktree_add
    assert_match(RULE, File.read(File.join(REPO_ROOT, "agents.md")))
  end

  def test_the_core_values_say_never_type_git_worktree_add
    assert_match(RULE, File.read(File.join(REPO_ROOT, "claude/.claude/core-values.yml")))
  end
end
