#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# The glow install step points `style:` in glow's live config at the stowed Solunized style. Glow
# 3.0.0 only resolves a style from every directory through an absolute path, so the step writes the
# real $HOME into the file. These tests run the real script against a scratch $HOME, with a `uname`
# stub first on PATH so the macOS branch runs on Linux CI and the skip branch runs on a Mac.
class GlowStyleInstallTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(REPO_ROOT, "install/tasks/51_configure_glow_style.sh")

  def test_an_existing_style_line_points_at_the_stowed_solunized_style
    write_config(%(style: "auto"\nwidth: 80\n))

    run_step

    assert_equal(%(style: "#{style_path}"\nwidth: 80\n), config)
  end

  def test_a_config_without_a_style_line_gets_one_and_keeps_its_other_lines
    write_config(%(# style name or JSON path (default "auto")\nwidth: 80\n))

    run_step

    assert_equal(%(# style name or JSON path (default "auto")\nwidth: 80\nstyle: "#{style_path}"\n), config)
  end

  def test_a_missing_config_is_created_with_only_the_style_line
    run_step

    assert_equal(%(style: "#{style_path}"\n), config)
  end

  def test_a_second_run_leaves_the_config_unchanged
    write_config(%(style: "auto"\nwidth: 80\n))

    run_step
    first = config
    run_step

    assert_equal(first, config)
  end

  def test_the_step_leaves_the_config_alone_outside_macos
    write_config(%(style: "auto"\n))

    run_step(os: "Linux")

    assert_equal(%(style: "auto"\n), config)
  end

  def test_the_step_creates_no_config_outside_macos
    run_step(os: "Linux")

    refute_path_exists(config_path)
  end

  def test_a_missing_stowed_style_leaves_the_config_alone
    FileUtils.rm(File.join(glow_dir, "solunized.json"))
    write_config(%(style: "auto"\n))

    _stdout, stderr, status = run_step

    assert_predicate(status, :success?)
    assert_match(/solunized\.json/, stderr)
    assert_equal(%(style: "auto"\n), config)
  end

  def test_install_sh_runs_the_glow_step_after_stowing
    lines = File.readlines(File.join(REPO_ROOT, "install.sh"))
    stow = lines.index { |line| line.include?(%(run_task "50_stow_all.sh")) }
    glow = lines.index { |line| line.include?(%(run_task "51_configure_glow_style.sh")) }

    refute_nil(glow)
    assert_operator(glow, :>, stow)
  end

  def test_the_step_is_executable
    assert_path_exists(SCRIPT)
    assert_predicate(File.stat(SCRIPT), :executable?)
  end

  def setup
    @tmp = Dir.mktmpdir
    FileUtils.mkdir_p([ glow_dir, bin_dir ])
    FileUtils.touch(File.join(glow_dir, "solunized.json"))
  end

  def teardown
    FileUtils.rm_rf(@tmp)
  end

  private

  def home = File.join(@tmp, "home")
  def bin_dir = File.join(@tmp, "bin")
  def glow_dir = File.join(home, "Library/Preferences/glow")
  def config_path = File.join(glow_dir, "glow.yml")
  def style_path = File.join(glow_dir, "solunized.json")
  def config = File.read(config_path)

  def write_config(content)
    File.write(config_path, content)
  end

  def run_step(os: "Darwin")
    stub = File.join(bin_dir, "uname")
    File.write(stub, "#!/bin/sh\necho #{os}\n")
    FileUtils.chmod(0o755, stub)

    Open3.capture3({ "HOME" => home, "PATH" => "#{bin_dir}:#{ENV["PATH"]}" }, SCRIPT)
  end
end
