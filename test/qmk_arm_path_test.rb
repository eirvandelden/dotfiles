#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Proves paths.zsh puts QMK's keg-only ARM compiler on PATH, but only when its
# Homebrew directories exist.
class QmkArmPathTest < Minitest::Test
  KEGS = %w[arm-none-eabi-gcc@8 arm-none-eabi-binutils].freeze

  def setup
    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @home = FileUtils.mkdir_p(File.join(@tmpdir, "home")).first
    @brew = FileUtils.mkdir_p(File.join(@tmpdir, "homebrew")).first
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_both_arm_keg_bins_are_on_path_when_present
    KEGS.each { |keg| FileUtils.mkdir_p(File.join(@brew, "opt", keg, "bin")) }

    assert_equal(KEGS.map { |keg| File.join(@brew, "opt", keg, "bin") }.sort, arm_entries.sort)
  end

  def test_no_arm_keg_bin_is_on_path_when_absent
    assert_empty(arm_entries)
  end

  private

  def arm_entries
    stdout, stderr, = Open3.capture3(shell_env, "zsh", "-f", "-c", shell_script, unsetenv_others: true)

    assert_equal("", stderr)
    stdout.lines.map(&:strip).grep(/arm-none-eabi/)
  end

  def shell_script
    <<~SH
      typeset -gU path
      source "#{File.join(@repo_root, "zsh/.config/zsh/paths.zsh")}"
      print -rl -- $path
    SH
  end

  def shell_env
    { "HOME" => @home, "HOMEBREW_PREFIX" => @brew, "PATH" => "/usr/bin:/bin", "TERM" => "dumb" }
  end
end
