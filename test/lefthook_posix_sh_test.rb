#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "lefthook_binary"

class LefthookPosixShTest < Minitest::Test
  def self.locate_dash
    found = `which dash 2>/dev/null`.strip
    found unless found.empty?
  end

  NATIVE_LEFTHOOK = LefthookBinary.locate
  DASH_BIN = locate_dash
  MISSING_LEFTHOOK_MESSAGE = LefthookBinary::MISSING_MESSAGE

  def setup
    skip(MISSING_LEFTHOOK_MESSAGE) unless NATIVE_LEFTHOOK
    skip("dash not found on PATH, cannot force a POSIX sh") unless DASH_BIN

    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @repo_dir = File.join(@tmpdir, "repo")
    @hooks_dir = File.join(@tmpdir, "hooks")
    @origin_dir = File.join(@tmpdir, "origin.git")
    FileUtils.mkdir_p(@bin_dir)
    setup_dotfiles_home
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_pre_push_rejects_a_push_from_main_when_sh_is_dash
    setup_repo("main")
    stub_real_lefthook
    stub_dash_as_sh
    commit_file("todo.txt", "hello\n")
    _out, _err, status = push
    refute(status.success?, "Expected a push from main to be rejected by no-push-to-main under dash")
  end

  def test_pre_push_rejects_a_push_of_a_feature_branch_to_main_when_sh_is_dash
    setup_repo("main")
    stub_real_lefthook
    stub_dash_as_sh
    run_git("-C", @repo_dir, "switch", "-q", "-c", "feature")
    commit_file("todo.txt", "hello\n")
    out, err, status = git("push", "origin", "feature:main")
    refute(status.success?, "Expected a push of a feature branch to main to be rejected under dash")
    assert_match(/Pushing to main is not allowed/, out + err)
  end

  def test_commit_msg_rejects_an_empty_commit_on_main_when_sh_is_dash
    setup_repo("main")
    stub_real_lefthook
    stub_dash_as_sh
    out, err, status = git("commit", "--allow-empty", "-m", "empty")
    refute(status.success?, "Expected an empty commit on main to be rejected under dash")
    assert_match(/Direct commit to main is not allowed/, out + err)
  end

  private

  def setup_dotfiles_home
    dotfiles_dir = File.join(@tmpdir, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles_dir)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(dotfiles_dir, "lefthook.yml"))
  end

  def setup_repo(branch)
    FileUtils.cp_r(File.join(@repo_root, "git/.config/git/hooks"), @hooks_dir)
    run_git("init", "--bare", "--quiet", @origin_dir)
    run_git("init", "--quiet", "--initial-branch=#{branch}", @repo_dir)
    run_git("-C", @repo_dir, "config", "core.hooksPath", @hooks_dir)
    run_git("-C", @repo_dir, "config", "user.name", "Test")
    run_git("-C", @repo_dir, "config", "user.email", "test@example.com")
    run_git("-C", @repo_dir, "remote", "add", "origin", @origin_dir)
    File.write(File.join(@repo_dir, "README.md"), "init\n")
    run_git("-C", @repo_dir, "add", ".")
    run_git("-C", @repo_dir, "commit", "-q", "-m", "init", env: { "LEFTHOOK" => "0" })
  end

  def commit_file(name, content)
    File.write(File.join(@repo_dir, name), content)
    run_git("-C", @repo_dir, "add", ".")
    run_git("-C", @repo_dir, "commit", "-q", "-m", "add #{name}", env: { "LEFTHOOK" => "0" })
  end

  def stub_real_lefthook
    write_executable("lefthook", "#!/bin/sh\nexec \"#{NATIVE_LEFTHOOK}\" \"$@\"\n")
  end

  def stub_dash_as_sh
    write_executable("sh", "#!/bin/sh\nexec \"#{DASH_BIN}\" \"$@\"\n")
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
    path
  end

  def repo_env
    {
      "HOME" => @tmpdir,
      "PATH" => "#{@bin_dir}:/usr/bin:/bin",
      "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "GIT_AUTHOR_NAME" => "Test",
      "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test",
      "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
  end

  def git(*args)
    Open3.capture3(repo_env, "git", *args, chdir: @repo_dir)
  end

  def push
    git("push", "origin", "HEAD")
  end

  def run_git(*args, env: {})
    full_env = { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null" }.merge(env)
    stdout, stderr, status = Open3.capture3(full_env, "git", *args, chdir: @tmpdir)
    return if status.success?

    flunk "git #{args.join(" ")} failed (exit #{status.exitstatus}):\n#{stdout}\n#{stderr}"
  end
end
