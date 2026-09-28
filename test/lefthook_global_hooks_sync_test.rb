#!/usr/bin/env ruby
require "minitest/autorun"
require "digest"
require "fileutils"
require "open3"
require "tmpdir"

class LefthookGlobalHooksSyncTest < Minitest::Test
  TRUNK = "trunk"
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
    @home = Dir.mktmpdir
    @bin_dir = File.join(@home, "bin")
    @log_file = File.join(@home, "commands.log")
    @origin_dir = File.join(@home, "origin.git")
    @pusher_dir = File.join(@home, "pusher")
    @puller_dir = File.join(@home, "puller")
    @global_hooks_dir = File.join(@home, ".config", "git", "hooks")
    write_git_config_files
    stow_hooks_as_links
    stub_commands
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_pull_in_dotfiles_repo_keeps_global_hooks_linked
    setup_git_repos(own_config: true)
    push_file("README.md", "changed")
    pull_in_puller
    assert_global_hooks_linked
  end

  def test_rebase_in_dotfiles_repo_keeps_global_hooks_linked
    setup_git_repos(own_config: true)
    commit_locally_in_puller("local.rb", "# local\n")
    push_file("README.md", "changed")
    pull_in_puller
    assert_global_hooks_linked
  end

  def test_pull_in_repo_without_own_config_keeps_global_hooks_linked
    setup_git_repos(own_config: false)
    push_file("README.md", "changed")
    pull_in_puller
    assert_global_hooks_linked
  end

  private

  def tracked_hooks_dir
    File.join(@repo_root, "git/.config/git/hooks")
  end

  def write_git_config_files
    File.write(File.join(@home, ".gitconfig"), "[user]\n  name = Test\n  email = test@example.com\n")
    FileUtils.mkdir_p(@global_hooks_dir)
    File.write(File.join(@home, ".config", "git", "config"), "[core]\n  hooksPath = ~/.config/git/hooks\n")
  end

  def stow_hooks_as_links
    dotfiles_dir = File.join(@home, "Developer", "dotfiles")
    stowed_hooks_dir = File.join(dotfiles_dir, "git/.config/git/hooks")
    FileUtils.mkdir_p(stowed_hooks_dir)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(dotfiles_dir, "lefthook.yml"))
    Dir.children(tracked_hooks_dir).each do |name|
      FileUtils.cp(File.join(tracked_hooks_dir, name), stowed_hooks_dir, preserve: true)
      File.symlink(File.join(stowed_hooks_dir, name), File.join(@global_hooks_dir, name))
    end
  end

  def stub_commands
    FileUtils.mkdir_p(@bin_dir)
    %w[rails yarn rv bundle].each do |cmd|
      write_executable(cmd, "#!/bin/sh\necho \"#{cmd} $*\" >> \"#{@log_file}\"\n")
    end
    write_executable("lefthook", "#!/bin/sh\nexec \"#{NATIVE_LEFTHOOK}\" \"$@\"\n")
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end

  def setup_git_repos(own_config:)
    run_git("init", "--bare", @origin_dir, "--quiet")
    run_git("-C", @origin_dir, "symbolic-ref", "HEAD", "refs/heads/#{TRUNK}")
    run_git("clone", @origin_dir, @pusher_dir, "--quiet")
    commit_initial_files(own_config)
    run_git("clone", @origin_dir, @puller_dir, "--quiet")
    run_git("-C", @puller_dir, "config", "pull.rebase", "true")
  end

  def commit_initial_files(own_config)
    File.write(File.join(@pusher_dir, "README.md"), "initial")
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), @pusher_dir) if own_config
    commit_in(@pusher_dir, "init")
    run_git("-C", @pusher_dir, "push", "origin", TRUNK)
  end

  def commit_in(dir, message)
    run_git("-C", dir, "add", ".")
    run_git("-C", dir, "commit", "-m", message)
  end

  def commit_locally_in_puller(relative_path, content)
    File.write(File.join(@puller_dir, relative_path), content)
    commit_in(@puller_dir, "local commit")
  end

  def push_file(relative_path, content)
    File.write(File.join(@pusher_dir, relative_path), content)
    commit_in(@pusher_dir, "change #{relative_path}")
    run_git("-C", @pusher_dir, "push", "origin", TRUNK)
  end

  def pull_in_puller
    stdout, stderr, status = Open3.capture3(hook_env, "git", "pull", "--quiet", chdir: @puller_dir)
    return if status.success?

    flunk "git pull failed (exit #{status.exitstatus}):\nstdout: #{stdout}\nstderr: #{stderr}"
  end

  def run_git(*args)
    stdout, stderr, status = Open3.capture3(hook_env.merge("LEFTHOOK" => "0"), "git", *args, chdir: @home)
    return if status.success?

    flunk "git #{args.join(" ")} failed (exit #{status.exitstatus}):\n#{stdout}\n#{stderr}"
  end

  def hook_env
    {
      "HOME" => @home,
      "PATH" => "#{@bin_dir}:/usr/bin:/bin",
      "GIT_CONFIG_GLOBAL" => nil,
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "XDG_CONFIG_HOME" => nil,
      "LEFTHOOK" => nil,
      "LEFTHOOK_CONFIG" => nil,
      "LEFTHOOK_VERBOSE" => nil,
      "LEFTHOOK_BIN" => NATIVE_LEFTHOOK.to_s
    }
  end

  def assert_global_hooks_linked
    broken = Dir.children(@global_hooks_dir).sort.reject { |name| linked_to_tracked_shim?(name) }
    assert_empty(broken, "Global hooks no longer linked to their unchanged tracked shim: #{broken.join(", ")}")
  end

  def linked_to_tracked_shim?(name)
    hook = File.join(@global_hooks_dir, name)
    tracked = File.join(tracked_hooks_dir, name)
    File.symlink?(hook) && File.exist?(tracked) && sha256(hook) == sha256(tracked)
  end

  def sha256(path)
    Digest::SHA256.file(path).hexdigest
  end
end
