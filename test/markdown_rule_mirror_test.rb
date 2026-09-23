#!/usr/bin/env ruby
require "minitest/autorun"

# agents.md (the playbook Claude and Codex both read) and core-values.yml (the hook that
# re-injects a subset of the playbook so it survives context compaction) must both carry the
# no-hardwrap rule, or an agent that only sees core-values.yml never learns it.
class MarkdownRuleMirrorTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  PLAYBOOK_PATH = File.join(REPO_ROOT, "agents.md")
  CORE_VALUES_PATH = File.join(REPO_ROOT, "claude/.claude/core-values.yml")

  def test_the_playbook_tells_agents_one_line_per_paragraph
    assert_match(/one line per paragraph/i, File.read(PLAYBOOK_PATH))
  end

  def test_the_core_values_repeat_the_one_line_per_paragraph_rule
    assert_match(/one line per paragraph/i, File.read(CORE_VALUES_PATH))
  end
end
