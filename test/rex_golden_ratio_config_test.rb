#!/usr/bin/env ruby
require "json"
require "minitest/autorun"
require "open3"
require_relative "isolated_git"

# rex/.config/rex/init.lua binds no golden-ratio chord, and the LaunchAgent plist keeps the
# watcher running. Both are read as files: Rex and launchd are not available here.
class RexGoldenRatioConfigTest < Minitest::Test
  REX_DIR = File.expand_path("../rex", __dir__)
  INIT = File.join(REX_DIR, ".config/rex/init.lua")
  PLIST = File.join(REX_DIR, "Library/LaunchAgents/com.eirvandelden.rex-golden-ratio.plist")
  LABEL = "com.eirvandelden.rex-golden-ratio".freeze

  def test_init_leaves_golden_ratio_to_the_watcher
    refute_match(/golden_ratio/, File.read(INIT))
  end

  def test_the_plist_passes_plutil_lint
    skip("plutil is not on PATH") unless system("command -v plutil >/dev/null 2>&1")
    assert(File.exist?(PLIST), "#{PLIST} is missing")

    output, status = Open3.capture2e("plutil", "-lint", PLIST)

    assert(status.success?, output)
  end

  def test_the_plist_names_the_label
    assert_equal(LABEL, plist.fetch("Label"))
  end

  def test_the_plist_runs_the_watcher_for_every_session_without_autostart
    command = plist.fetch("ProgramArguments").join(" ")

    assert_includes(command, "golden_ratio_watch.lua")
    assert_includes(command, "--all")
    assert_includes(command, "--autostart=false")
  end

  def test_the_plist_runs_the_watcher_at_load_and_keeps_it_alive
    assert_equal(true, plist.fetch("RunAtLoad"))
    assert(plist.fetch("KeepAlive"), "KeepAlive is not set")
  end

  private

  def plist
    skip("plutil is not on PATH") unless system("command -v plutil >/dev/null 2>&1")
    assert(File.exist?(PLIST), "#{PLIST} is missing")
    output, status = Open3.capture2e("plutil", "-convert", "json", "-o", "-", PLIST)
    assert(status.success?, output)
    JSON.parse(output)
  end
end
