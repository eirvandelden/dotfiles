#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "open3"

class ConductorScriptTest < Minitest::Test
  SCRIPT_DIR = File.expand_path("..", __dir__)

  def setup
    @tmpdir = File.realpath(Dir.mktmpdir)
    @bin_dir = File.join(@tmpdir, "bin")
    @log_file = File.join(@tmpdir, "commands.log")
    FileUtils.mkdir_p(@bin_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_setup_runs_worktree_setup_when_available
    workspace = rails_workspace("my-app")
    write_executable("worktree-setup", "#!/bin/sh\necho 'worktree-setup' >> \"#{@log_file}\"\n")

    run_script("setup", chdir: workspace)

    assert_includes command_log, "worktree-setup"
  end

  def test_setup_warns_when_worktree_setup_missing
    workspace = rails_workspace("my-app")

    result = run_script("setup", chdir: workspace)

    assert_includes result.fetch(:stderr), "worktree-setup not found"
  end

  def test_run_starts_bin_dev_when_present
    workspace = rails_workspace("bin-dev-app", bin_dev: true)
    stub_run_commands

    result = run_script("run", chdir: workspace)

    assert_includes result.fetch(:stdout), "Using bin/dev"
    assert_includes result.fetch(:stdout), "port 3010"
  end

  def test_run_uses_bundle_exec_for_procfile_projects
    workspace = rails_workspace("procfile-app", procfile: true)
    stub_run_commands

    run_script("run", chdir: workspace)

    assert_includes command_log, "bundle exec foreman start -f Procfile.dev -p 3010"
  end

  def test_run_uses_bundle_exec_for_rails_server_fallback
    workspace = rails_workspace("server-app")
    stub_run_commands

    run_script("run", chdir: workspace)

    assert_includes command_log, "bundle exec rails server -p 3010"
  end

  def test_archive_removes_context_directory
    workspace = rails_workspace("my-app")
    context_dir = File.join(workspace, ".context")
    FileUtils.mkdir_p(context_dir)
    File.write(File.join(context_dir, "notes.md"), "some notes")

    run_script("archive", chdir: workspace)

    refute File.exist?(context_dir)
  end

  def test_archive_runs_worktree_remove_when_available
    workspace = rails_workspace("my-app")
    write_executable("worktree-remove", "#!/bin/sh\necho \"worktree-remove $*\" >> \"#{@log_file}\"\n")

    run_script("archive", chdir: workspace)

    assert_includes command_log, "worktree-remove #{workspace}"
  end

  private

  def rails_workspace(name, bin_dev: false, procfile: false)
    workspace = File.join(@tmpdir, name)
    FileUtils.mkdir_p(File.join(workspace, "config"))
    FileUtils.touch(File.join(workspace, "config", "application.rb"))
    FileUtils.touch(File.join(workspace, "config", "database.yml"))
    FileUtils.touch(File.join(workspace, "Gemfile"))
    if bin_dev
      bin_dir = File.join(workspace, "bin")
      FileUtils.mkdir_p(bin_dir)
      dev_script = File.join(bin_dir, "dev")
      File.write(dev_script, "#!/bin/sh\necho \"bin/dev PORT=$PORT\" >> \"#{@log_file}\"\n")
      FileUtils.chmod("+x", dev_script)
    end
    FileUtils.touch(File.join(workspace, "Procfile.dev")) if procfile
    workspace
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
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end

  def run_script(name, chdir:, env: {})
    script = File.join(SCRIPT_DIR, name)
    stdout, stderr, status = Open3.capture3(base_env.merge(env), script, chdir:)
    return { stdout:, stderr:, status: } if status.success?

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
