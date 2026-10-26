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

  SETTINGS_SCRIPT = <<~'RUBY'.freeze
    %w[maintenance.auto gc.auto].each do |key|
      puts IO.popen(["git", "config", "--show-scope", "--get", key], &:read).split.join("\t")
    end
  RUBY

  # Runs git the way a test does when it gives a child its own config: GIT_CONFIG_GLOBAL set on the git
  # process itself, after the helper loaded. user.name proves git reads that file at all.
  OWN_CONFIG_SCRIPT = <<~'RUBY'.freeze
    own = { "GIT_CONFIG_GLOBAL" => ARGV.fetch(0) }
    %w[user.name maintenance.auto gc.auto].each do |key|
      puts IO.popen(own, ["git", "config", "--show-scope", "--get", key], &:read).split.join("\t")
    end
  RUBY

  INIT_SCRIPT = <<~'RUBY'.freeze
    require "tmpdir"
    Dir.mktmpdir do |dir|
      { "work" => [], "bare" => [ "--bare" ] }.each do |label, flags|
        target = File.join(dir, label)
        system("git", "init", "--quiet", *flags, target, exception: true)
        git_dir = label == "bare" ? target : File.join(target, ".git")
        %w[info hooks].each { |name| puts "#{label} #{name} #{Dir.children(File.join(git_dir, name)).size}" }
      end
    end
  RUBY

  def setup
    @config_home = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@config_home)
  end

  def test_a_test_file_with_the_helper_commits_under_the_global_no_push_to_main_hook
    write_hostile_config(hook: true)
    fixture = write_fixture_test(with_helper: true)

    output, status = run_child(RbConfig.ruby, fixture)

    assert(status.success?, output)
  end

  def test_a_test_file_without_the_helper_fails_under_the_global_no_push_to_main_hook
    write_hostile_config(hook: true)
    fixture = write_fixture_test(with_helper: false)

    output, status = run_child(RbConfig.ruby, fixture)

    assert_match(/global hook refused main/, output)
    refute(status.success?)
  end

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

  def test_the_helper_turns_off_automatic_maintenance_and_gc
    output, status = run_child(RbConfig.ruby, "-Itest", "-risolated_git", "-e", SETTINGS_SCRIPT)

    assert(status.success?, output)
    assert_equal([ "command\tfalse", "command\t0" ], output.lines.map(&:chomp))
  end

  def test_the_quiet_settings_win_over_a_childs_own_global_config
    own_config = File.join(@config_home, "own-config")
    File.write(own_config, "[user]\n\tname = Own\n[maintenance]\n\tauto = true\n[gc]\n\tauto = 6700\n")

    output, status = run_child(RbConfig.ruby, "-Itest", "-risolated_git", "-e", OWN_CONFIG_SCRIPT, own_config)

    assert(status.success?, output)
    assert_equal([ "global\tOwn", "command\tfalse", "command\t0" ], output.lines.map(&:chomp))
  end

  def test_a_commit_under_the_helper_starts_no_maintenance
    trace = File.join(@config_home, "trace")

    output, status = run_child({ "GIT_TRACE" => trace }, RbConfig.ruby, "-Itest", "-risolated_git", "-e", COMMIT_SCRIPT)

    assert(status.success?, output)
    refute_match(/maintenance run/, File.read(trace))
  end

  def test_git_init_under_the_helper_copies_no_sample_hooks
    output, status = run_child(RbConfig.ruby, "-Itest", "-risolated_git", "-e", INIT_SCRIPT)

    assert(status.success?, output)
    assert_equal([ "work info 0", "work hooks 0", "bare info 0", "bare hooks 0" ], output.lines.map(&:chomp))
  end

  def test_the_helper_keeps_earlier_git_config_count_entries
    inherited = { "GIT_CONFIG_COUNT" => "1", "GIT_CONFIG_KEY_0" => "user.name", "GIT_CONFIG_VALUE_0" => "Inherited" }

    output, status = run_child(inherited, RbConfig.ruby, "-Itest", "-risolated_git", "-e",
                               "puts IO.popen(%w[git config --get user.name], &:read)")

    assert(status.success?, output)
    assert_equal("Inherited\n", output)
  end

  def test_the_quiet_settings_win_over_an_inherited_conflicting_entry
    inherited = { "GIT_CONFIG_COUNT" => "1", "GIT_CONFIG_KEY_0" => "maintenance.auto", "GIT_CONFIG_VALUE_0" => "true" }

    output, status = run_child(inherited, RbConfig.ruby, "-Itest", "-risolated_git", "-e",
                               "puts IO.popen(%w[git config --get maintenance.auto], &:read)")

    assert(status.success?, output)
    assert_equal("false\n", output)
  end

  def test_the_helper_loads_on_its_own
    directory = File.join(@config_home, "alone")
    FileUtils.mkdir_p(directory)
    FileUtils.cp(File.join(ROOT, "test", "isolated_git.rb"), directory)

    output, status = run_child(RbConfig.ruby, "-r./isolated_git", "-e", "puts ENV.fetch('GIT_TEMPLATE_DIR')",
                               chdir: directory)

    assert(status.success?, output)
    refute(File.exist?(output.chomp), "the template directory outlives its process")
  end

  def test_every_test_file_requires_the_helper
    missing = Dir.glob(File.join(ROOT, "test", "*_test.rb")).reject do |file|
      File.read(file).match?(/^require_relative "isolated_git"$/)
    end

    assert_empty(missing.map { |file| File.basename(file) }, "these files must require isolated_git")
  end

  private

  # A minimal Minitest file whose one test commits twice on main, with or without the helper line
  # every real test file has. The real helper is copied beside it so that line loads it.
  def write_fixture_test(with_helper:)
    directory = File.join(@config_home, "fixture-#{with_helper ? 'with' : 'without'}")
    FileUtils.mkdir_p(directory)
    FileUtils.cp(File.join(ROOT, "test", "isolated_git.rb"), directory)
    File.write(File.join(directory, "commit_test.rb"), <<~RUBY)
      require "minitest/autorun"
      #{'require_relative "isolated_git"' if with_helper}
      class CommitTest < Minitest::Test
        def test_commits_twice_on_main
          #{COMMIT_SCRIPT.lines.map(&:chomp).join("\n      ")}
        end
      end
    RUBY
    File.join(directory, "commit_test.rb")
  end

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

  def run_child(*command, chdir: ROOT)
    # HOME points at the temporary directory too, so a real ~/.gitconfig cannot override the hostile one.
    environment = { "HOME" => @config_home, "XDG_CONFIG_HOME" => @config_home,
                    "GIT_CONFIG_GLOBAL" => nil, "GIT_CONFIG_SYSTEM" => nil,
                    "GIT_CONFIG_COUNT" => nil, "GIT_TEMPLATE_DIR" => nil }
    overrides, *arguments = command.first.is_a?(Hash) ? command : [ {}, *command ]
    Open3.capture2e(environment.merge(overrides), *arguments, chdir: chdir)
  end
end
