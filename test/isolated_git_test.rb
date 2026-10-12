#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

# Temporary-repository tests must not pick up the machine's global git setup (hooks, signing).
# Each test builds a hostile XDG_CONFIG_HOME, which is where Etienne's global git config lives.
class IsolatedGitTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @config_home = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@config_home)
  end

  def test_review_report_check_passes_under_the_global_no_push_to_main_hook
    write_hostile_config(hook: true)

    output, status = run_child(RbConfig.ruby, "-Itest", "test/review_report_check_test.rb")

    assert(status.success?, output)
  end

  private

  def write_hostile_config(hook: false, signing: false)
    config = []
    config << "[core]\n\thooksPath = #{write_hooks}\n" if hook
    config << signing_config if signing
    FileUtils.mkdir_p(File.join(@config_home, "git"))
    File.write(File.join(@config_home, "git", "config"), config.join)
  end

  def write_hooks
    hooks = File.join(@config_home, "hooks")
    FileUtils.mkdir_p(hooks)
    write_executable(File.join(hooks, "pre-commit"), <<~SH)
      #!/bin/sh
      branch=$(git rev-parse --abbrev-ref HEAD)
      case "$branch" in
        main | master) echo "global hook refused $branch" >&2; exit 1 ;;
      esac
    SH
    write_executable(File.join(hooks, "pre-push"), "#!/bin/sh\nexit 1\n")
    hooks
  end

  def signing_config
    program = File.join(@config_home, "failing-signer")
    write_executable(program, "#!/bin/sh\necho 'no signing agent' >&2\nexit 1\n")
    "[commit]\n\tgpgsign = true\n[gpg]\n\tformat = ssh\n\tprogram = #{program}\n" \
      "[gpg \"ssh\"]\n\tprogram = #{program}\n[user]\n\tsigningkey = ssh-ed25519 AAAAdummy\n"
  end

  def write_executable(path, body)
    File.write(path, body)
    File.chmod(0o755, path)
  end

  def run_child(*command)
    environment = { "XDG_CONFIG_HOME" => @config_home, "GIT_CONFIG_GLOBAL" => nil, "GIT_CONFIG_SYSTEM" => nil }
    output, status = Open3.capture2e(environment, *command, chdir: ROOT)
    [ output, status ]
  end
end
