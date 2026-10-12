#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "isolated_git"

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

  COMMIT_SCRIPT = <<~'RUBY'.freeze
    require "tmpdir"
    Dir.mktmpdir do |dir|
      identity = ["-c", "user.name=Test", "-c", "user.email=test@example.com"]
      system("git", "init", "--quiet", "--initial-branch=main", dir, exception: true)
      2.times do |index|
        system("git", "-C", dir, *identity, "commit", "--quiet", "--allow-empty", "-m", "commit #{index}",
               exception: true)
      end
    end
  RUBY

  def test_a_commit_ignores_the_global_no_push_to_main_hook
    write_hostile_config(hook: true)

    output, status = run_commit_script("-Itest", "-risolated_git")

    assert(status.success?, output)
  end

  def test_a_commit_ignores_global_signing_with_no_agent
    write_hostile_config(signing: true)

    output, status = run_commit_script("-Itest", "-risolated_git")

    assert(status.success?, output)
  end

  def test_without_the_helper_the_global_hook_blocks_the_second_commit_on_main
    write_hostile_config(hook: true)

    output, status = run_commit_script

    assert_match(/global hook refused main/, output)
    refute(status.success?)
  end

  def test_without_the_helper_global_signing_blocks_the_commit
    write_hostile_config(signing: true)

    output, status = run_commit_script

    assert_match(/no signing agent/, output)
    refute(status.success?)
  end

  def test_the_helper_empties_the_global_and_system_config
    output, status = run_child(RbConfig.ruby, "-Itest", "-risolated_git", "-e",
                               'puts ENV.values_at("GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM")')

    assert(status.success?, output)
    assert_equal([ "/dev/null", "/dev/null" ], output.lines.map(&:chomp))
  end

  def test_every_test_file_requires_the_helper
    missing = Dir.glob(File.join(ROOT, "test", "*_test.rb")).reject do |file|
      File.read(file).include?('require_relative "isolated_git"')
    end

    assert_empty(missing.map { |file| File.basename(file) }, "these files must require isolated_git")
  end

  private

  def run_commit_script(*flags)
    run_child(RbConfig.ruby, *flags, "-e", COMMIT_SCRIPT)
  end

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
