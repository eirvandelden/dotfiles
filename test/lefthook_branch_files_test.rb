#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "lefthook_binary"
require_relative "isolated_git"

# Real `git commit` and `git push` runs through the global pre-commit and pre-push hooks and the
# repository's lefthook.yml. The pre-push checks must scan only the files the branch itself changes
# against main, also after a rebase over a main that moved on. The marker words are built by
# concatenation, so this file passes the marker checks it tests.
class LefthookBranchFilesTest < Minitest::Test
  TRUNK = "trunk"
  BRANCH = "claims-status"
  FIX_WORD = "FIX" + "ME"
  COMMIT_WORD = "NO" + "COMMIT"
  NATIVE_LEFTHOOK = LefthookBinary.locate

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @home = Dir.mktmpdir
    @bin_dir = File.join(@home, "bin")
    @work = File.join(@home, "work")
    link_global_setup
    stub_commands
    create_repositories
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_a_rebased_branch_pushes_past_markers_that_only_main_added
    branch_pushed_before_main_moved
    main_adds("notes/main-only.txt", "# #{FIX_WORD} main wrote this\n")
    rebase_over_main

    stdout, stderr, status = push

    assert(status.success?, stdout + stderr)
  end

  private

  def branch_pushed_before_main_moved
    git(@work, "checkout", "--quiet", "-b", BRANCH)
    commit("app/claims.txt", "claims\n", "touch code")
    git(@work, "push", "--quiet", "-u", "origin", BRANCH)
  end

  def main_adds(relative_path, content)
    git(@work, "checkout", "--quiet", TRUNK)
    commit(relative_path, content, "main adds #{relative_path}")
    git(@work, "push", "--quiet", "origin", TRUNK)
    git(@work, "checkout", "--quiet", BRANCH)
  end

  def rebase_over_main
    git(@work, "fetch", "--quiet", "origin")
    git(@work, "rebase", "--quiet", "origin/#{TRUNK}")
  end

  def link_global_setup
    hooks = File.join(@home, ".config", "git", "hooks")
    FileUtils.mkdir_p(hooks)
    File.write(File.join(@home, ".gitconfig"), "[user]\n  name = Test\n  email = test@example.com\n")
    File.write(File.join(@home, ".config", "git", "config"), "[core]\n  hooksPath = ~/.config/git/hooks\n")
    %w[pre-commit pre-push].each do |hook|
      File.symlink(File.join(@repo_root, "git/.config/git/hooks", hook), File.join(hooks, hook))
    end
    File.symlink(File.join(@repo_root, "git/.config/git/worktree-tools"), File.join(@home, ".config", "git", "worktree-tools"))
    dotfiles = File.join(@home, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), dotfiles)
  end

  # gh reports no open pull request; shellcheck and yamllint log their arguments to $HOME/<name>.log.
  def stub_commands
    FileUtils.mkdir_p(@bin_dir)
    write_stub("gh", "echo 0")
    %w[shellcheck yamllint].each do |name|
      write_stub(name, "echo \"$@\" >> \"#{File.join(@home, "#{name}.log")}\"")
    end
  end

  def write_stub(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    FileUtils.chmod("+x", path)
  end

  def create_repositories
    origin = File.join(@home, "origin.git")
    git(@home, "init", "--bare", "--quiet", origin)
    git(@home, "-C", origin, "symbolic-ref", "HEAD", "refs/heads/#{TRUNK}")
    git(@home, "clone", "--quiet", origin, @work)
    commit("README.md", "initial", "init")
    git(@work, "push", "--quiet", "origin", "HEAD:#{TRUNK}")
    git(@work, "remote", "set-head", "origin", TRUNK)
  end

  def commit(relative_path, content, message)
    path = File.join(@work, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    git(@work, "add", relative_path)
    git(@work, "commit", "--quiet", "-m", message)
  end

  # Runs without the hooks, to build state that the hooks would refuse.
  def git(directory, *arguments)
    _, stderr, status = Open3.capture3(environment.merge("LEFTHOOK" => "0"), "git", "-C", directory, *arguments)
    flunk("git #{arguments.join(' ')} failed: #{stderr}") unless status.success?
  end

  def push
    Open3.capture3(environment, "git", "-C", @work, "push", "-u", "origin", BRANCH)
  end

  def environment
    ruby_bin = File.dirname(RbConfig.ruby)
    { "HOME" => @home, "PATH" => "#{@bin_dir}:#{ruby_bin}:/usr/bin:/bin", "GIT_CONFIG_GLOBAL" => nil,
      "GIT_CONFIG_SYSTEM" => "/dev/null", "XDG_CONFIG_HOME" => nil, "LEFTHOOK" => nil, "LEFTHOOK_CONFIG" => nil,
      "LEFTHOOK_VERBOSE" => nil, "LEFTHOOK_BIN" => NATIVE_LEFTHOOK.to_s }
  end
end
