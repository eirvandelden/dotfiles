#!/usr/bin/env ruby
require "minitest/autorun"

module WorktreeTools
  class GitAliasTest < Minitest::Test
    CONFIG_PATH = File.expand_path("../../config", __dir__)

    def test_git_config_exposes_worktree_init_alias
      config = File.read(CONFIG_PATH)

      assert_includes config, 'worktree-init = "!'
      assert_includes config, "worktree-tools/worktree-init"
    end
  end
end
