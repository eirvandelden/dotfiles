#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Git gets GitHub HTTPS credentials from 1Password and nothing from the
# Keychain. Each test runs real `git credential` against the dotfiles git
# config, with a stub `op` on a minimal PATH, the dotfiles checkout linked at
# ~/Developer/dotfiles in a temporary HOME (and nothing restowed), and a
# stand-in Keychain helper in a temporary
# system config. Xcode's own gitconfig still loads on macOS; git cannot reach its
# osxkeychain program because GIT_EXEC_PATH is empty and PATH holds only the stubs,
# /usr/bin and /bin. `stub-token` is a placeholder, not a secret.
class GitCredentialHelperTest < Minitest::Test
  CONFIG = File.expand_path("../git/.config/git/config", __dir__)
  CHECKOUT = File.expand_path("..", __dir__)
  OP_REFERENCE = "read op://Familie/Github/token --account vandelden".freeze
  UNSET = %w[
    GIT_DIR GIT_WORK_TREE GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
    GIT_ASKPASS SSH_ASKPASS XDG_CONFIG_HOME
  ].to_h { |name| [ name, nil ] }.freeze

  def setup
    @tmpdir = Dir.mktmpdir
    @bin = File.join(@tmpdir, "bin")
    @exec_path = File.join(@tmpdir, "exec-path")
    FileUtils.mkdir_p([ @bin, @exec_path ])
    stub_op
    stub_keychain
    write_system_config
    link_dotfiles_checkout
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_github_credentials_come_from_the_1password_item
    stdout, stderr, status = fill("github.com")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "username=x-access-token"
    assert_includes stdout, "password=stub-token"
    assert_includes op_calls, OP_REFERENCE
    assert_equal "", keychain_calls
  end

  def test_a_git_credential_1password_program_on_path_does_not_replace_the_helper
    write_executable(File.join(@bin, "git-credential-1password"), <<~SH)
      #!/bin/sh
      echo "username=impostor"
      echo "password=from-impostor"
    SH

    stdout, stderr, status = fill("github.com")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "password=stub-token"
    refute_includes stdout, "from-impostor"
  end

  def test_gist_credentials_come_from_the_1password_item
    stdout, stderr, status = fill("gist.github.com")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "username=x-access-token"
    assert_includes stdout, "password=stub-token"
    assert_includes op_calls, OP_REFERENCE
    assert_equal "", keychain_calls
  end

  def test_storing_a_github_credential_leaves_1password_alone
    _stdout, stderr, status = git_credential("approve", github_credential)

    assert_equal(0, status.exitstatus, stderr)
    assert_equal "", op_calls
    assert_equal "", keychain_calls
  end

  def test_erasing_a_github_credential_leaves_1password_alone
    _stdout, stderr, status = git_credential("reject", github_credential)

    assert_equal(0, status.exitstatus, stderr)
    assert_equal "", op_calls
    assert_equal "", keychain_calls
  end

  def test_a_failed_op_read_gives_git_no_github_password
    stub_failing_op

    stdout, stderr, status = fill("github.com", "-c", "credential.helper=#{keychain}")

    refute status.success?, "git should stop when op read fails"
    refute_includes stdout, "password="
    assert_includes stderr, "told us to quit"
    assert_equal "", keychain_calls
  end

  def test_another_host_gets_no_credentials_from_any_helper
    stdout, _stderr, status = fill("gitlab.com")

    refute status.success?, "git should find no credential for another host"
    refute_includes stdout, "password="
    assert_equal "", op_calls
    assert_equal "", keychain_calls
  end

  def test_the_config_names_no_osxkeychain_helper
    settings = File.readlines(CONFIG).map(&:strip).reject { |line| line.start_with?("#") }

    assert_equal [], settings.grep(/osxkeychain/)
  end

  def test_the_config_reads_nothing_from_the_keychain
    assert_equal [], File.readlines(CONFIG).grep(/find-generic-password/)
  end

  private

  # A stand-in for the 1Password CLI: records its arguments and answers with a
  # placeholder, so no real vault is touched.
  def stub_op
    write_executable(File.join(@bin, "op"), <<~SH)
      #!/bin/sh
      echo "$*" >> "#{op_log}"
      echo "stub-token"
    SH
  end

  def stub_failing_op
    write_executable(File.join(@bin, "op"), <<~SH)
      #!/bin/sh
      echo "$*" >> "#{op_log}"
      echo "op: vault is locked" >&2
      exit 1
    SH
  end

  # Plays the Keychain helper that Xcode's system gitconfig names.
  def stub_keychain
    write_executable(keychain, <<~SH)
      #!/bin/sh
      echo "$1" >> "#{keychain_log}"
      echo "username=keychain"
      echo "password=from-keychain"
    SH
  end

  # The checkout sits where the global hooks expect it. Nothing from the git
  # package is restowed, as on a machine that pulled the merge but has not run
  # install.sh yet.
  def link_dotfiles_checkout
    target = File.join(@tmpdir, "Developer", "dotfiles")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(CHECKOUT, target)
  end

  def write_system_config
    File.write(system_config, "[credential]\n\thelper = #{keychain}\n")
  end

  def write_executable(path, body)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end

  def keychain
    File.join(@tmpdir, "keychain-standin")
  end

  def system_config
    File.join(@tmpdir, "system.gitconfig")
  end

  def op_log
    File.join(@tmpdir, "op-calls.log")
  end

  def keychain_log
    File.join(@tmpdir, "keychain-calls.log")
  end

  def op_calls
    File.exist?(op_log) ? File.read(op_log) : ""
  end

  def keychain_calls
    File.exist?(keychain_log) ? File.read(keychain_log) : ""
  end

  def github_credential
    "protocol=https\nhost=github.com\nusername=x-access-token\npassword=stub-token\n\n"
  end

  def fill(host, *options)
    git_credential("fill", "protocol=https\nhost=#{host}\n\n", *options)
  end

  def git_credential(action, input, *options)
    Open3.capture3(git_env, "git", *options, "credential", action, stdin_data: input, chdir: @tmpdir)
  end

  def git_env
    UNSET.merge(
      "HOME" => @tmpdir,
      "PATH" => "#{@bin}:/usr/bin:/bin",
      "GIT_CONFIG_GLOBAL" => CONFIG,
      "GIT_CONFIG_SYSTEM" => system_config,
      "GIT_EXEC_PATH" => @exec_path,
      "GIT_TERMINAL_PROMPT" => "0"
    )
  end
end
