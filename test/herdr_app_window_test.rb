#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "tmpdir"
require_relative "herdr_app_harness"
require_relative "isolated_git"
%w[command_line machine panes].each { |name| require File.join(HerdrAppHarness::PANE_LIBRARY, name) }

# HerdrAppPane::Window called directly, with a FakeCommandLine over a two-core World. The own terminal is t20 of
# the personal core (space sp2) or of the work core (space work/sp3); see herdr_app_harness.rb.
class HerdrAppWindowTest < Minitest::Test
  include HerdrAppHarness::Fixtures

  def setup
    @main = Dir.mktmpdir("main")
    @work = Dir.mktmpdir("work")
    @world = work_world(cwd: @main, work_cwd: @work)
  end

  def teardown
    FileUtils.rm_rf([ @main, @work ])
  end

  def test_space_of_answers_hc_terminal_addresses_and_herdr_app_pane_addresses_in_the_default_core
    rows = window("default").space_of("t20")

    assert_equal(%w[t20 t11], rows.map { |row| row["terminal"] })
    assert_equal(%w[p20 p11], rows.map { |row| row["pane"] })
  end

  def test_space_of_answers_hc_terminal_addresses_and_herdr_app_pane_addresses_in_the_work_core
    rows = window("work").space_of("t20")

    assert_equal(%w[t20 t11], rows.map { |row| row["terminal"] })
    assert_equal(%w[work/p20 work/p11], rows.map { |row| row["pane"] })
  end

  def test_split_answers_an_hc_terminal_address_in_the_default_core
    assert_equal({ "pane" => "p61", "terminal" => "t61" }, window("default").split("p20", "right", [ "zsh" ]))
  end

  def test_split_answers_an_hc_terminal_address_in_the_work_core
    assert_equal({ "pane" => "work/p61", "terminal" => "t61" }, window("work").split("work/p20", "right", [ "zsh" ]))
  end

  private

  def window(core)
    line = HerdrAppHarness::FakeCommandLine.new(@world, [], core: core)
    HerdrAppPane::Window.new(line, machine: HerdrAppPane::Machine.new(core == "default" ? nil : core))
  end
end
