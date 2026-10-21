#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "hook_scripts"

class HookScriptsTest < Minitest::Test
  def test_directory_is_not_the_tracked_directory
    refute_equal(File.realpath(HookScripts::TRACKED), File.realpath(HookScripts.directory))
  end

  def test_directory_has_the_tracked_names_bytes_and_executable_bits
    tracked = Dir.children(HookScripts::TRACKED).sort

    assert_equal(tracked, Dir.children(HookScripts.directory).sort)
    tracked.each { |name| assert_same_hook(name) }
  end

  def test_directory_is_a_read_only_copy_of_the_tracked_hooks
    hook = File.join(HookScripts.directory, Dir.children(HookScripts.directory).first)

    refute(File.writable?(HookScripts.directory), "the hooks copy directory is writable")
    refute(File.writable?(hook), "a hook in the hooks copy is writable")
  end

  def test_directory_returns_the_same_path_on_a_second_call
    assert_equal(HookScripts.directory, HookScripts.directory)
  end

  private

  def assert_same_hook(name)
    tracked = File.join(HookScripts::TRACKED, name)
    copy = File.join(HookScripts.directory, name)

    assert_equal(File.binread(tracked), File.binread(copy), "#{name} differs")
    assert_equal(File.executable?(tracked), File.executable?(copy), "#{name} executable bit differs")
  end
end
