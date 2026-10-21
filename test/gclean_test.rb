#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# gclean sweeps merged worktrees, then deletes merged local branches. It never touches a branch
# that a worktree has checked out, nor main. The sweep is stubbed: it needs gh and the network.
class GcleanTest < Minitest::Test
  FUNCTION = File.expand_path("../zsh/.config/zsh/functions/worktree.zsh", __dir__)
  ALIASES = File.expand_path("../zsh/.config/zsh/aliases.zsh", __dir__)

  def setup
    @tmpdir = File.realpath(Dir.mktmpdir)
    @repo = File.join(@tmpdir, "repo")
    FileUtils.mkdir_p(@repo)
    git("init", "--quiet", "--initial-branch=main")
    git("commit", "--quiet", "--allow-empty", "-m", "initial")
    add_origin
    install_sweep_stub
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_deletes_a_merged_branch
    git("branch", "merged-branch")

    run_gclean

    refute(branch?("merged-branch"))
  end

  def test_keeps_a_branch_with_unmerged_work
    git("switch", "--quiet", "-c", "unmerged-branch")
    git("commit", "--quiet", "--allow-empty", "-m", "unmerged work")
    git("switch", "--quiet", "main")

    run_gclean

    assert(branch?("unmerged-branch"))
  end

  def test_keeps_a_merged_branch_checked_out_in_a_worktree
    git("worktree", "add", "--quiet", File.join(".worktrees", "wt"), "-b", "worktree-branch")

    _, stderr, status = run_gclean

    assert(status.success?, stderr)
    assert(branch?("worktree-branch"))
    refute_match(/branch '\+' not found|used by worktree/, stderr)
  end

  def test_keeps_main
    git("branch", "merged-branch")

    run_gclean

    assert(branch?("main"))
  end

  def test_keeps_the_current_branch
    git("switch", "--quiet", "-c", "current-branch")

    run_gclean

    assert(branch?("current-branch"))
  end

  def test_deletes_the_branch_of_a_worktree_that_the_sweep_removed
    git("worktree", "add", "--quiet", File.join(".worktrees", "swept"), "-b", "swept-branch")
    install_sweep_stub("git worktree remove .worktrees/swept")

    run_gclean

    refute(branch?("swept-branch"))
  end

  def test_deletes_a_branch_merged_into_the_default_branch_that_the_checkout_lacks
    git("commit", "--quiet", "--allow-empty", "-m", "merged upstream")
    git("push", "--quiet", "origin", "main")
    git("remote", "set-head", "origin", "main")
    git("branch", "merged-upstream")
    git("reset", "--quiet", "--hard", "HEAD~1")

    run_gclean

    refute(branch?("merged-upstream"))
  end

  def test_no_alias_shadows_the_function
    refute_match(/^alias gclean=/, File.read(ALIASES))
  end

  private

  def run_gclean
    script = "source '#{FUNCTION}'; gclean"
    Open3.capture3({ "GCLEAN_SWEEP" => File.join(@tmpdir, "sweep") }, "zsh", "-f", "-c", script, chdir: @repo)
  end

  def add_origin
    origin = File.join(@tmpdir, "origin.git")
    Open3.capture2e("git", "init", "--quiet", "--bare", origin)
    git("remote", "add", "origin", origin)
    git("push", "--quiet", "origin", "main")
  end

  def install_sweep_stub(command = "true")
    path = File.join(@tmpdir, "sweep")
    File.write(path, "#!/bin/sh\n#{command}\n")
    File.chmod(0o755, path)
  end

  def branch?(name)
    _, status = Open3.capture2("git", "-C", @repo, "rev-parse", "--verify", "refs/heads/#{name}", err: File::NULL)
    status.success?
  end

  def git(*arguments)
    output, status = Open3.capture2e("git", "-C", @repo, "-c", "user.email=test@example.com",
                                     "-c", "user.name=Test", *arguments)
    raise "git #{arguments.join(' ')} failed: #{output}" unless status.success?

    output
  end
end
