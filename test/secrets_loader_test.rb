#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"
require_relative "codex_shim_support"

# `secrets` prints export statements for the references listed in
# ~/.config/secrets/1password.env, and for the optional work overlay beside it.
# Each file is read from its own 1Password account: the personal one is named in
# the function, the work one comes from SECRETS_WORK_OP_ACCOUNT so this
# repository names no employer. `unlock` applies those exports to the current
# shell and puts the unlocked-bin directory, with its `codex` shim, first on PATH.
class SecretsLoaderTest < Minitest::Test
  include CodexShimSupport

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

    stdout, stderr, status = run_secrets("both", "SECRETS_WORK_OP_ACCOUNT" => "employer")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "export WORK_TOKEN="
    assert_includes op_calls, "op://Work/token/credential --account employer"
  end

  def test_unlock_both_without_the_work_account_warns_and_loads_personal
    write_work_overlay

    stdout, stderr, status = run_secrets("both", "SECRETS_WORK_OP_ACCOUNT" => "")

    assert_equal(0, status.exitstatus, stderr)
    assert_equal [], stdout.lines.grep(/WORK_TOKEN/)
    assert_includes stderr, "SECRETS_WORK_OP_ACCOUNT"
  end

  def test_the_personal_file_is_read_from_the_personal_account
    stdout, stderr, status = run_secrets("personal")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "export PERSONAL_TOKEN="
    assert_includes op_calls, "op://Private/token/credential --account vandelden"
  end

  def test_the_personal_mapping_unlocks_the_home_assistant_gate_token
    FileUtils.cp(REPO_MAPPING, File.join(@config, "1password.env"))

    stdout, stderr, status = run_secrets("personal")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "export HA_MCP_GATE_TOKEN="
    assert_includes op_calls, "op://Familie/HomeAssistantMcp/HA_MCP_GATE_TOKEN --account vandelden"
  end

  def test_unlock_exports_the_secrets_and_puts_the_unlocked_commands_first_on_path
    stdout, stderr, status = run_unlock('unlock personal; print -r -- "token=$PERSONAL_TOKEN"; print -r -- "path=$PATH"')

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
    assert_includes stdout, "path=#{SHIM_DIR}:"
  end

  def test_unlock_twice_keeps_one_path_entry
    stdout, stderr, status = run_unlock('unlock personal; unlock personal; print -r -- "$PATH"')

    assert_equal(0, status.exitstatus, stderr)
    assert_equal 1, stdout.split(":").count(SHIM_DIR)
  end

  def test_a_failed_unlock_changes_neither_the_environment_nor_path
    File.write(File.join(@bin, "op"), "#!/bin/sh\nexit 1\n")
    File.write(File.join(@config, "1password.env"), "FIRST=op://a/b/c\nSECOND=op://a/b/c\n")

    stdout, _, status = run_unlock('unlock personal; print -r -- "status=$? first=${FIRST-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    assert_includes stdout, "status=1 first=unset"
    refute_includes stdout, SHIM_DIR
  end

  def test_a_failed_unlock_before_and_reports_failure_and_changes_nothing
    fail_every_op_read

    stdout, _, status = run_unlock('unlock personal && print reported-success; print -r -- "first=${FIRST-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    refute_includes stdout, "reported-success"
    assert_includes stdout, "first=unset"
    refute_includes stdout, SHIM_DIR
  end

  def test_a_failed_unlock_before_or_runs_the_fallback_and_changes_nothing
    fail_every_op_read

    stdout, _, status = run_unlock('unlock personal || print fallback-ran; print -r -- "first=${FIRST-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    assert_includes stdout, "fallback-ran"
    assert_includes stdout, "first=unset"
    refute_includes stdout, SHIM_DIR
  end

  def test_unlock_without_the_shim_in_zdotdir_exports_the_secrets_keeps_path_and_warns_to_restow
    empty_zdotdir = File.join(@tmpdir, "empty-zdotdir")
    FileUtils.mkdir_p(empty_zdotdir)

    stdout, stderr, status = run_unlock('unlock personal; print -r -- "token=$PERSONAL_TOKEN path=$PATH"', "ZDOTDIR" => empty_zdotdir)

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
    refute_includes stdout, empty_zdotdir
    assert_includes stderr, "unlock: #{empty_zdotdir}/unlocked-bin/codex is missing; restow the zsh package"
  end

  def test_unlock_exports_the_shim_directory_to_child_shells
    stdout, stderr, status = run_unlock('unlock personal; zsh -f -c \'print -r -- "marker=$UNLOCKED_BIN"\'')

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "marker=#{SHIM_DIR}"
  end

  # Codex runs its shell commands as `zsh -lc`. On macOS, /etc/zprofile runs
  # path_helper there, which moves /opt/homebrew/bin ahead of the shim.
  def test_zprofile_puts_the_shim_back_ahead_of_a_reordered_path
    stdout, stderr, status = run_zprofile("UNLOCKED_BIN" => SHIM_DIR)

    assert_equal(0, status.exitstatus, stderr)
    assert_equal File.join(SHIM_DIR, "codex"), stdout.chomp
  end

  def test_zprofile_leaves_path_alone_without_unlock
    stdout, stderr, status = run_zprofile

    assert_equal(0, status.exitstatus, stderr)
    assert_equal File.join(@tmpdir, "homebrew-bin", "codex"), stdout.chomp
  end

  # paths.zsh runs in every shell and puts /usr/local/bin and /usr/bin first,
  # where an Intel Mac or Linux keeps codex.
  def test_paths_zsh_keeps_the_shim_first_after_unlock
    script = "source #{File.join(ZSH_DIR, 'paths.zsh')}\nprint -r -- \"first=$path[1]\""
    stdout, stderr, status = Open3.capture3(env.merge("UNLOCKED_BIN" => SHIM_DIR), "zsh", "-f", "-c", script)

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "first=#{SHIM_DIR}\n"
  end

  # End to end on a Mac whose path_helper puts a real codex ahead of the shim.
  # Elsewhere it passes without the fix; the zprofile tests prove the logic.
  def test_a_login_shell_started_after_unlock_finds_the_shim_first
    stdout, stderr, status = run_unlock('unlock personal; zsh -l -c "command -v codex"', "HOME" => stowed_home)

    assert_equal(0, status.exitstatus, stderr)
    assert_equal File.join(SHIM_DIR, "codex"), stdout.lines.last.to_s.chomp
  end

  def test_the_unlock_alias_no_longer_shadows_the_function
    aliases = File.join(File.dirname(LOADER), "..", "aliases.zsh")
    script = "source #{aliases}\nsource #{LOADER}\nunlock personal\nprint -r -- \"token=$PERSONAL_TOKEN\""

    stdout, stderr, status = Open3.capture3(env, "zsh", "-f", "-c", script)

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
  end

  def test_the_personal_mapping_resolves_the_journal_assistant_token_from_1password
    FileUtils.cp(REPO_MAPPING, File.join(@config, "1password.env"))

    stdout, stderr, status = run_secrets("personal")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "export JOURNAL_ASSISTANT_TOKEN="
    assert_includes op_calls, "op://Familie/JournalAdministration/assistant_token --account vandelden"
  end

  def test_unlock_personal_exports_the_personal_secrets_and_reads_nothing_from_the_work_account
    write_work_overlay

    stdout, stderr, status = run_unlock('unlock personal; print -r -- "work=${WORK_TOKEN-unset}"; print -r -- "token=$PERSONAL_TOKEN"',
                                        "SECRETS_WORK_OP_ACCOUNT" => "employer")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
    assert_includes stdout, "work=unset"
    assert_includes op_calls, "--account vandelden"
    refute_includes op_calls, "--account employer"
    refute_includes stderr, "scope?"
  end

  def test_unlock_work_exports_the_work_secrets_and_reads_nothing_from_the_personal_account
    write_work_overlay

    stdout, stderr, status = run_unlock('unlock work; print -r -- "work=$WORK_TOKEN"; print -r -- "personal=${PERSONAL_TOKEN-unset}"',
                                        "SECRETS_WORK_OP_ACCOUNT" => "employer")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "work=a-secret-value"
    assert_includes stdout, "personal=unset"
    assert_includes op_calls, "--account employer"
    refute_includes op_calls, "--account vandelden"
    refute_includes stderr, "scope?"
  end

  def test_unlock_both_exports_both_sets
    write_work_overlay

    stdout, stderr, status = run_unlock('unlock both; print -r -- "work=$WORK_TOKEN personal=$PERSONAL_TOKEN"',
                                        "SECRETS_WORK_OP_ACCOUNT" => "employer")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "work=a-secret-value personal=a-secret-value"
  end

  def test_a_bare_unlock_without_a_terminal_prints_the_usage_and_applies_nothing
    stdout, stderr, status = run_unlock('unlock; print -r -- "status=$? token=${PERSONAL_TOKEN-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    assert_includes stderr, "usage: unlock [personal|work|both]"
    assert_includes stdout, "status=2 token=unset"
    refute_includes stdout, SHIM_DIR
    assert_equal "", op_calls
  end

  def test_unlock_with_an_unknown_scope_prints_the_usage_and_applies_nothing
    stdout, stderr, status = run_unlock('unlock bogus; print -r -- "status=$? token=${PERSONAL_TOKEN-unset} path=$PATH"')

    assert_equal(0, status.exitstatus)
    assert_includes stderr, "usage: unlock [personal|work|both]"
    assert_includes stdout, "status=2 token=unset"
    refute_includes stdout, SHIM_DIR
    assert_equal "", op_calls
  end

  def test_unlock_with_two_scopes_prints_the_usage_and_applies_nothing
    stdout, stderr, status = run_unlock('unlock personal work; print -r -- "status=$? token=${PERSONAL_TOKEN-unset}"')

    assert_equal(0, status.exitstatus)
    assert_includes stderr, "usage: unlock [personal|work|both]"
    assert_includes stdout, "status=2 token=unset"
    assert_equal "", op_calls
  end

  def test_bare_secrets_without_a_terminal_prints_the_secrets_usage_and_no_exports
    stdout, stderr, status = Open3.capture3(env, "zsh", "-f", "-c", "source #{LOADER}\nsecrets")

    assert_equal(2, status.exitstatus)
    assert_includes stderr, "usage: secrets [personal|work|both]"
    assert_equal "", stdout
    assert_equal "", op_calls
  end

  def test_unlock_work_without_the_work_account_fails_naming_the_variable_and_applies_nothing
    write_work_overlay

    stdout, stderr, status = run_unlock('unlock work; print -r -- "status=$? work=${WORK_TOKEN-unset} path=$PATH"',
                                        "SECRETS_WORK_OP_ACCOUNT" => nil)

    assert_equal(0, status.exitstatus)
    assert_includes stderr, "SECRETS_WORK_OP_ACCOUNT"
    assert_includes stdout, "status=1 work=unset"
    refute_includes stdout, SHIM_DIR
    assert_equal "", op_calls
  end

  def test_unlock_work_needs_no_personal_file
    write_work_overlay
    FileUtils.rm(File.join(@config, "1password.env"))

    stdout, stderr, status = run_unlock('unlock work; print -r -- "work=$WORK_TOKEN"', "SECRETS_WORK_OP_ACCOUNT" => "employer")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "work=a-secret-value"
  end

  def test_unlock_work_without_the_work_overlay_fails_and_applies_nothing
    stdout, stderr, status = run_unlock('unlock work; print -r -- "status=$? path=$PATH"', "SECRETS_WORK_OP_ACCOUNT" => "employer")

    assert_equal(0, status.exitstatus)
    assert_includes stderr, "secrets: config not found:"
    assert_includes stdout, "status=1"
    refute_includes stdout, SHIM_DIR
  end

  def test_unlock_personal_ignores_the_work_overlay_without_a_work_account
    write_work_overlay

    stdout, stderr, status = run_unlock('unlock personal; print -r -- "token=$PERSONAL_TOKEN"', "SECRETS_WORK_OP_ACCOUNT" => "")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes stdout, "token=a-secret-value"
    refute_includes stderr, "SECRETS_WORK_OP_ACCOUNT"
  end

  private

  # The PATH that path_helper leaves behind: a directory with a real codex
  # ahead of the shim.
  def run_zprofile(extra_env = {})
    homebrew_bin = File.join(@tmpdir, "homebrew-bin")
    FileUtils.mkdir_p(homebrew_bin)
    File.write(File.join(homebrew_bin, "codex"), "#!/bin/sh\n")
    FileUtils.chmod(0o755, File.join(homebrew_bin, "codex"))
    path = "#{homebrew_bin}:#{SHIM_DIR}:/usr/bin:/bin"
    script = "source #{File.join(ZSH_DIR, '.zprofile')}\ncommand -v codex"
    Open3.capture3(env.merge("PATH" => path).merge(extra_env), "zsh", "-f", "-c", script)
  end

  # A HOME laid out as stow leaves it, so a login shell reads this branch's files.
  def stowed_home
    home = File.join(@tmpdir, "home")
    FileUtils.mkdir_p(File.join(home, ".config"))
    File.symlink(ZSH_DIR, File.join(home, ".config", "zsh"))
    home
  end

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

  def run_secrets(scope, extra_env = {})
    Open3.capture3(env.merge(extra_env), "zsh", "-c", "source #{LOADER} && secrets #{scope}")
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
