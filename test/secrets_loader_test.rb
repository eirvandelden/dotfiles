#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# `secrets` prints export statements for the references listed in
# ~/.config/secrets/1password.env, and for the optional work overlay beside it.
# Each file is read from its own 1Password account: the personal one is named in
# the function, the work one comes from SECRETS_WORK_OP_ACCOUNT so this
# repository names no employer.
class SecretsLoaderTest < Minitest::Test
  LOADER = File.expand_path("../zsh/.config/zsh/functions/secrets.zsh", __dir__)

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

  def op_log
    File.join(@tmpdir, "op-calls.log")
  end

  def op_calls
    File.exist?(op_log) ? File.read(op_log) : ""
  end

  def run_secrets(env = {})
    full_env = {
      "XDG_CONFIG_HOME" => File.join(@tmpdir, "config"),
      "PATH" => "#{@bin}:#{ENV.fetch('PATH')}"
    }.merge(env)
    Open3.capture3(full_env, "zsh", "-c", "source #{LOADER} && secrets")
  end
end
