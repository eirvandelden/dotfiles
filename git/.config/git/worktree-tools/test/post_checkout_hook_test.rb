#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

module WorktreeTools
  class PostCheckoutHookTest < Minitest::Test
    HOOK_PATH = File.expand_path("../../hooks/post-checkout", __dir__)

    def setup
      @tmpdir = Dir.mktmpdir
      @bin_dir = File.join(@tmpdir, "bin")
      @log_file = File.join(@tmpdir, "commands.log")
      FileUtils.mkdir_p(@bin_dir)
      write_executable("git", git_script)
      write_executable("lefthook", lefthook_script)
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    def test_post_checkout_does_not_run_worktree_setup_for_new_worktree
      stdout, stderr, status = Open3.capture3(
        hook_env,
        HOOK_PATH,
        "0000000000000000000000000000000000000000",
        "abc123",
        "1"
      )

      assert status.success?, "hook failed: #{stderr}"
      refute_includes stdout, "New worktree detected"
      refute_includes command_log, "worktree-setup"
      assert_includes command_log, "lefthook run post-checkout"
    end

    private

    def hook_env
      {
        "HOME" => @tmpdir,
        "PATH" => "#{@bin_dir}:/usr/bin:/bin"
      }
    end

    def git_script
      <<~SH
        #!/bin/sh
        if [ "$1" = "rev-parse" ] && [ "$2" = "--show-toplevel" ]; then
          pwd
          exit 0
        fi
        exit 1
      SH
    end

    def lefthook_script
      <<~SH
        #!/bin/sh
        echo "lefthook $*" >> "#{@log_file}"
      SH
    end

    def write_executable(name, body)
      path = File.join(@bin_dir, name)
      File.write(path, body)
      FileUtils.chmod("+x", path)
    end

    def command_log
      File.exist?(@log_file) ? File.read(@log_file) : ""
    end
  end
end
