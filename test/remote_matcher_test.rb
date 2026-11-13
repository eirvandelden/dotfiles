#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../claude/.claude/hooks/remote_matcher"
require_relative "isolated_git"

# RemoteMatcher decides which origins are personal. Both personal owners match over
# ssh and https; an owner that only shares a prefix does not.
class RemoteMatcherTest < Minitest::Test
  def setup
    @home = Dir.mktmpdir
    @original_home = ENV.fetch("HOME")
    ENV["HOME"] = @home
  end

  def teardown
    ENV["HOME"] = @original_home
    FileUtils.rm_rf(@home)
  end

  def test_personal_accepts_both_owners_over_ssh_and_https
    %w[eirvandelden eirvandelden-dev].each do |owner|
      assert(RemoteMatcher.personal?("git@github.com:#{owner}/clocky.git"), owner)
      assert(RemoteMatcher.personal?("https://github.com/#{owner}/clocky.git"), owner)
    end
  end

  def test_an_owner_that_only_shares_the_prefix_is_not_personal
    %w[eirvandelden-devtools eirvandeldenx].each do |owner|
      refute(RemoteMatcher.personal?("https://github.com/#{owner}/x"), owner)
      refute(RemoteMatcher.personal?("git@github.com:#{owner}/x.git"), owner)
    end
  end

  def test_a_foreign_owner_is_not_personal
    refute(RemoteMatcher.personal?("git@github.com:someone-else/clocky.git"))
  end

  def test_allowed_remotes_holds_a_pattern_per_personal_owner_plus_the_listed_remotes
    FileUtils.mkdir_p(File.join(@home, ".claude"))
    File.write(File.join(@home, ".claude", "consent-guard-allowed-remotes.txt"), "acme/\n")

    patterns = RemoteMatcher.allowed_remotes

    assert_equal(RemoteMatcher::PERSONAL_OWNERS.size + 1, patterns.size)
    assert(patterns.any? { |pattern| "github.com/acme/x".match?(pattern) })
  end
end
