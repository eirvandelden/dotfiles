#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "delivery_harness"
require_relative "isolated_git"

# The `gh` and `herdr` stubs are called many times per delivery test, so their start-up cost counts.
class DeliveryHarnessTest < Minitest::Test
  include DeliveryHarness

  def setup
    setup_harness
    @probe = File.join(@state, "probe.rb")
    @answer = File.join(@state, "gem-defined")
    File.write(@probe, "at_exit { File.write(ENV.fetch('PROBE_OUT'), defined?(::Gem).inspect) }\n")
  end

  def teardown
    teardown_harness
  end

  def test_a_stub_call_starts_without_rubygems
    %w[gh herdr].each do |name|
      File.delete(@answer) if File.exist?(@answer)

      _, error, = call_stub(name)

      assert_path_exists(@answer, error)
      assert_equal("nil", File.read(@answer), "#{name} stub loaded RubyGems")
    end
  end

  def test_build_repo_gives_each_test_its_own_repository_and_origin
    build_repo
    first_repo = @repo
    commit_file("extra.txt", "x", "extra")
    git("push", "--quiet", "origin", "HEAD:refs/heads/pushed")
    assert_includes(origin_branches, "pushed")
    teardown_harness

    setup_harness
    build_repo

    refute_equal(first_repo, @repo)
    refute_path_exists(File.join(@repo, "extra.txt"))
    refute_includes(origin_branches, "pushed")
    assert_equal(@branch, git("branch", "--show-current").strip)
  end

  def test_build_repo_with_another_branch_builds_another_fixture
    build_repo(branch: "other-change")

    assert_equal("other-change", git("branch", "--show-current").strip)
    assert_equal([ "main" ], origin_branches)
  end

  private

  def call_stub(name)
    environment = { "STUB_STATE" => @state, "PROBE_OUT" => @answer, "RUBYOPT" => "-r#{@probe}" }
    Open3.capture3(environment, File.join(@stub_bin, name), "pr", "list")
  end
end
