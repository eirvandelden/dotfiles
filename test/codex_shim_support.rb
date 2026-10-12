require "fileutils"
require "open3"
require "tmpdir"

# Shared fixtures for the unlock/codex-shim tests: both 1Password mapping files,
# a stub `op`, and a fake "real" codex that logs what it was called with. The
# real Codex never runs in a test.
module CodexShimSupport
  ZSH_DIR = File.expand_path("../zsh/.config/zsh", __dir__)
  LOADER = File.join(ZSH_DIR, "functions/secrets.zsh")
  SHIM_DIR = File.join(ZSH_DIR, "unlocked-bin")
  SHIM = File.join(SHIM_DIR, "codex")
  MAPPED = %w[FIZZY_PAT NODE_AUTH_TOKEN MCP_EMAIL_SERVER_AUTH_TOKEN].freeze

  def setup_codex_fixtures
    @tmpdir = Dir.mktmpdir
    @config = File.join(@tmpdir, "config", "secrets")
    @bin = File.join(@tmpdir, "bin")
    @fake_bin = File.join(@tmpdir, "fake-bin")
    @codex_log = File.join(@tmpdir, "codex.log")
    [ @config, @bin, @fake_bin ].each { |dir| FileUtils.mkdir_p(dir) }
    write_mapping_files
    write_executable(File.join(@bin, "op"), "#!/bin/sh\necho a-secret-value\n")
    write_executable(File.join(@fake_bin, "codex"), fake_codex)
  end

  def teardown_codex_fixtures
    FileUtils.remove_entry(@tmpdir)
  end

  # Runs a zsh snippet with unlock available, never reading a user startup file.
  def run_zsh(script, env = {})
    Open3.capture3(shell_env.merge(env), "zsh", "-f", "-c", "source #{LOADER}\n#{script}")
  end

  def shell_env
    {
      "XDG_CONFIG_HOME" => File.join(@tmpdir, "config"),
      "ZDOTDIR" => ZSH_DIR,
      "SECRETS_WORK_OP_ACCOUNT" => "employer",
      "FAKE_CODEX_LOG" => @codex_log,
      "PATH" => "#{@fake_bin}:#{@bin}:/usr/bin:/bin"
    }
  end

  # One hash per fake-codex call:
  # { args: [...], env: { "NAME" => "set"/"unset" }, path: [...] }.
  def codex_calls
    return [] unless File.exist?(@codex_log)

    File.read(@codex_log).split("CALL\n").reject(&:empty?).map { |call| parse_call(call) }
  end

  def single_call
    assert_equal 1, codex_calls.length, "expected exactly one call to the real codex"
    codex_calls.first
  end

  private

  def parse_call(call)
    lines = call.lines(chomp: true)
    args = lines.filter_map { |line| line.delete_prefix("ARG=") if line.start_with?("ARG=") }
    env = lines.grep(/\A[A-Z_]+=(set|unset)\z/).to_h { |line| line.split("=", 2) }
    path = lines.find { |line| line.start_with?("PATH=") }.to_s.delete_prefix("PATH=").split(":")
    { args: args, env: env, path: path }
  end

  def write_mapping_files
    File.write(File.join(@config, "1password.env"), <<~ENV)
      # personal
      FIZZY_PAT=op://Test/fizzy/credential

      NODE_AUTH_TOKEN=op://Test/node/credential
    ENV
    File.write(File.join(@config, "1password.work.env"), "MCP_EMAIL_SERVER_AUTH_TOKEN=op://Test/email/credential\n")
  end

  def write_executable(path, body)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end

  def fake_codex
    <<~SH
      #!/bin/sh
      {
        echo CALL
        for arg in "$@"; do echo "ARG=$arg"; done
        echo "PATH=$PATH"
        for name in #{MAPPED.join(' ')} UNMAPPED_VAR UNLOCKED_BIN; do
          eval "value=\\${$name+set}"
          echo "$name=${value:-unset}"
        done
      } >> "$FAKE_CODEX_LOG"
      exit "${FAKE_CODEX_STATUS:-0}"
    SH
  end
end
