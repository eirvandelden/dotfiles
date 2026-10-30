#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "lefthook_binary"
require_relative "hook_scripts"
require_relative "git_fixture"
require_relative "isolated_git"

class LefthookPullHooksTest < Minitest::Test
  TRUNK = "trunk"
  NATIVE_LEFTHOOK = LefthookBinary.locate
  MISSING_LEFTHOOK_MESSAGE = LefthookBinary::MISSING_MESSAGE
  PACKAGE_LOCK = "{\"name\":\"app\",\"version\":\"1\"}".freeze

  # <root>/origin.git on trunk, <root>/pusher with one commit pushed, <root>/puller cloned from it.
  REPOSITORY = GitFixture.new do |root|
    origin = File.join(root, "origin.git")
    pusher = File.join(root, "pusher")
    puller = File.join(root, "puller")
    identity = { "LEFTHOOK" => "0", "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                 "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com" }
    git = ->(*arguments) { system(identity, "git", *arguments, exception: true) }
    git.call("init", "--bare", origin, "--quiet")
    git.call("-C", origin, "symbolic-ref", "HEAD", "refs/heads/#{TRUNK}")
    git.call("clone", origin, pusher, "--quiet")
    File.write(File.join(pusher, ".gitkeep"), "")
    git.call("-C", pusher, "add", ".")
    git.call("-C", pusher, "commit", "-m", "init", "--quiet")
    git.call("-C", pusher, "push", "origin", TRUNK, "--quiet")
    git.call("clone", origin, puller, "--quiet")
    { "pull.rebase" => "true", "rebase.autoStash" => "true" }.each { |key, value| git.call("-C", puller, "config", key, value) }
  end

  def setup
    skip(MISSING_LEFTHOOK_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log_file = File.join(@tmpdir, "commands.log")
    @hooks_dir = HookScripts.directory
    FileUtils.mkdir_p(@bin_dir)
    setup_dotfiles_home
    stub_commands
    setup_git_repos
  end

  def teardown
    FileUtils.rm_rf([ @tmpdir, @repository_copy ].compact)
  end

  # Each test below runs the steps of several former single-behaviour tests in one pair of repositories. The log is
  # emptied before every pull, so a step sees only what its own pull ran.

  def test_pulling_migrations_runs_db_migrate_and_a_hostile_migration_name_runs_nothing
    # new migration file
    push_file("db/migrate/20260731000000_add_thing.rb", "# migration")
    pull_logged
    assert_command_ran("rails db:migrate")
    # changed schema
    push_file("db/schema.rb", "ActiveRecord::Schema.define(version: 1) {}")
    pull_logged
    assert_command_ran("rails db:migrate")
    # migration name with a command on a new line
    push_file("db/migrate/a\ntouch PWNED\n", "")
    pull_logged
    refute_path_exists(File.join(@puller_dir, "PWNED"), "A pulled file name ran a shell command")
  end

  def test_pulling_in_a_yarn_repository_installs_with_yarn_only_beside_a_yarn_lock
    # package.json with no lockfile installs nothing
    push_file("package.json", "{\"name\":\"app\"}")
    pull_logged
    refute_command_ran("yarn install")
    refute_command_ran("npm install")
    # changed yarn.lock
    push_file("yarn.lock", "# yarn lockfile v1\n")
    pull_logged
    assert_command_ran("yarn install")
    # changed package.json beside yarn.lock
    push_file("package.json", "{\"name\":\"app\",\"version\":\"2\"}")
    pull_logged
    assert_command_ran("yarn install")
    refute_command_ran("npm install")
  end

  def test_pulling_in_an_npm_repository_installs_with_npm_only
    # changed package-lock.json
    push_file("package-lock.json", PACKAGE_LOCK)
    pull_logged
    assert_command_ran("npm install")
    refute_command_ran("yarn install")
    # changed package.json beside package-lock.json
    push_file("package.json", "{\"name\":\"app\"}")
    pull_logged
    assert_command_ran("npm install")
    refute_command_ran("yarn install")
  end

  def test_pulling_gemfiles_installs_through_bi_and_ignores_deleted_nested_and_hostile_gemfiles
    # changed Gemfile.lock installs through bi
    push_file("Gemfile", "source \"https://rubygems.org\"\n")
    push_file("Gemfile.lock", "GEM\n  specs:\n")
    pull_logged
    assert_command_ran("bundle lock")
    assert_command_ran("rv ci")
    refute_command_ran("bundle install")
    # deleting the root Gemfile does not bundle install
    push_deletion_with_readme_change("Gemfile")
    pull_logged
    refute_command_ran("bundle install")
    # a nested Gemfile does not bundle
    push_file("bundler/Gemfile", "source \"https://rubygems.org\"\n")
    pull_logged
    refute_command_ran("bundle")
    refute_command_ran("rv ci")
    # Gemfile name with a command on a new line
    push_file("Gemfile\ntouch PWNED\n", "")
    pull_logged
    refute_path_exists(File.join(@puller_dir, "PWNED"), "A pulled file name ran a shell command")
  end

  def test_pull_touching_only_readme_runs_no_migrations
    push_file("README.md", "changed")
    pull_in_puller
    [ "bundle", "rv ci", "rails db:migrate", "yarn install", "npm install" ].each { |cmd| refute_command_ran(cmd) }
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

  private

  def setup_dotfiles_home
    dotfiles_dir = File.join(@tmpdir, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles_dir)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(dotfiles_dir, "lefthook.yml"))
  end

  def stub_commands
    %w[rails yarn npm].each do |cmd|
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

  # A copy of the fixture: a bare origin, a pusher that holds the first commit and a puller cloned from it.
  def setup_git_repos
    write_global_gitconfig
    @repository_copy = REPOSITORY.copy
    @origin_dir = File.join(@repository_copy, "origin.git")
    @pusher_dir = File.join(@repository_copy, "pusher")
    @puller_dir = File.join(@repository_copy, "puller")
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

  def push_deletion_with_readme_change(relative_path)
    run_git("-C", @pusher_dir, "rm", "--quiet", relative_path)
    File.write(File.join(@pusher_dir, "README.md"), "changed")
    run_git("-C", @pusher_dir, "add", "README.md")
    run_git("-C", @pusher_dir, "commit", "-m", "remove #{File.basename(relative_path)}")
    run_git("-C", @pusher_dir, "push", "origin", TRUNK)
  end

  def pull_in_puller
    stdout, stderr, status = Open3.capture3(pull_env, "sh", "-c", "git pull --quiet", chdir: @puller_dir)
    return if status.success?

    flunk "git pull failed (exit #{status.exitstatus}):\nstdout: #{stdout}\nstderr: #{stderr}"
  end

  def pull_logged
    File.write(@log_file, "")
    pull_in_puller
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
      "PATH" => "#{File.join(@repo_root, "ruby/.local/bin")}:#{@bin_dir}:/usr/bin:/bin",
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
    refute_match(
      /#{Regexp.escape(cmd)}/,
      command_log,
      "Expected '#{cmd}' not to have run. Log:\n#{command_log}"
    )
  end
end
