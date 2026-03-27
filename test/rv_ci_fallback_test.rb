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

  def test_bi_uses_bundle_install_with_lockfile
    workspace = ruby_workspace("locked-app", lockfile: true)

    run_bi(workspace)

    assert_match(/bundle install/, command_log)
    assert_nil(/rv ci/.match(command_log))
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

  def test_verify_ruby_path_accepts_rv_managed_ruby
    write_version_file(".ruby-version", "4.0.2")
    ruby_path = write_managed_executable(".local/share/rv/rubies/ruby-4.0.2/bin/ruby")

    run_shell(pre_push_command("verify-ruby-path"), chdir: @tmpdir, env: path_env_for(ruby_path))
  end

  def test_verify_ruby_path_rejects_non_rv_ruby
    write_version_file(".ruby-version", "4.0.2")
    ruby_path = write_executable("ruby", "#!/bin/sh\nexit 0\n")

    error = assert_raises(Minitest::Assertion) do
      run_shell(pre_push_command("verify-ruby-path"), chdir: @tmpdir, env: path_env_for(ruby_path))
    end

    assert_match(/ruby resolves outside rv-managed path/, error.message)
  end

  def test_verify_node_path_accepts_chnode_managed_node
    write_version_file(".node-version", "22.21.1")
    node_path = write_managed_executable(".nodes/node-22.21.1/bin/node")

    run_shell(pre_push_command("verify-node-path"), chdir: @tmpdir, env: path_env_for(node_path))
  end

  def test_verify_node_path_rejects_non_chnode_node
    write_version_file(".node-version", "22.21.1")
    node_path = write_executable("node", "#!/bin/sh\nexit 0\n")

    error = assert_raises(Minitest::Assertion) do
      run_shell(pre_push_command("verify-node-path"), chdir: @tmpdir, env: path_env_for(node_path))
    end

    assert_match(/node resolves outside chnode-managed path/, error.message)
  end

  def test_environment_skips_chnode_prompt_hook_when_chnode_is_unavailable
    output = capture_command(
      "zsh", "-f", "-c", <<~SH, chdir: @tmpdir
        autoload -Uz compinit
        compinit
        export HOMEBREW_PREFIX="#{@tmpdir}/missing-homebrew"
        source "#{File.join(@repo_root, "zsh/.config/zsh/paths.zsh")}"
        source "#{File.join(@repo_root, "zsh/.config/zsh/environment.zsh")}"
        printf '%s\n' "${precmd_functions[*]}"
      SH
    )

    assert_no_match(/chnode_auto/, output)
  end

  def test_paths_registers_directory_hooks_without_startup_errors
    write_stub_homebrew_command("rv", <<~SH)
      #!/bin/sh
      if [ "$1" = "shell" ] && [ "$2" = "init" ]; then
        printf '%s\n' 'function _rv_autoload_hook() { :; }'
      fi
    SH
    write_stub_chnode_scripts

    result = capture_command_result(
      "zsh", "-f", "-c", <<~SH, chdir: @tmpdir,
        export HOMEBREW_PREFIX="#{@tmpdir}/homebrew"
        source "#{File.join(@repo_root, "zsh/.config/zsh/paths.zsh")}"
        printf '%s\n' "${chpwd_functions[*]}"
      SH
    )

    assert_equal("", result[:stderr])
    assert_match(/_rv_autoload_hook/, result[:stdout])
    assert_match(/chnode_auto/, result[:stdout])
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
    path
  end

  def write_managed_executable(relative_path)
    path = File.join(@tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\nexit 0\n")
    FileUtils.chmod("+x", path)
    path
  end

  def write_version_file(name, version)
    File.write(File.join(@tmpdir, name), "#{version}\n")
  end

  def run_bi(workspace)
    command = "source '#{aliases_path}'; bi"
    run_command("zsh", "-f", "-c", command, chdir: workspace)
  end

  def run_shell(command, chdir:, env: {})
    run_command("sh", "-c", command, chdir:, env:)
  end

  def run_command(*command, chdir:, env: {})
    stdout, stderr, status = Open3.capture3(base_env.merge(env), *command, chdir:)
    return if status.success?

    flunk <<~MSG
      #{command.join(" ")} failed with #{status.exitstatus}
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MSG
  end

  def capture_command(*command, chdir:, env: {})
    result = capture_command_result(*command, chdir:, env:)
    return result[:stdout] if result[:status].success?

    flunk <<~MSG
      #{command.join(" ")} failed with #{result[:status].exitstatus}
      stdout:
      #{result[:stdout]}
      stderr:
      #{result[:stderr]}
    MSG
  end

  def capture_command_result(*command, chdir:, env: {})
    stdout, stderr, status = Open3.capture3(base_env.merge(env), *command, chdir:)
    { stdout:, stderr:, status: }
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
    lefthook_config.fetch("migrations").fetch("commands").fetch("bundle").fetch("run")
  end

  def pre_push_command(name)
    lefthook_config.fetch("pre-push").fetch("commands").fetch(name).fetch("run")
  end

  def lefthook_config
    deep_merge(load_yaml("lefthook.yml"), load_yaml("lefthook-local.yml"))
  end

  def load_yaml(name)
    path = File.join(@repo_root, name)
    return {} unless File.exist?(path)

    YAML.safe_load(File.read(path), aliases: true) || {}
  end

  def deep_merge(left, right)
    left.merge(right) do |_key, left_value, right_value|
      if left_value.is_a?(Hash) && right_value.is_a?(Hash)
        deep_merge(left_value, right_value)
      else
        right_value
      end
    end
  end

  def assert_no_match(pattern, value)
    assert_not(pattern.match?(value), "Expected #{value.inspect} to not match #{pattern.inspect}")
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end

  def write_stub_homebrew_command(name, body)
    path = File.join(@tmpdir, "homebrew", "bin", name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    FileUtils.chmod("+x", path)
    path
  end

  def write_stub_chnode_scripts
    chnode_root = File.join(@tmpdir, "homebrew", "opt", "chnode", "share", "chnode")
    FileUtils.mkdir_p(chnode_root)
    File.write(File.join(chnode_root, "chnode.sh"), "# chnode stub\n")
    File.write(File.join(chnode_root, "auto.sh"), "chnode_auto() { :; }\n")
  end

  def path_env_for(binary_path)
    { "PATH" => "#{File.dirname(binary_path)}:/usr/bin:/bin" }
  end

  def command_log
    File.exist?(@log_file) ? File.read(@log_file) : ""
  end
end
