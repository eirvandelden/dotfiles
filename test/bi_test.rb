#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "timeout"
require "tmpdir"

# `bi` installs gems with rv. Bundler only resolves the lockfile; rv does every install.
# Each test builds a project in a temporary directory, with a HOME there and a PATH of
# stubs plus /usr/bin:/bin. The stubs log their argv to one file.
class BiTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  BI = File.join(REPO_ROOT, "ruby/.local/bin/bi")
  ALIASES = File.join(REPO_ROOT, "zsh/.config/zsh/aliases.zsh")
  BUNDLER_BIN = Gem.bin_path("bundler", "bundle")

  def setup
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "stubs")
    @log_file = File.join(@tmpdir, "commands.log")
    @project = File.join(@tmpdir, "project")
    FileUtils.mkdir_p([ @bin_dir, @project ])
    stub_rv
    stub_solargraph
    stub_bundle_logging
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_up_to_date_lockfile_installs_with_rv_ci_and_never_bundle_install
    use_real_bundler
    write_path_gem_gemfile("alpha")
    lock_with_bundler
    locked = File.binread(File.join(@project, "Gemfile.lock"))
    FileUtils.rm_f(@log_file)

    result = run_bi

    assert_success(result)
    assert_includes(command_lines, "rv ci")
    refute_includes(command_lines, "bundle install")
    assert_equal(locked, File.binread(File.join(@project, "Gemfile.lock")), "bi rewrote an up-to-date lockfile")
  end

  def test_missing_lockfile_is_written_by_bundler_before_rv_ci
    use_real_bundler
    write_path_gem_gemfile("alpha")

    result = run_bi

    assert_success(result)
    assert_match(/alpha/, File.read(File.join(@project, "Gemfile.lock")))
    assert_runs_in_order("bundle lock", "rv ci")
    refute_includes(command_lines, "bundle install")
  end

  def test_gem_added_to_gemfile_is_locked_then_installed_with_rv_ci
    use_real_bundler
    write_path_gem_gemfile("alpha")
    lock_with_bundler
    write_path_gem_gemfile("alpha", "beta")
    FileUtils.rm_f(@log_file)

    result = run_bi

    assert_success(result)
    assert_match(/beta/, File.read(File.join(@project, "Gemfile.lock")))
    assert_runs_in_order("bundle lock", "rv ci")
    refute_includes(command_lines, "bundle install")
  end

  def test_failing_rv_ci_warns_and_falls_back_to_bundle_install
    write_plain_project

    result = run_bi(env: { "RV_FAIL" => "1" })

    assert_success(result)
    assert_match(/rv ci failed, installing with bundle install instead/, result[:stderr])
    assert_runs_in_order("rv ci", "bundle install")
  end

  def test_failing_fallback_exits_non_zero
    write_plain_project

    result = run_bi(env: { "RV_FAIL" => "1", "BUNDLE_INSTALL_FAIL" => "1" })

    refute_predicate(result[:status], :success?, "bi hid a failing bundle install")
  end

  def test_missing_rv_stops_with_an_error_and_installs_nothing
    write_plain_project
    FileUtils.rm(File.join(@bin_dir, "rv"))

    result = run_bi

    assert_equal(1, result[:status].exitstatus, result[:stderr])
    assert_match(/rv is missing/, result[:stderr])
    refute_match(/rv ci|bundle install/, command_log)
  end

  def test_missing_rv_is_reported_before_bundler_runs
    write_plain_project
    FileUtils.rm(File.join(@bin_dir, "rv"))

    run_bi

    assert_equal("", command_log, "bi ran a command before it noticed rv is missing")
  end

  def test_directory_without_gemfile_has_nothing_to_install
    result = run_bi

    assert_success(result)
    assert_match(/no Gemfile in .*nothing to install/, result[:stdout] + result[:stderr])
    assert_equal("", command_log)
  end

  def test_subdirectory_installs_for_the_project_above_it
    write_rails_project
    subdirectory = File.join(@project, "app", "models")
    FileUtils.mkdir_p(subdirectory)

    result = run_bi(chdir: subdirectory)

    assert_success(result)
    assert_runs_in_order("bundle lock", "rv ci", "bin/rails app:update:bin")
    refute_includes(command_lines, "bundle install")
  end

  def test_git_repository_without_gemfile_stops_at_its_root
    write_rails_project
    repository = File.join(@project, ".worktrees", "no-gemfile")
    FileUtils.mkdir_p(repository)
    system("git", "init", "--quiet", repository, exception: true)

    result = run_bi(chdir: repository)

    assert_success(result)
    assert_match(/no Gemfile in .*nothing to install/, result[:stdout] + result[:stderr])
    assert_equal("", command_log)
  end

  def test_bundle_gemfile_names_the_gemfile_to_look_for
    File.write(File.join(@project, "other.gemfile"), "")
    File.write(File.join(@project, "other.gemfile.lock"), "")

    named = run_bi(env: { "BUNDLE_GEMFILE" => "other.gemfile" })

    assert_success(named)
    assert_includes(command_lines, "rv ci")

    FileUtils.rm_f(@log_file)
    write_plain_project
    missing = run_bi(env: { "BUNDLE_GEMFILE" => "absent.gemfile" })

    assert_success(missing)
    assert_match(/nothing to install/, missing[:stdout] + missing[:stderr])
    assert_equal("", command_log)
  end

  def test_rails_app_regenerates_binstubs_and_runs_solargraph_after_install
    write_rails_project

    result = run_bi

    assert_success(result)
    assert_runs_in_order("rv ci", "bin/rails app:update:bin", "solargraph gems")
  end

  def test_rails_app_runs_solargraph_gems
    write_rails_project

    run_bi

    assert_includes(command_lines, "solargraph gems")
    refute_includes(command_lines, "solargraph")
  end

  def test_plain_gem_only_installs
    write_plain_project

    result = run_bi

    assert_success(result)
    assert_includes(command_lines, "rv ci")
    refute_match(/bin\/rails|solargraph/, command_log)
  end

  def test_customised_binstub_is_kept_without_a_prompt
    write_rails_project
    bin_dev = File.join(@project, "bin/dev")
    File.write(bin_dev, "customised\n")

    result = run_bi

    assert_success(result)
    assert_equal("customised\n", File.read(bin_dev))
    assert_includes(command_lines, "rails answered n")
  end

  def test_missing_solargraph_is_skipped_with_a_note
    write_rails_project
    FileUtils.rm(File.join(@bin_dir, "solargraph"))

    result = run_bi

    assert_success(result)
    assert_match(/solargraph not found, skipping/, result[:stdout] + result[:stderr])
  end

  def test_bi_runs_by_name_from_non_interactive_bash_and_zsh
    write_plain_project
    path = "#{File.dirname(BI)}:#{@bin_dir}:/usr/bin:/bin"

    { "bash" => [ "bash", "-c", "bi" ], "zsh" => [ "zsh", "-f", "-c", "bi" ] }.each do |shell, command|
      FileUtils.rm_f(@log_file)
      stdout, stderr, status = Open3.capture3(base_env.merge("PATH" => path), *command, chdir: @project)

      assert_predicate(status, :success?, "#{shell} could not run bi\n#{stdout}\n#{stderr}")
      assert_includes(command_lines, "rv ci", shell)
    end
  end

  def test_aliases_no_longer_define_a_bi_function
    stdout, = Open3.capture3(base_env, "zsh", "-f", "-c", "source '#{ALIASES}'; whence -w bi", chdir: @project)

    refute_match(/function/, stdout)
  end

  private

  def run_bi(env: {}, chdir: @project)
    flunk("ruby/.local/bin/bi is missing or not executable") unless File.executable?(BI)

    stdout, stderr, status = Timeout.timeout(60) do
      Open3.capture3(base_env.merge(env), BI, chdir:, stdin_data: "")
    end
    { stdout:, stderr:, status: }
  end

  def assert_success(result)
    assert_predicate(result[:status], :success?, "bi failed\nstdout:\n#{result[:stdout]}\nstderr:\n#{result[:stderr]}")
  end

  def assert_runs_in_order(*commands)
    positions = commands.map { |command| command_lines.index { |line| line.start_with?(command) } }

    assert_equal(commands.length, positions.compact.length, "missing a command in:\n#{command_log}")
    assert_equal(positions.sort, positions, "commands ran out of order:\n#{command_log}")
  end

  def base_env
    {
      "HOME" => @tmpdir,
      "PATH" => "#{@bin_dir}:/usr/bin:/bin",
      "BUNDLE_GEMFILE" => nil,
      "RUBYOPT" => nil,
      "BUNDLE_BIN_PATH" => nil
    }
  end

  def command_log
    File.exist?(@log_file) ? File.read(@log_file) : ""
  end

  def command_lines
    command_log.lines.map(&:chomp)
  end

  def write_plain_project
    File.write(File.join(@project, "Gemfile"), "source \"https://rubygems.org\"\n")
    File.write(File.join(@project, "Gemfile.lock"), "")
  end

  def write_rails_project
    write_plain_project
    FileUtils.mkdir_p(File.join(@project, "bin"))
    write_stub(File.join(@project, "bin/rails"), <<~SH)
      #!/bin/sh
      echo "bin/rails $*" >> "#{@log_file}"
      # Thor asks once per differing file and treats end of input as "overwrite".
      if read answer; then :; else answer=Y; fi
      case "$answer" in
        n) echo "rails answered n" >> "#{@log_file}" ;;
        *) echo "rails answered $answer" >> "#{@log_file}"; echo overwritten > bin/dev ;;
      esac
    SH
  end

  def write_path_gem_gemfile(*names)
    names.each do |name|
      dir = File.join(@project, "vendor", name)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "#{name}.gemspec"), <<~RUBY)
        Gem::Specification.new do |spec|
          spec.name = "#{name}"
          spec.version = "0.1.0"
          spec.summary = "#{name}"
          spec.authors = [ "test" ]
        end
      RUBY
    end
    File.write(File.join(@project, "Gemfile"), names.map { |name| "gem \"#{name}\", path: \"vendor/#{name}\"\n" }.join)
  end

  def lock_with_bundler
    stdout, stderr, status = Open3.capture3(base_env, File.join(@bin_dir, "bundle"), "lock", chdir: @project)

    assert_predicate(status, :success?, "test setup could not lock the Gemfile\n#{stdout}\n#{stderr}")
  end

  def stub_rv
    write_stub(File.join(@bin_dir, "rv"), <<~SH)
      #!/bin/sh
      echo "rv $*" >> "#{@log_file}"
      [ -n "${RV_FAIL:-}" ] && exit 1
      if [ "$1" = "ci" ] && [ ! -f "Gemfile.lock" ]; then
        echo "MissingImplicitLockfile" >&2
        exit 1
      fi
      exit 0
    SH
  end

  def stub_solargraph
    write_stub(File.join(@bin_dir, "solargraph"), "#!/bin/sh\necho \"solargraph $*\" >> \"#{@log_file}\"\n")
  end

  def stub_bundle_logging
    write_stub(File.join(@bin_dir, "bundle"), <<~SH)
      #!/bin/sh
      echo "bundle $*" >> "#{@log_file}"
      [ "$1" = "install" ] && [ -n "${BUNDLE_INSTALL_FAIL:-}" ] && exit 1
      exit 0
    SH
  end

  # The real Bundler, started through the Ruby running this test, so the restricted PATH needs no Ruby.
  def use_real_bundler
    write_stub(File.join(@bin_dir, "bundle"), <<~SH)
      #!/bin/sh
      echo "bundle $*" >> "#{@log_file}"
      exec "#{RbConfig.ruby}" "#{BUNDLER_BIN}" "$@"
    SH
  end

  def write_stub(path, body)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end
end
