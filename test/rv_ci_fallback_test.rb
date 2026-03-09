#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

class RvCiFallbackTest < Minitest::Test
  def setup
    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log_file = File.join(@tmpdir, "commands.log")
    FileUtils.mkdir_p(@bin_dir)
    stub_commands
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_bi_uses_bundle_install_without_lockfile
    workspace = ruby_workspace("fresh-app")

    run_bi(workspace)

    assert_match(/bundle install/, command_log)
    assert_nil(/rv ci/.match(command_log))
  end

  def test_bi_uses_rv_ci_with_lockfile
    workspace = ruby_workspace("locked-app", lockfile: true)

    run_bi(workspace)

    assert_match(/rv ci/, command_log)
    assert_nil(/bundle install/.match(command_log))
  end

  def test_lefthook_uses_bundle_install_without_lockfile
    workspace = ruby_workspace("hook-fresh")

    run_shell(lefthook_bundle_command, chdir: workspace)

    assert_match(/bundle install/, command_log)
    assert_nil(/rv ci/.match(command_log))
  end

  def test_lefthook_uses_rv_ci_with_lockfile
    workspace = ruby_workspace("hook-locked", lockfile: true)

    run_shell(lefthook_bundle_command, chdir: workspace)

    assert_match(/rv ci/, command_log)
    assert_nil(/bundle install/.match(command_log))
  end

  private

  def ruby_workspace(name, lockfile: false)
    workspace = File.join(@tmpdir, name)
    FileUtils.mkdir_p(File.join(workspace, "bin"))
    File.write(File.join(workspace, "Gemfile"), "source \"https://rubygems.org\"\n")
    File.write(File.join(workspace, "Gemfile.lock"), "") if lockfile
    File.write(File.join(workspace, "bin", "rails"), "#!/bin/sh\nexit 0\n")
    FileUtils.chmod("+x", File.join(workspace, "bin", "rails"))
    workspace
  end

  def stub_commands
    write_executable("bundle", <<~SH)
      #!/bin/sh
      echo "bundle $*" >> "#{@log_file}"
    SH
    write_executable("rv", <<~SH)
      #!/bin/sh
      echo "rv $*" >> "#{@log_file}"
      if [ "$1" = "ci" ] && [ ! -f "Gemfile.lock" ]; then
        echo "MissingImplicitLockfile" >&2
        exit 1
      fi
    SH
    write_executable("solargraph", "#!/bin/sh\nexit 0\n")
    write_executable("sysctl", "#!/bin/sh\necho 8\n")
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end

  def run_bi(workspace)
    command = "source '#{aliases_path}'; bi"
    run_command("zsh", "-f", "-c", command, chdir: workspace)
  end

  def run_shell(command, chdir:)
    run_command("sh", "-c", command, chdir:)
  end

  def run_command(*command, chdir:)
    stdout, stderr, status = Open3.capture3(base_env, *command, chdir:)
    return if status.success?

    flunk <<~MSG
      #{command.join(" ")} failed with #{status.exitstatus}
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MSG
  end

  def base_env
    {
      "HOME" => @tmpdir,
      "PATH" => "#{@bin_dir}:/usr/bin:/bin"
    }
  end

  def aliases_path
    File.join(@repo_root, "zsh/.config/zsh/aliases.zsh")
  end

  def lefthook_bundle_command
    config = YAML.safe_load(File.read(File.join(@repo_root, "lefthook.yml")), aliases: true)
    config.fetch("migrations").fetch("commands").fetch("bundle").fetch("run")
  end

  def command_log
    File.exist?(@log_file) ? File.read(@log_file) : ""
  end
end
