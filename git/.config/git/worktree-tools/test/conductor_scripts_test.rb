#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

class ConductorScriptsTest < Minitest::Test
  ROOT = File.expand_path("../../../../..", __dir__)
  SETUP_SCRIPT = File.join(ROOT, "conductor/.config/conductor/scripts/setup")
  RUN_SCRIPT = File.join(ROOT, "conductor/.config/conductor/scripts/run")
  ARCHIVE_SCRIPT = File.join(ROOT, "conductor/.config/conductor/scripts/archive")
  CLAUDE_FILE = File.join(ROOT, "claude/.config/claude/CLAUDE.md")
  CONDUCTOR_ENV_KEYS = %w[CONDUCTOR_ROOT_PATH CONDUCTOR_PORT CONDUCTOR_WORKSPACE_NAME CONDUCTOR_WORKSPACE_PATH].freeze

  def setup
    @tmpdir = Dir.mktmpdir
    @saved_conductor_env = CONDUCTOR_ENV_KEYS.to_h { |key| [ key, ENV[key] ] }
    CONDUCTOR_ENV_KEYS.each { |key| ENV.delete(key) }
  end

  def teardown
    CONDUCTOR_ENV_KEYS.each { |key| ENV[key] = @saved_conductor_env[key] }
    FileUtils.rm_rf(@tmpdir)
  end

  def test_setup_preserves_env_local_and_exports_workspace_database_name
    project = create_git_rails_project("myapp")
    File.write(File.join(project, ".env.local"), "EXISTING=value\n")
    FileUtils.touch(File.join(project, "Gemfile.lock"))

    log_file = File.join(project, "bundle.log")
    install_bundle_stub(project, log_file)

    env = { "PATH" => "#{project}:#{ENV.fetch('PATH')}" }
    run_script(SETUP_SCRIPT, project, env: env)

    env_local = File.read(File.join(project, ".env.local"))
    assert_includes env_local, "EXISTING=value"
    assert_includes env_local, "DATABASE_NAME=myapp_myapp_development"

    log = File.read(log_file)
    assert_includes log, "DATABASE_NAME=myapp_myapp_development install --quiet"
    assert_includes log, "DATABASE_NAME=myapp_myapp_development exec rails db:prepare"
  end

  def test_run_loads_database_name_from_env_local
    project = create_rails_project("workspace")
    File.write(File.join(project, ".env.local"), "DATABASE_NAME=workspace_db\n")
    File.write(
      File.join(project, "bin/dev"),
      <<~SH
        #!/bin/sh
        printf 'DATABASE_NAME=%s\n' "${DATABASE_NAME:-}"
      SH
    )
    FileUtils.chmod("+x", File.join(project, "bin/dev"))

    output = run_script(RUN_SCRIPT, project)

    assert_includes output, "DATABASE_NAME=workspace_db"
  end

  def test_archive_loads_database_name_from_env_local
    project = create_git_rails_project("workspace")
    File.write(File.join(project, ".env.local"), "DATABASE_NAME=workspace_db\n")

    log_file = File.join(project, "bundle.log")
    install_bundle_stub(project, log_file)

    env = { "PATH" => "#{project}:#{ENV.fetch('PATH')}" }
    run_script(ARCHIVE_SCRIPT, project, env: env)

    log = File.read(log_file)
    assert_includes log, "DATABASE_NAME=workspace_db exec rails db:drop"
  end

  def test_claude_symlink_points_to_dotfiles_agents_file
    assert File.symlink?(CLAUDE_FILE), "expected #{CLAUDE_FILE} to remain a symlink"
    assert_equal File.expand_path("~/Developer/dotfiles/agents.md"), File.readlink(CLAUDE_FILE)
  end

  private

  def create_git_rails_project(name)
    project = create_rails_project(name)
    run_command("git", "-C", project, "init", "-q")
    run_command("git", "-C", project, "config", "user.name", "Test User")
    run_command("git", "-C", project, "config", "user.email", "test@example.com")
    run_command("git", "-C", project, "commit", "--allow-empty", "-m", "init", "-q")
    project
  end

  def create_rails_project(name)
    project = File.join(@tmpdir, name)
    FileUtils.mkdir_p(File.join(project, "config"))
    FileUtils.mkdir_p(File.join(project, "bin"))
    FileUtils.touch(File.join(project, "Gemfile"))
    FileUtils.touch(File.join(project, "config", "application.rb"))
    FileUtils.touch(File.join(project, "config", "database.yml"))
    project
  end

  def install_bundle_stub(project, log_file)
    File.write(
      File.join(project, "bundle"),
      <<~SH
        #!/bin/sh
        printf 'DATABASE_NAME=%s %s\n' "${DATABASE_NAME:-}" "$*" >> "#{log_file}"

        if [ "$1" = "exec" ] && [ "$2" = "rails" ] && [ "$3" = "db:version" ]; then
          exit 1
        fi

        exit 0
      SH
    )
    FileUtils.chmod("+x", File.join(project, "bundle"))
  end

  def run_script(script, workdir, env: {})
    stdout, stderr, status = Open3.capture3(env, script, chdir: workdir)
    assert status.success?, "Script failed: #{script}\n#{stdout}#{stderr}"
    stdout + stderr
  end

  def run_command(*args)
    assert system(*args), "Command failed: #{args.join(' ')}"
  end
end
