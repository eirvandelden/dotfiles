#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# The state directories step creates the XDG state directories that ssh, irb and mysql write to, and
# copies the old history files in. These tests run the real script against a scratch $HOME.
class StateDirsInstallTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(REPO_ROOT, "install/tasks/54_prepare_state_dirs.sh")

  def test_the_three_directories_are_created_private
    run_step

    %w[ssh irb mysql].each do |name|
      path = state(name)
      assert_predicate(File.stat(path), :directory?)
      assert_equal(0o700, File.stat(path).mode & 0o777)
    end
  end

  def test_existing_histories_are_copied_and_the_originals_stay
    File.write(home(".irb_history"), "puts 1\n")
    File.write(home(".mysql_history"), "select 1;\n")

    run_step

    assert_equal("puts 1\n", File.read(state("irb/history")))
    assert_equal("select 1;\n", File.read(state("mysql/history")))
    assert_path_exists(home(".irb_history"))
    assert_path_exists(home(".mysql_history"))
  end

  def test_an_existing_target_is_not_overwritten
    FileUtils.mkdir_p(state("irb"))
    File.write(state("irb/history"), "kept\n")
    File.write(home(".irb_history"), "old\n")

    run_step

    assert_equal("kept\n", File.read(state("irb/history")))
  end

  def test_missing_histories_create_no_target_files
    run_step

    refute_path_exists(state("irb/history"))
    refute_path_exists(state("mysql/history"))
  end

  def test_a_second_run_succeeds
    File.write(home(".irb_history"), "puts 1\n")
    run_step

    _stdout, _stderr, status = run_step

    assert_predicate(status, :success?)
    assert_equal("puts 1\n", File.read(state("irb/history")))
  end

  def test_install_runs_the_task_after_the_rex_step
    lines = File.readlines(File.join(REPO_ROOT, "install.sh"))
    rex = lines.index { |line| line.include?(%(run_task "53_configure_rex_defaults.sh")) }
    state = lines.index { |line| line.include?(%(run_task "54_prepare_state_dirs.sh")) }

    refute_nil(rex)
    refute_nil(state)
    assert_operator(state, :>, rex)
  end

  def test_the_step_is_executable
    assert_path_exists(SCRIPT)
    assert_predicate(File.stat(SCRIPT), :executable?)
  end

  def setup
    @tmp = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@tmp, "home"))
  end

  def teardown
    FileUtils.rm_rf(@tmp)
  end

  private

  def home(name) = File.join(@tmp, "home", name)
  def state(name) = home(".local/state/#{name}")

  def run_step
    Open3.capture3({ "HOME" => File.join(@tmp, "home") }, SCRIPT)
  end
end
