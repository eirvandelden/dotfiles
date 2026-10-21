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

  private

  def call_stub(name)
    environment = { "STUB_STATE" => @state, "PROBE_OUT" => @answer, "RUBYOPT" => "-r#{@probe}" }
    Open3.capture3(environment, File.join(@stub_bin, name), "pr", "list")
  end
end
