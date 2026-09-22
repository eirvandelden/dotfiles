#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

class LefthookLocalHooksTest < Minitest::Test
  RV_LEFTHOOK_GLOB = File.join(
    Dir.home, ".local/share/rv/rubies/*/lib/ruby/gems/*/gems/lefthook-*/libexec/lefthook-darwin-arm64/lefthook"
  )

  def self.env_lefthook_bin
    ENV["LEFTHOOK_BIN"] if ENV["LEFTHOOK_BIN"] && File.executable?(ENV["LEFTHOOK_BIN"])
  end

  def self.path_lefthook_bin
    found = `which lefthook 2>/dev/null`.strip
    found unless found.empty?
  end

  def self.locate_native_lefthook
    env_lefthook_bin || path_lefthook_bin || Dir.glob(RV_LEFTHOOK_GLOB).find { |f| File.executable?(f) }
  end

  NATIVE_LEFTHOOK = locate_native_lefthook
  MISSING_LEFTHOOK_MESSAGE =
    "lefthook not found: not on PATH (checked LEFTHOOK_BIN and `which lefthook`) " \
    "and no rv install matched #{RV_LEFTHOOK_GLOB}"

  def setup
    skip(MISSING_LEFTHOOK_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log_file = File.join(@tmpdir, "commands.log")
    @repo_dir = File.join(@tmpdir, "repo")
    @hooks_dir = File.join(@tmpdir, "hooks")
    @origin_dir = File.join(@tmpdir, "origin.git")
    FileUtils.mkdir_p(@bin_dir)
    setup_dotfiles_home
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_pre_commit_uses_global_fallback_and_rejects_conflict_markers
    setup_repo("trunk")
    stub_real_lefthook
    stage_file("conflict.txt", conflict_markers)
    _out, _err, status = git("commit", "-m", "conflict")
    assert_not(status.success?, "Expected a commit with conflict markers to be rejected by the global fallback")
  end

  def test_pre_commit_calls_lefthook_with_no_auto_install
    setup_repo("trunk")
    stub_logging_lefthook
    stage_file("clean.txt", "hello\n")
    git("commit", "-m", "clean")
    assert_match(/--no-auto-install/, hook_invocation("pre-commit"))
  end

  def test_pre_push_uses_global_fallback_and_rejects_push_from_main
    setup_repo("main")
    stub_real_lefthook
    _out, _err, status = push
    assert_not(status.success?, "Expected a push from main to be rejected by the global fallback")
  end

  def test_pre_push_calls_lefthook_with_no_auto_install
    setup_repo("trunk")
    stub_logging_lefthook
    push
    assert_match(/--no-auto-install/, hook_invocation("pre-push"))
  end

  private

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end

  def hook_invocation(hook_name)
    invocation = File.readlines(@log_file, chomp: true).find { |line| line.start_with?("run #{hook_name}") }
    assert_not(invocation.nil?, "Expected #{hook_name} to invoke lefthook. Log:\n#{File.read(@log_file)}")
    invocation
  end

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

  def conflict_markers
    "<<<<<<< HEAD\nfoo\n=======\nbar\n>>>>>>> branch\n"
  end

  def stage_file(name, content)
    File.write(File.join(@repo_dir, name), content)
    run_git("-C", @repo_dir, "add", ".")
  end

  def stub_real_lefthook
    write_executable("lefthook", "#!/bin/sh\nexec \"#{NATIVE_LEFTHOOK}\" \"$@\"\n")
  end

  def stub_logging_lefthook
    write_executable("lefthook", "#!/bin/sh\necho \"$*\" >> \"#{@log_file}\"\n")
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
