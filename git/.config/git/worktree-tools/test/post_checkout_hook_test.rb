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
      @init_log = File.join(@tmpdir, "init.log")
      @real_bin_dir = File.join(@tmpdir, "real-bin")
      FileUtils.mkdir_p(@real_bin_dir)
      write_executable("git", git_script)
      write_executable("lefthook", lefthook_script)
      FileUtils.cp(File.join(@bin_dir, "lefthook"), @real_bin_dir)
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

    def test_post_checkout_runs_worktree_init_for_a_new_linked_worktree_of_an_opted_in_repo
      worktree = linked_worktree(opt_in: true)
      run_hook(worktree, ZERO_SHA)

      assert_equal [ "#{worktree}\n" ], File.readlines(@init_log)
      assert_includes command_log, "lefthook run post-checkout"
    end

    def test_post_checkout_skips_worktree_init_without_the_opt_in
      run_hook(linked_worktree(opt_in: false), ZERO_SHA)

      refute File.exist?(@init_log)
    end

    def test_post_checkout_skips_worktree_init_for_a_branch_switch
      run_hook(linked_worktree(opt_in: true), "abc123")

      refute File.exist?(@init_log)
    end

    def test_post_checkout_skips_worktree_init_for_a_fresh_clone
      run_hook(main_checkout(opt_in: true), ZERO_SHA)

      refute File.exist?(@init_log)
    end

    def test_post_checkout_skips_everything_when_lefthook_is_disabled
      run_hook(linked_worktree(opt_in: true), ZERO_SHA, "LEFTHOOK" => "0")

      refute File.exist?(@init_log)
      assert_equal "", command_log
    end

    def test_post_checkout_still_runs_lefthook_when_worktree_init_fails
      worktree = linked_worktree(opt_in: true)
      write_init_stub("exit 1")
      _stdout, stderr, status = run_hook(worktree, ZERO_SHA)

      assert status.success?, "hook failed: #{stderr}"
      assert_match(/worktree-init failed/, stderr)
      assert_includes command_log, "lefthook run post-checkout"
    end

    def test_post_checkout_runs_worktree_init_under_dash
      dash = `which dash 2>/dev/null`.strip
      skip("dash not found on PATH") if dash.empty?

      worktree = linked_worktree(opt_in: true)
      Open3.capture3(real_git_env, dash, HOOK_PATH, ZERO_SHA, "abc123", "1", chdir: worktree)

      assert_equal [ "#{worktree}\n" ], File.readlines(@init_log)
    end

    private

    ZERO_SHA = "0" * 40

    def main_checkout(opt_in:)
      @repo = File.join(@tmpdir, "repo")
      FileUtils.mkdir_p(@repo)
      real_git("init", "--quiet", "--initial-branch=main", chdir: @repo)
      real_git("commit", "--quiet", "--allow-empty", "-m", "init", chdir: @repo)
      real_git("config", "worktree-tools.initOnCreate", "true", chdir: @repo) if opt_in
      write_init_stub("echo \"$1\" >> \"#{@init_log}\"")
      @repo
    end

    def linked_worktree(opt_in:)
      main_checkout(opt_in: opt_in)
      path = File.join(@tmpdir, "linked")
      real_git("worktree", "add", "--quiet", "-b", "feature", path, chdir: @repo)
      File.realpath(path)
    end

    def write_init_stub(body)
      path = File.join(@tmpdir, ".config", "git", "worktree-tools", "worktree-init")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#!/bin/sh\n#{body}\n")
      FileUtils.chmod("+x", path)
    end

    def run_hook(dir, old_sha, extra_env = {})
      Open3.capture3(real_git_env.merge(extra_env), HOOK_PATH, old_sha, "abc123", "1", chdir: dir)
    end

    def real_git_env
      hook_env.merge(
        "PATH" => "#{@real_bin_dir}:/usr/bin:/bin",
        "GIT_CONFIG_GLOBAL" => "/dev/null",
        "GIT_CONFIG_SYSTEM" => "/dev/null",
        "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
        "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"
      )
    end

    def real_git(*args, chdir:)
      stdout, stderr, status = Open3.capture3(real_git_env, "git", *args, chdir: chdir)
      flunk "git #{args.join(" ")} failed: #{stdout}#{stderr}" unless status.success?
    end

    def hook_env
      {
        "HOME" => @tmpdir,
        "XDG_CONFIG_HOME" => File.join(@tmpdir, ".config"),
        "LEFTHOOK_BIN" => nil,
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
