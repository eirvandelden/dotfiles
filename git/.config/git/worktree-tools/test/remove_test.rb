#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

module WorktreeTools
  class RemoveTest < Minitest::Test
    CONDUCTOR_ENV_KEYS = %w[CONDUCTOR_ROOT_PATH CONDUCTOR_PORT CONDUCTOR_WORKSPACE_NAME CONDUCTOR_WORKSPACE_PATH].freeze
    WORKTREE_REMOVE = File.expand_path("../worktree-remove", __dir__)

    def setup
      @tmpdir = Dir.mktmpdir
      @saved_conductor_env = CONDUCTOR_ENV_KEYS.to_h { |key| [ key, ENV[key] ] }
      CONDUCTOR_ENV_KEYS.each { |key| ENV.delete(key) }
    end

    def teardown
      CONDUCTOR_ENV_KEYS.each { |key| ENV[key] = @saved_conductor_env[key] }
      FileUtils.rm_rf(@tmpdir)
    end

    def test_remove_deletes_puma_dev_entry_even_when_conductor_now_disables_it
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)

      puma_dev_entry = File.join(@tmpdir, ".puma-dev", "mobile.mobile")
      FileUtils.mkdir_p(File.dirname(puma_dev_entry))
      File.write(puma_dev_entry, "3000")

      run_remove(worktree, env: conductor_env(worktree))

      refute File.exist?(puma_dev_entry), "expected worktree-remove to delete stale puma-dev entry"
    end

    private

    def setup_regular_repo_with_worktree
      repo = File.join(@tmpdir, "repo")
      FileUtils.mkdir_p(repo)
      run_command("git", "-C", repo, "init", "-q")
      run_command("git", "-C", repo, "config", "user.name", "Test User")
      run_command("git", "-C", repo, "config", "user.email", "test@example.com")
      run_command("git", "-C", repo, "commit", "--allow-empty", "-m", "init", "-q")

      worktree = File.join(@tmpdir, "mobile")
      run_command("git", "-C", repo, "worktree", "add", "-q", worktree, "-b", "mobile")

      [ repo, worktree ]
    end

    def rails_structure(path)
      FileUtils.mkdir_p(File.join(path, "config"))
      FileUtils.touch(File.join(path, "Gemfile"))
      FileUtils.touch(File.join(path, "config", "application.rb"))
      FileUtils.touch(File.join(path, "config.ru"))
    end

    def conductor_env(worktree)
      {
        "CONDUCTOR_ROOT_PATH" => @tmpdir,
        "CONDUCTOR_PORT" => "3000",
        "CONDUCTOR_WORKSPACE_NAME" => "mobile",
        "CONDUCTOR_WORKSPACE_PATH" => worktree,
        "HOME" => @tmpdir
      }
    end

    def run_command(*args)
      assert system(*args), "Command failed: #{args.join(' ')}"
    end

    def run_remove(worktree, env:)
      stdout, stderr, status = Open3.capture3(env, "ruby", WORKTREE_REMOVE, worktree)
      return if status.success?

      flunk <<~MSG
        worktree-remove failed with #{status.exitstatus}
        stdout:
        #{stdout}
        stderr:
        #{stderr}
      MSG
    end
  end
end
