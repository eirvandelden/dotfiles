#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# `secrets` prints export statements for the references listed in
# ~/.config/secrets/1password.env, and for the optional work overlay beside it.
# Each file is read from its own 1Password account: the personal one is named in
# the function, the work one comes from SECRETS_WORK_OP_ACCOUNT so this
# repository names no employer. `unlock` applies those exports to the current
# shell and puts the unlocked-bin directory, with its `codex` shim, first on PATH.
class SecretsLoaderTest < Minitest::Test
  ZSH_DIR = File.expand_path("../zsh/.config/zsh", __dir__)
  LOADER = File.join(ZSH_DIR, "functions/secrets.zsh")
  SHIM_DIR = File.join(ZSH_DIR, "unlocked-bin")
  REPO_MAPPING = File.expand_path("../secrets/.config/secrets/1password.env", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @config = File.join(@tmpdir, "config", "secrets")
    FileUtils.mkdir_p(@config)
    File.write(File.join(@config, "1password.env"), "PERSONAL_TOKEN=op://Private/token/credential\n")
    stub_op
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_the_work_overlay_is_read_from_the_account_the_environment_names
    write_work_overlay

    stdout, stderr, status = run_secrets("SECRETS_WORK_OP_ACCOUNT" => "employer")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "export WORK_TOKEN="
    assert_includes op_calls, "op://Work/token/credential --account employer"
  end

  def test_an_unnamed_work_account_skips_the_overlay_instead_of_reading_it_as_personal
    write_work_overlay

    stdout, stderr, status = run_secrets("SECRETS_WORK_OP_ACCOUNT" => "")

    assert_equal(0, status.exitstatus, stderr)
    assert_equal [], stdout.lines.grep(/WORK_TOKEN/)
    assert_includes stderr, "SECRETS_WORK_OP_ACCOUNT"
  end

  def test_the_personal_file_is_read_from_the_personal_account
    stdout, stderr, status = run_secrets

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "export PERSONAL_TOKEN="
    assert_includes op_calls, "op://Private/token/credential --account vandelden"
  end

  def test_the_personal_mapping_unlocks_the_home_assistant_gate_token
    FileUtils.cp(REPO_MAPPING, File.join(@config, "1password.env"))

    stdout, stderr, status = run_secrets

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "export HA_MCP_GATE_TOKEN="
    assert_includes op_calls, "op://Familie/HomeAssistantMcp/HA_MCP_GATE_TOKEN --account vandelden"
  end

  def test_unlock_exports_the_secrets_and_puts_the_unlocked_commands_first_on_path
    stdout, stderr, status = run_unlock('unlock; print -r -- "token=$PERSONAL_TOKEN"; print -r -- "path=$PATH"')

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
    assert_includes stdout, "path=#{SHIM_DIR}:"
  end

  def test_unlock_twice_keeps_one_path_entry
    stdout, stderr, status = run_unlock('unlock; unlock; print -r -- "$PATH"')

    assert_equal(0, status.exitstatus, stderr)
    assert_equal 1, stdout.split(":").count(SHIM_DIR)
  end

  def test_a_failed_unlock_changes_neither_the_environment_nor_path
    File.write(File.join(@bin, "op"), "#!/bin/sh\nexit 1\n")
    File.write(File.join(@config, "1password.env"), "FIRST=op://a/b/c\nSECOND=op://a/b/c\n")

    stdout, _, status = run_unlock('unlock; print -r -- "status=$? first=${FIRST-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    assert_includes stdout, "status=1 first=unset"
    refute_includes stdout, SHIM_DIR
  end

  def test_a_failed_unlock_before_and_reports_failure_and_changes_nothing
    fail_every_op_read

    stdout, _, status = run_unlock('unlock && print reported-success; print -r -- "first=${FIRST-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    refute_includes stdout, "reported-success"
    assert_includes stdout, "first=unset"
    refute_includes stdout, SHIM_DIR
  end

  def test_a_failed_unlock_before_or_runs_the_fallback_and_changes_nothing
    fail_every_op_read

    stdout, _, status = run_unlock('unlock || print fallback-ran; print -r -- "first=${FIRST-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    assert_includes stdout, "fallback-ran"
    assert_includes stdout, "first=unset"
    refute_includes stdout, SHIM_DIR
  end

  def test_unlock_without_the_shim_in_zdotdir_exports_the_secrets_keeps_path_and_warns_to_restow
    empty_zdotdir = File.join(@tmpdir, "empty-zdotdir")
    FileUtils.mkdir_p(empty_zdotdir)

    stdout, stderr, status = run_unlock('unlock; print -r -- "token=$PERSONAL_TOKEN path=$PATH"', "ZDOTDIR" => empty_zdotdir)

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
    refute_includes stdout, empty_zdotdir
    assert_includes stderr, "unlock: #{empty_zdotdir}/unlocked-bin/codex is missing; restow the zsh package"
  end

  def test_the_unlock_alias_no_longer_shadows_the_function
    aliases = File.join(File.dirname(LOADER), "..", "aliases.zsh")
    script = "source #{aliases}\nsource #{LOADER}\nunlock\nprint -r -- \"token=$PERSONAL_TOKEN\""

    stdout, stderr, status = Open3.capture3(env, "zsh", "-f", "-c", script)

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
  end

  private

  def write_work_overlay
    File.write(File.join(@config, "1password.work.env"), "WORK_TOKEN=op://Work/token/credential\n")
  end

  # A stand-in for the 1Password CLI: records the arguments it was called with
  # and answers with a value, so no real vault is touched.
  def stub_op
    @bin = File.join(@tmpdir, "bin")
    FileUtils.mkdir_p(@bin)
    op = File.join(@bin, "op")
    File.write(op, <<~SH)
      #!/bin/sh
      shift # drop "read"
      echo "$*" >> "#{op_log}"
      echo "a-secret-value"
    SH
    FileUtils.chmod(0o755, op)
  end

  # zsh ignores `set -e` on the left of && and ||, so these failures must be
  # caught without it.
  def fail_every_op_read
    File.write(File.join(@bin, "op"), "#!/bin/sh\nexit 1\n")
    File.write(File.join(@config, "1password.env"), "FIRST=op://a/b/c\nSECOND=op://a/b/c\n")
  end

  def op_log
    File.join(@tmpdir, "op-calls.log")
  end

  def op_calls
    File.exist?(op_log) ? File.read(op_log) : ""
  end

  def run_secrets(extra_env = {})
    Open3.capture3(env.merge(extra_env), "zsh", "-c", "source #{LOADER} && secrets")
  end

  def run_unlock(script, extra_env = {})
    Open3.capture3(env.merge(extra_env), "zsh", "-f", "-c", "source #{LOADER}\n#{script}")
  end

  def env
    {
      "XDG_CONFIG_HOME" => File.join(@tmpdir, "config"),
      "ZDOTDIR" => ZSH_DIR,
      "PATH" => "#{@bin}:#{ENV.fetch('PATH')}"
    }
  end
end
