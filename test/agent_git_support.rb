require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# A temporary HOME with the dotfiles checkout linked at ~/Developer/dotfiles, an agent signing key
# made at run time, and PATH stubs. `agent_env` carries exactly what Claude's settings.json puts in the
# environment (or Codex's config.toml), so a test runs real git behind the agent include.
module AgentGitSupport
  CHECKOUT = File.expand_path("..", __dir__)
  AGENT_DIRECTORY = File.join(CHECKOUT, "git/.config/git/agent")
  SETTINGS = File.join(CHECKOUT, "claude/.claude/settings.json")
  CODEX_CONFIG = File.join(CHECKOUT, "codex/.codex/config.toml")
  INCLUDE_KEYS = %w[GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0].freeze
  UNSET = %w[GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME
             GIT_COMMITTER_EMAIL GIT_ASKPASS SSH_ASKPASS XDG_CONFIG_HOME].to_h { |name| [ name, nil ] }.freeze

  def setup_agent_home
    @home = File.realpath(Dir.mktmpdir("agent-home"))
    @bin = File.join(@home, "bin")
    FileUtils.mkdir_p([ @bin, File.join(@home, "Developer") ])
    File.symlink(CHECKOUT, File.join(@home, "Developer", "dotfiles"))
  end

  def teardown_agent_home
    FileUtils.remove_entry(@home)
  end

  # The agent include of one tool, as its configuration file sets it.
  def claude_include
    JSON.parse(File.read(SETTINGS)).fetch("env").slice(*INCLUDE_KEYS)
  end

  def codex_include
    section = File.read(CODEX_CONFIG)[/^\[shell_environment_policy\.set\]\n(.*?)(?=^\[|\z)/m, 1]
    section.scan(/^(GIT_CONFIG_\w+) = "(.*)"$/).to_h.slice(*INCLUDE_KEYS)
  end

  def agent_env(include_pairs = claude_include, extra = {})
    UNSET.merge("HOME" => @home, "PATH" => "#{@bin}:/usr/bin:/bin", "SSH_AUTH_SOCK" => nil)
         .merge(include_pairs).merge(extra)
  end

  def plain_env(extra = {})
    UNSET.merge("HOME" => @home, "PATH" => "#{@bin}:/usr/bin:/bin", "SSH_AUTH_SOCK" => nil)
         .merge(INCLUDE_KEYS.to_h { |name| [ name, nil ] }).merge(extra)
  end

  def signing_key
    File.join(@home, ".local/state/agent-git/signing_key")
  end

  def make_signing_key
    FileUtils.mkdir_p(File.dirname(signing_key))
    _out, err, status = Open3.capture3("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", signing_key)
    raise err unless status.success?

    FileUtils.chmod(0o600, signing_key)
  end

  def write_executable(path, body)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end

  def repository(remote = "git@github.com:eirvandelden/x.git", name: "repo")
    path = File.join(@home, name)
    FileUtils.mkdir_p(path)
    git(path, "init", "-q", "-b", "main", env: plain_env)
    git(path, "remote", "add", "origin", remote, env: plain_env) if remote
    path
  end

  def git(directory, *arguments, env: agent_env, stdin: nil)
    Open3.capture3(env, "git", "-C", directory, *arguments, stdin_data: stdin.to_s)
  end

  def commit(directory, message = "change", env: agent_env)
    File.write(File.join(directory, "file.txt"), "#{Time.now.to_f}\n")
    git(directory, "add", "file.txt", env: env)
    git(directory, "commit", "-q", "-m", message, env: env)
  end

  def config_value(directory, key, env: agent_env)
    out, = git(directory, "config", "--get", key, env: env)
    out.strip
  end
end
