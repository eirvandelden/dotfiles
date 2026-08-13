#!/usr/bin/env ruby
require "minitest/autorun"
require "digest"
require "fileutils"
require "open3"
require "tmpdir"

class LefthookPullHooksTest < Minitest::Test
  TRUNK = "trunk"
  NATIVE_LEFTHOOK = Dir.glob(
    File.join(Dir.home, ".local/share/rv/rubies/*/lib/ruby/gems/*/gems/lefthook-*/libexec/lefthook-darwin-arm64/lefthook")
  ).find { |f| File.executable?(f) }

  def setup
    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log_file = File.join(@tmpdir, "commands.log")
    @origin_dir = File.join(@tmpdir, "origin.git")
    @pusher_dir = File.join(@tmpdir, "pusher")
    @puller_dir = File.join(@tmpdir, "puller")
    @hooks_dir = File.join(@tmpdir, "hooks")
    FileUtils.mkdir_p(@bin_dir)
    setup_dotfiles_home
    stub_commands
    setup_git_repos
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_new_migration_file_triggers_db_migrate
    push_file("db/migrate/20260731000000_add_thing.rb", "# migration")
    pull_in_puller
    assert_command_ran("rails db:migrate")
  end

  def test_changed_schema_triggers_db_migrate
    push_file("db/schema.rb", "ActiveRecord::Schema.define(version: 1) {}")
    pull_in_puller
    assert_command_ran("rails db:migrate")
  end

  def test_changed_gemfile_lock_triggers_rv_ci
    push_file("Gemfile.lock", "GEM\n  specs:\n")
    pull_in_puller
    assert_command_ran("rv ci")
  end

  def test_changed_yarn_lock_triggers_yarn_install
    push_file("yarn.lock", "# yarn lockfile v1\n")
    pull_in_puller
    assert_command_ran("yarn install")
  end

  def test_changed_package_lock_json_triggers_yarn_install
    push_file("package-lock.json", "{\"name\":\"app\",\"version\":\"1\"}")
    pull_in_puller
    assert_command_ran("yarn install")
  end

  def test_pull_on_non_main_branch_still_fires_hooks
    push_file("db/migrate/20260731000001_add_other.rb", "# migration")
    pull_in_puller
    assert_command_ran("rails db:migrate")
  end

  def test_pull_with_local_commit_uses_rebase_path_and_migrates
    push_file("README.md", "initial")
    pull_in_puller

    File.write(File.join(@puller_dir, "local.rb"), "# local\n")
    run_git("-C", @puller_dir, "add", ".")
    run_git("-C", @puller_dir, "commit", "-m", "local commit")

    push_file("db/migrate/20260731000002_rebased.rb", "# migration")

    FileUtils.rm_f(@log_file)
    pull_in_puller
    assert_command_ran("rails db:migrate")
  end

  def test_repo_with_own_lefthook_config_ignores_global_defaults
    File.write(
      File.join(@puller_dir, "lefthook.yml"),
      "post-merge:\n  commands:\n    own:\n      run: echo own\n"
    )
    push_file("db/migrate/20260731000003_ignored.rb", "# migration")
    pull_in_puller
    refute_command_ran("rails db:migrate")
  end

  def test_pull_does_not_overwrite_hook_scripts
    before = hooks_checksums
    push_file("db/migrate/20260731000004_add_thing.rb", "# migration")
    pull_in_puller
    assert_equal(before, hooks_checksums, "Hook scripts were modified by auto-install")
  end

  private

  def setup_dotfiles_home
    dotfiles_dir = File.join(@tmpdir, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles_dir)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(dotfiles_dir, "lefthook.yml"))
  end

  def stub_commands
    %w[rails yarn].each do |cmd|
      write_executable(cmd, "#!/bin/sh\necho \"#{cmd} $*\" >> \"#{@log_file}\"\n")
    end
    write_executable("rv", "#!/bin/sh\necho \"rv $*\" >> \"#{@log_file}\"\n")
    write_executable("bundle", "#!/bin/sh\necho \"bundle $*\" >> \"#{@log_file}\"\n")
    write_executable("lefthook", "#!/bin/sh\nexec \"#{NATIVE_LEFTHOOK}\" \"$@\"\n")
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
    path
  end

  def setup_git_repos
    FileUtils.cp_r(File.join(@repo_root, "git/.config/git/hooks"), @hooks_dir)
    write_global_gitconfig

    run_git("init", "--bare", @origin_dir, "--quiet")
    run_git("-C", @origin_dir, "symbolic-ref", "HEAD", "refs/heads/#{TRUNK}")

    run_git("clone", @origin_dir, @pusher_dir, "--quiet")
    run_git("-C", @pusher_dir, "config", "user.name", "Test")
    run_git("-C", @pusher_dir, "config", "user.email", "test@example.com")

    File.write(File.join(@pusher_dir, ".gitkeep"), "")
    run_git("-C", @pusher_dir, "add", ".")
    run_git("-C", @pusher_dir, "commit", "-m", "init")
    run_git("-C", @pusher_dir, "push", "origin", TRUNK)

    run_git("clone", @origin_dir, @puller_dir, "--quiet", env: { "GIT_CONFIG_GLOBAL" => global_gitconfig })
    run_git("-C", @puller_dir, "config", "user.name", "Test")
    run_git("-C", @puller_dir, "config", "user.email", "test@example.com")
    run_git("-C", @puller_dir, "config", "pull.rebase", "true")
    run_git("-C", @puller_dir, "config", "rebase.autoStash", "true")
  end

  def global_gitconfig
    @global_gitconfig ||= File.join(@tmpdir, "gitconfig")
  end

  def write_global_gitconfig
    File.write(global_gitconfig, <<~GITCONFIG)
      [core]
        hooksPath = #{@hooks_dir}
      [user]
        name = Test
        email = test@example.com
    GITCONFIG
  end

  def push_file(relative_path, content)
    full_path = File.join(@pusher_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    run_git("-C", @pusher_dir, "add", ".")
    run_git("-C", @pusher_dir, "commit", "-m", "add #{File.basename(relative_path)}")
    run_git("-C", @pusher_dir, "push", "origin", TRUNK)
  end

  def pull_in_puller
    stdout, stderr, status = Open3.capture3(pull_env, "sh", "-c", "git pull --quiet", chdir: @puller_dir)
    return if status.success?

    flunk "git pull failed (exit #{status.exitstatus}):\nstdout: #{stdout}\nstderr: #{stderr}"
  end

  def run_git(*args, env: {})
    full_env = setup_env.merge(env)
    stdout, stderr, status = Open3.capture3(full_env, "git", *args, chdir: @tmpdir)
    return if status.success?

    flunk "git #{args.join(" ")} failed (exit #{status.exitstatus}):\n#{stdout}\n#{stderr}"
  end

  def setup_env
    {
      "LEFTHOOK" => "0",
      "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "GIT_AUTHOR_NAME" => "Test",
      "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test",
      "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
  end

  def pull_env
    {
      "HOME" => @tmpdir,
      "PATH" => "#{@bin_dir}:/usr/bin:/bin",
      "GIT_CONFIG_GLOBAL" => global_gitconfig,
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "GIT_AUTHOR_NAME" => "Test",
      "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test",
      "GIT_COMMITTER_EMAIL" => "test@example.com",
      "LEFTHOOK_BIN" => NATIVE_LEFTHOOK.to_s
    }
  end

  def command_log
    File.exist?(@log_file) ? File.read(@log_file) : ""
  end

  def assert_command_ran(cmd)
    assert_match(
      /#{Regexp.escape(cmd)}/,
      command_log,
      "Expected '#{cmd}' to have run. Log:\n#{command_log}"
    )
  end

  def refute_command_ran(cmd)
    assert_no_match(
      /#{Regexp.escape(cmd)}/,
      command_log,
      "Expected '#{cmd}' not to have run. Log:\n#{command_log}"
    )
  end

  def assert_no_match(pattern, value, message = nil)
    assert_not(pattern.match?(value), message)
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end

  def hooks_checksums
    Dir.glob(File.join(@hooks_dir, "*")).sort.to_h do |f|
      [ File.basename(f), Digest::SHA256.hexdigest(File.read(f)) ]
    end
  end
end
