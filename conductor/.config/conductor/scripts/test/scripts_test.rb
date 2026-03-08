#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "open3"

class ConductorScriptTest < Minitest::Test
  SCRIPT_DIR = File.expand_path("..", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log_file = File.join(@tmpdir, "commands.log")
    FileUtils.mkdir_p(@bin_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_setup_without_lockfile_uses_bundle_install
    workspace = rails_workspace("fresh-app")
    stub_setup_commands(database_exists: true)

    run_script("setup", chdir: workspace)

    assert_includes command_log, "bundle install"
    refute_includes command_log, "rv ci"
  end

  def test_setup_uses_bundle_exec_for_database_commands
    workspace = rails_workspace("db-app", lockfile: true)
    stub_setup_commands(database_exists: false)

    run_script("setup", chdir: workspace)

    assert_includes command_log, "bundle exec rails db:version"
    assert_includes command_log, "bundle exec rails db:prepare"
  end

  def test_run_uses_bundle_exec_for_procfile_projects
    workspace = rails_workspace("procfile-app", procfile: true)
    stub_run_commands

    run_script("run", chdir: workspace, env: { "CONDUCTOR_PORT" => "4567" })

    assert_includes command_log, "bundle exec foreman start -f Procfile.dev -p 4567"
  end

  def test_run_uses_bundle_exec_for_rails_server_fallback
    workspace = rails_workspace("server-app")
    stub_run_commands

    run_script("run", chdir: workspace, env: { "CONDUCTOR_PORT" => "4567" })

    assert_includes command_log, "bundle exec rails server -p 4567"
  end

  private

  def rails_workspace(name, lockfile: false, procfile: false)
    workspace = File.join(@tmpdir, name)
    FileUtils.mkdir_p(File.join(workspace, "config"))
    FileUtils.touch(File.join(workspace, "config", "application.rb"))
    FileUtils.touch(File.join(workspace, "config", "database.yml"))
    FileUtils.touch(File.join(workspace, "Gemfile"))
    FileUtils.touch(File.join(workspace, "Gemfile.lock")) if lockfile
    FileUtils.touch(File.join(workspace, "Procfile.dev")) if procfile
    workspace
  end

  def stub_setup_commands(database_exists:)
    write_executable("bundle", bundle_setup_script(database_exists:))
    write_executable("git", <<~SH)
      #!/bin/sh
      if [ "$1" = "rev-parse" ] && [ "$2" = "--show-toplevel" ]; then
        pwd
        exit 0
      fi
      exit 1
    SH
    write_executable("rv", <<~SH)
      #!/bin/sh
      echo "rv $*" >> "#{@log_file}"
    SH
    write_executable("rails", <<~SH)
      #!/bin/sh
      echo "rails $*" >> "#{@log_file}"
      if [ "$1" = "db:version" ]; then
        exit #{database_exists ? 0 : 1}
      fi
    SH
  end

  def stub_run_commands
    write_executable("bundle", <<~SH)
      #!/bin/sh
      echo "bundle $*" >> "#{@log_file}"
    SH
    write_executable("foreman", <<~SH)
      #!/bin/sh
      echo "foreman $*" >> "#{@log_file}"
    SH
    write_executable("rails", <<~SH)
      #!/bin/sh
      echo "rails $*" >> "#{@log_file}"
    SH
  end

  def bundle_setup_script(database_exists:)
    result = database_exists ? 0 : 1

    <<~SH
      #!/bin/sh
      echo "bundle $*" >> "#{@log_file}"
      if [ "$1" = "exec" ] && [ "$2" = "rails" ] && [ "$3" = "db:version" ]; then
        exit #{result}
      fi
    SH
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end

  def run_script(name, chdir:, env: {})
    script = File.join(SCRIPT_DIR, name)
    stdout, stderr, status = Open3.capture3(base_env.merge(env), script, chdir:)
    return if status.success?

    flunk <<~MSG
      #{name} failed with #{status.exitstatus}
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MSG
  end

  def base_env
    {
      "HOME" => @tmpdir,
      "PATH" => "#{@bin_dir}:/usr/bin:/bin",
      "ZDOTDIR" => @tmpdir
    }
  end

  def command_log
    File.exist?(@log_file) ? File.read(@log_file) : ""
  end
end
