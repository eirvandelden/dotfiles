#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "lefthook_binary"
require_relative "isolated_git"

# A real `git commit` and `git push` through the global hooks and lefthook. Vendored skill references
# keep upstream prose that holds the marker, so the no-fixme checks skip them; every other file stays checked.
class NoFixmeHookTest < Minitest::Test
  TRUNK = "trunk"
  BRANCH = "vendored-references"
  MARKER = "FIX" + "ME"
  REFERENCE = "agents/.agents/skills/rails-guides/references/command_line.md"
  SKILL_FILE = "agents/.agents/skills/rails-guides/SKILL.md"
  NATIVE_LEFTHOOK = LefthookBinary.locate

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @home = Dir.mktmpdir
    @work = File.join(@home, "work")
    link_global_setup
    create_repositories
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_pre_push_passes_a_vendored_reference_with_the_marker
    git_unchecked("checkout", "--quiet", "-b", BRANCH)
    commit_unchecked(REFERENCE, "Do not leave a #{MARKER} here\n")

    output, status = push

    assert(status.success?, output)
  end

  def test_pre_commit_passes_a_vendored_reference_with_the_marker
    stage(REFERENCE, "Do not leave a #{MARKER} here\n")

    output, status = commit

    assert(status.success?, output)
  end

  def test_pre_commit_rejects_the_marker_in_a_skill_file_outside_references
    stage(SKILL_FILE, "Do not leave a #{MARKER} here\n")

    output, status = commit

    refute(status.success?, output)
    assert_match(/Your staged files include a #{MARKER}/, output)
    assert_match(/#{Regexp.escape(SKILL_FILE)}/, output)
  end

  def test_pre_push_rejects_the_marker_outside_references_pushed_with_a_vendored_reference
    git_unchecked("checkout", "--quiet", "-b", BRANCH)
    commit_unchecked(REFERENCE, "Do not leave a #{MARKER} here\n")
    commit_unchecked("outside.txt", "Do not leave a #{MARKER} here\n")

    output, status = push

    refute(status.success?, output)
    assert_match(/Your pushed files include a #{MARKER}/, output)
    assert_match(/outside\.txt/, output)
    refute_match(/#{Regexp.escape(REFERENCE)}:\d+/, output)
  end

  private

  def link_global_setup
    hooks = File.join(@home, ".config", "git", "hooks")
    FileUtils.mkdir_p(hooks)
    File.write(File.join(@home, ".gitconfig"), "[user]\n  name = Test\n  email = test@example.com\n")
    File.write(File.join(@home, ".config", "git", "config"), "[core]\n  hooksPath = ~/.config/git/hooks\n")
    %w[pre-commit pre-push].each do |hook|
      File.symlink(File.join(@repo_root, "git/.config/git/hooks", hook), File.join(hooks, hook))
    end
    stub_review_report_fresh
    dotfiles = File.join(@home, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), dotfiles)
  end

  # The freshness check is out of scope here; only the no-fixme result decides the push.
  def stub_review_report_fresh
    tools = File.join(@home, ".config", "git", "worktree-tools")
    FileUtils.mkdir_p(tools)
    path = File.join(tools, "review-report-fresh")
    File.write(path, "#!/bin/sh\nexit 0\n")
    FileUtils.chmod("+x", path)
  end

  def create_repositories
    origin = File.join(@home, "origin.git")
    git_unchecked("init", "--bare", "--quiet", origin, directory: @home)
    git_unchecked("-C", origin, "symbolic-ref", "HEAD", "refs/heads/#{TRUNK}", directory: @home)
    git_unchecked("clone", "--quiet", origin, @work, directory: @home)
    commit_unchecked("README.md", "initial\n")
    git_unchecked("push", "--quiet", "origin", "HEAD:#{TRUNK}")
  end

  def stage(relative_path, content)
    path = File.join(@work, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    git_unchecked("add", relative_path)
  end

  def commit_unchecked(relative_path, content)
    stage(relative_path, content)
    git_unchecked("commit", "--quiet", "-m", "add #{relative_path}")
  end

  def git_unchecked(*arguments, directory: @work)
    flags = directory == @work ? [ "-C", @work ] : []
    _, stderr, status = Open3.capture3(environment.merge("LEFTHOOK" => "0"), "git", *flags, *arguments)
    flunk("git #{arguments.join(' ')} failed: #{stderr}") unless status.success?
  end

  def commit
    run_git("commit", "-m", "subject")
  end

  def push
    run_git("push", "-u", "origin", BRANCH)
  end

  def run_git(*arguments)
    stdout, stderr, status = Open3.capture3(environment, "git", "-C", @work, *arguments)
    [ stdout + stderr, status ]
  end

  def environment
    ruby_bin = File.dirname(RbConfig.ruby)
    { "HOME" => @home, "PATH" => "#{ruby_bin}:/usr/bin:/bin", "GIT_CONFIG_GLOBAL" => nil,
      "GIT_CONFIG_SYSTEM" => "/dev/null", "XDG_CONFIG_HOME" => nil, "LEFTHOOK" => nil, "LEFTHOOK_CONFIG" => nil,
      "LEFTHOOK_VERBOSE" => nil, "LEFTHOOK_BIN" => NATIVE_LEFTHOOK.to_s }
  end
end
