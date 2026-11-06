#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# The Rex defaults install step sets the two Rex app defaults that make Rex match Ghostty. These tests
# run the real script against a scratch $HOME. Stubs for `uname`, `pgrep` and `defaults` come first on
# PATH, so the macOS branch runs on Linux CI and the real Rex domain is never touched. The `defaults`
# stub keeps its values in files and logs every write.
class RexDefaultsInstallTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(REPO_ROOT, "install/tasks/53_configure_rex_defaults.sh")

  def test_both_keys_are_written_when_rex_is_not_running
    run_step

    assert_equal("useTheme", stored("Workspace.interfaceStyle"))
    assert_equal("0", stored("Workspace.terminalImproveTextContrast"))
  end

  def test_a_second_run_writes_nothing
    run_step
    writes = write_log

    run_step

    assert_equal(writes, write_log)
  end

  def test_a_key_that_already_has_its_value_is_not_written_again
    store("Workspace.interfaceStyle", "useTheme")

    run_step

    assert_equal([ "write com.superlogical.rex Workspace.terminalImproveTextContrast -bool false" ], write_log)
  end

  def test_nothing_is_written_while_rex_runs
    _stdout, stderr, status = run_step(rex_running: true)

    assert_predicate(status, :success?)
    assert_match(/Rex is running/, stderr)
    assert_empty(write_log)
  end

  def test_the_step_skips_outside_macos
    run_step(os: "Linux")

    assert_empty(write_log)
  end

  def test_install_runs_the_task_after_the_glow_step
    lines = File.readlines(File.join(REPO_ROOT, "install.sh"))
    glow = lines.index { |line| line.include?(%(run_task "51_configure_glow_style.sh")) }
    rex = lines.index { |line| line.include?(%(run_task "53_configure_rex_defaults.sh")) }

    refute_nil(glow)
    refute_nil(rex)
    assert_operator(rex, :>, glow)
  end

  def test_the_step_is_executable
    assert_path_exists(SCRIPT)
    assert_predicate(File.stat(SCRIPT), :executable?)
  end

  def setup
    @tmp = Dir.mktmpdir
    FileUtils.mkdir_p([ bin_dir, state_dir, File.join(@tmp, "home") ])
  end

  def teardown
    FileUtils.rm_rf(@tmp)
  end

  private

  def bin_dir = File.join(@tmp, "bin")
  def state_dir = File.join(@tmp, "state")
  def log_path = File.join(@tmp, "writes.log")

  def stored(key) = File.read(File.join(state_dir, key))
  def store(key, value) = File.write(File.join(state_dir, key), value)
  def write_log = File.exist?(log_path) ? File.readlines(log_path, chomp: true) : []

  def stub(name, body)
    path = File.join(bin_dir, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    FileUtils.chmod(0o755, path)
  end

  # `defaults write DOMAIN KEY -bool false` keeps 0, as the real tool reads it back.
  def stub_defaults
    stub("defaults", <<~SH)
      if [ "$1" = read ]; then
        [ -f "#{state_dir}/$3" ] && cat "#{state_dir}/$3" && exit 0
        exit 1
      fi
      echo "$*" >> "#{log_path}"
      value="$5"
      [ "$4" = -bool ] && { [ "$5" = true ] && value=1 || value=0; }
      printf %s "$value" > "#{state_dir}/$3"
    SH
  end

  def run_step(os: "Darwin", rex_running: false)
    stub("uname", "echo #{os}")
    stub("pgrep", rex_running ? "exit 0" : "exit 1")
    stub_defaults

    Open3.capture3({ "HOME" => File.join(@tmp, "home"), "PATH" => "#{bin_dir}:#{ENV["PATH"]}" }, SCRIPT)
  end
end
