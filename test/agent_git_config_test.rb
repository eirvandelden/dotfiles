#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "agent_git_support"
require_relative "isolated_git"

# Behind the agent include, a personal repository gets the agent identity, signer and hooks; any other
# repository keeps Etienne's config. Every test runs real git in a temporary HOME.
class AgentGitConfigTest < Minitest::Test
  include AgentGitSupport

  def setup
    setup_agent_home
    make_signing_key
  end

  def teardown
    teardown_agent_home
  end

  def allowed_signers
    file = File.join(@home, "allowed_signers")
    File.write(file, "etienne@vandelden.family namespaces=\"git\" #{File.read("#{signing_key}.pub")}")
    file
  end

  def test_an_agent_commit_in_a_personal_repository_is_signed_by_the_agent_key
    path = repository
    _out, err, status = commit(path)

    assert status.success?, err
    out, = git(path, "-c", "gpg.ssh.allowedSignersFile=#{allowed_signers}", "log", "-1", "--format=%an|%G?|%GK")
    author, state, key = out.strip.split("|")

    assert_equal "Claude (agent)", author
    assert_equal "G", state
    assert_includes key, "SHA256:"
  end

  def test_the_agent_key_and_etiennes_key_are_told_apart
    path = repository
    commit(path, "agent")
    other = File.join(@home, "other_key")
    system("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", other, exception: true)
    signers = File.join(@home, "signers")
    File.write(signers, [ signing_key, other ].map { |key| "etienne@vandelden.family namespaces=\"git\" #{File.read("#{key}.pub")}" }.join)
    own = plain_env("GIT_AUTHOR_NAME" => "Etienne", "GIT_AUTHOR_EMAIL" => "etienne@vandelden.family")
    File.write(File.join(path, "own.txt"), "own\n")
    git(path, "add", "own.txt", env: own)
    git(path, "-c", "gpg.format=ssh", "-c", "user.signingkey=#{other}", "-c", "commit.gpgsign=true", "commit", "-q", "-m", "own", env: own)

    out, = git(path, "-c", "gpg.ssh.allowedSignersFile=#{signers}", "log", "--format=%an|%GK")
    keys = out.lines.to_h { |line| line.strip.split("|", 2) }

    assert_equal [ "Claude (agent)" ], keys.keys.grep(/agent/)
    refute_equal keys["Claude (agent)"], keys.except("Claude (agent)").values.first
    list, = git(path, "log", "--author=agent", "--format=%s")
    assert_equal "agent", list.strip
  end

  def test_a_missing_agent_signing_key_fails_and_names_it
    path = repository
    FileUtils.rm(signing_key)
    FileUtils.chmod(0o600, "#{signing_key}.pub")
    stub_agent = File.join(@home, "no-agent.sock")
    _out, err, status = commit(path, "x", env: agent_env(claude_include, "SSH_AUTH_SOCK" => stub_agent))

    refute status.success?
    assert_includes err, "agent signing key missing: #{signing_key}"
  end

  def test_without_the_agent_include_the_commit_signs_through_op_ssh_sign
    config = File.join(CHECKOUT, "git/.config/git/config")
    env = plain_env("GIT_CONFIG_GLOBAL" => config)
    path = repository

    assert_equal "/Applications/1Password.app/Contents/MacOS/op-ssh-sign", config_value(path, "gpg.ssh.program", env: env)
    assert_equal "Etienne van Delden de la Haije", config_value(path, "user.name", env: env)
    assert_equal "", config_value(path, "author.name", env: env)
  end

  def test_an_interactive_shell_drops_a_leaked_agent_include
    out = zsh(claude_include, "-ic")

    assert_equal "[][][]", out
  end

  def test_a_non_interactive_shell_keeps_the_agent_include
    out = zsh(claude_include, "-c")

    assert_includes out, "agent/claude.config"
  end

  def test_an_unrelated_git_config_count_stays_in_an_interactive_shell
    pairs = { "GIT_CONFIG_COUNT" => "1", "GIT_CONFIG_KEY_0" => "core.pager", "GIT_CONFIG_VALUE_0" => "cat" }

    assert_equal "[1][core.pager][cat]", zsh(pairs, "-ic")
  end

  def test_the_signer_signs_with_the_key_and_no_ssh_agent
    data = File.join(@home, "data")
    File.write(data, "payload")
    _out, err, status = Open3.capture3(plain_env("SSH_AUTH_SOCK" => File.join(@home, "agent.sock")),
                                       File.join(AGENT_DIRECTORY, "ssh-sign"), "-Y", "sign", "-n", "git", "-f", signing_key, data)

    assert status.success?, err
    assert File.exist?("#{data}.sig")
  end

  def test_the_signer_names_a_missing_private_key
    FileUtils.rm(signing_key)
    _out, err, status = Open3.capture3(plain_env, File.join(AGENT_DIRECTORY, "ssh-sign"), "-Y", "sign", "-n", "git", "-f", signing_key, "data")

    refute status.success?
    assert_includes err, "agent signing key missing: #{signing_key}"
  end

  def test_the_signer_passes_verify_through
    out, _err, status = Open3.capture3(plain_env, File.join(AGENT_DIRECTORY, "ssh-sign"), "-Y", "find-principals", "-s", "none", "-f", File.join(@home, "none"))

    refute status.success?
    refute_includes out, "agent signing key missing"
  end

  def test_the_codex_include_gives_the_codex_author
    path = repository
    _out, err, status = commit(path, "x", env: agent_env(codex_include))

    assert status.success?, err
    assert_equal "Codex (agent)", git(path, "log", "-1", "--format=%an", env: agent_env(codex_include)).first.strip
  end

  def test_a_repository_without_a_personal_remote_keeps_etiennes_config
    [ nil, "git@github.com:someone/else.git", "https://gitlab.com/eirvandelden/x.git" ].each_with_index do |remote, index|
      path = repository(remote, name: "closed#{index}")

      assert_equal listing(path, plain_env), listing(path, agent_env), remote.inspect
    end
  end

  def test_both_tools_carry_only_the_agent_include
    [ claude_include, codex_include ].each do |pairs|
      assert_equal INCLUDE_KEYS.sort, pairs.keys.sort
      assert_equal "1", pairs["GIT_CONFIG_COUNT"]
      assert_equal "include.path", pairs["GIT_CONFIG_KEY_0"]
      assert_match(%r{\A~/Developer/dotfiles/git/\.config/git/agent/(claude|codex)\.config\z}, pairs["GIT_CONFIG_VALUE_0"])
    end
    env_keys = JSON.parse(File.read(SETTINGS)).fetch("env").keys

    assert_equal INCLUDE_KEYS.sort, env_keys.sort
  end

  def test_the_agent_signing_key_lies_outside_the_checkout
    setup = File.read(File.join(AGENT_DIRECTORY, "personal.config"))
    key = setup[/signingkey = (.*)$/, 1]

    assert_equal "~/.local/state/agent-git/signing_key", key
    refute File.expand_path(key, "/home").start_with?(CHECKOUT)
    refute File.expand_path(key).start_with?(CHECKOUT)
  end

  private

  def listing(path, env)
    out, = git(path, "config", "--list", env: env)
    out.lines.reject { |line| line.start_with?("include.path=", "includeif.") }
  end

  def zsh(pairs, mode)
    zdotdir = File.join(@home, "zdotdir")
    FileUtils.mkdir_p(zdotdir)
    File.symlink(File.join(CHECKOUT, "zsh/.config/zsh/.zshrc"), File.join(zdotdir, ".zshrc"))
    script = 'print -rn -- "[${GIT_CONFIG_COUNT-}][${GIT_CONFIG_KEY_0-}][${GIT_CONFIG_VALUE_0-}]"'
    env = agent_env(pairs, "ZDOTDIR" => zdotdir)
    out, = Open3.capture3(env, "/bin/zsh", mode, script)
    out[/\[[^\]]*\]\[[^\]]*\]\[[^\]]*\]\z/] || out
  end
end
