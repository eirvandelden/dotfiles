#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "lefthook_binary"

# A real `git push` through the global pre-push hook, lefthook and the stowed
# review-report-fresh script. A branch with a change folder but no open pull request
# pushes without a fresh review, so implement and review can leave their work on the
# remote. Once a pull request is open the review must be fresh.
class ReviewPushHookTest < Minitest::Test
  TRUNK = "trunk"
  BRANCH = "claims-status"
  NATIVE_LEFTHOOK = LefthookBinary.locate

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @home = Dir.mktmpdir
    @bin_dir = File.join(@home, "bin")
    @work = File.join(@home, "work")
    link_global_setup
    stub_gh
    create_repositories
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_a_push_with_a_change_folder_and_no_pull_request_succeeds_without_a_fresh_review
    stale_branch
    open_pull_requests("0")

    stdout, stderr, status = push

    assert(status.success?, stdout + stderr)
  end

  def test_a_push_with_a_change_folder_and_an_open_pull_request_needs_a_fresh_review
    stale_branch
    open_pull_requests("1")

    stdout, stderr, status = push

    refute(status.success?)
    assert_match(/not covered by a fresh review/, stdout + stderr)
  end

  private

  def link_global_setup
    hooks = File.join(@home, ".config", "git", "hooks")
    FileUtils.mkdir_p(hooks)
    File.write(File.join(@home, ".gitconfig"), "[user]\n  name = Test\n  email = test@example.com\n")
    File.write(File.join(@home, ".config", "git", "config"), "[core]\n  hooksPath = ~/.config/git/hooks\n")
    File.symlink(File.join(@repo_root, "git/.config/git/hooks/pre-push"), File.join(hooks, "pre-push"))
    File.symlink(File.join(@repo_root, "git/.config/git/worktree-tools"), File.join(@home, ".config", "git", "worktree-tools"))
    dotfiles = File.join(@home, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), dotfiles)
  end

  # A gh that prints the count in $HOME/open_pull_requests.
  def stub_gh
    FileUtils.mkdir_p(@bin_dir)
    path = File.join(@bin_dir, "gh")
    File.write(path, "#!/bin/sh\ncat \"#{File.join(@home, 'open_pull_requests')}\"\n")
    FileUtils.chmod("+x", path)
  end

  def open_pull_requests(count)
    File.write(File.join(@home, "open_pull_requests"), count)
  end

  def create_repositories
    origin = File.join(@home, "origin.git")
    git(@home, "init", "--bare", "--quiet", origin)
    git(@home, "-C", origin, "symbolic-ref", "HEAD", "refs/heads/#{TRUNK}")
    git(@home, "clone", "--quiet", origin, @work)
    commit("README.md", "initial", "init")
    git(@work, "push", "--quiet", "origin", "HEAD:#{TRUNK}")
  end

  # A change folder with a review, then a code commit the review does not cover.
  def stale_branch
    git(@work, "checkout", "--quiet", "-b", BRANCH)
    commit("docs/changes/#{BRANCH}/review.md", "# Round 1\n", "add review")
    commit("app/claims.txt", "claims\n", "touch code")
  end

  def commit(relative_path, content, message)
    path = File.join(@work, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    git(@work, "add", relative_path)
    git(@work, "commit", "--quiet", "-m", message)
  end

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
