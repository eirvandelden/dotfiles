#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "tmpdir"
require_relative "herdr_app_harness"
require_relative "isolated_git"
%w[command_line machine panes tabs].each { |name| require File.join(HerdrAppHarness::PANE_LIBRARY, name) }

# HerdrAppPane::Tabs and the Window calls it uses, with a FakeCommandLine over a two-core World. The own terminal
# is t20 of the personal core (space sp2) or of the work core (space work/sp3); see herdr_app_harness.rb.
class HerdrAppTabsTest < Minitest::Test
  include HerdrAppHarness::Fixtures

  def setup
    @main = Dir.mktmpdir("main")
    @work = Dir.mktmpdir("work")
    @world = work_world(cwd: @main, work_cwd: @work)
    @calls = []
  end

  def teardown
    FileUtils.rm_rf([ @main, @work ])
  end

  def test_open_sends_the_folder_name_and_command
    tabs("work").open(@work, name: "docs", command: %w[tail -f log])

    assert_equal({ "folder" => @work, "name" => "docs", "argv" => %w[tail -f log], "focus" => false,
                   "space" => "work/sp3" }, tab_requests.first)
  end

  def test_open_without_a_command_sends_no_argv
    tabs("work").open(@work)

    refute_includes(tab_requests.first, "argv")
    refute_includes(tab_requests.first, "name")
  end

  def test_open_sends_focus_false
    tabs("work").open(@work)

    assert_equal(false, tab_requests.first["focus"])
    assert_equal("p11", @world[HerdrAppHarness::FOCUS_KEY])
  end

  def test_open_sends_the_herdr_app_address_of_the_own_space
    tabs("work").open(@work)
    tabs("default").open(@main)

    assert_equal(%w[work/sp3 sp2], tab_requests.map { |request| request["space"] })
  end

  def test_open_answers_the_hc_address_of_the_new_terminal
    assert_equal("t61", tabs("work").open(@work))
    assert_equal("t62", tabs("default").open(@main))
  end

  def test_open_answers_nil_when_herdr_app_names_no_terminal
    window = HerdrAppPane::Window.new(Object.new.tap { |line| line.define_singleton_method(:json) { |*_| { "ok" => true } } },
                                      machine: HerdrAppPane::Machine.new(nil))
    window.define_singleton_method(:space_address) { |_terminal| "sp2" }

    assert_nil(HerdrAppPane::Tabs.new(own: "t20", window: window).open(@main))
  end

  def test_open_makes_three_calls_and_never_reads_focus
    tabs("work").open(@work)

    names = @calls.map { |call| call[1] == "do" ? call.first(3) : call.first(2) }

    assert_equal([ %w[hc get], %w[herdr-app ls], %w[herdr-app do tab.new] ], names)
  end

  def test_open_refuses_and_sends_no_tab_new_when_herdr_app_lists_no_own_space
    @world["spaces"].reject! { |space| space["id"] == "work/sp3" }

    assert_raises(HerdrAppPane::Refusal) { tabs("work").open(@work) }
    assert_empty(tab_requests)
  end

  def test_space_address_refuses_when_hc_gives_no_space_label
    @world["terminals"]["work/t20"] = [ { "address" => "t20", "labels" => {} } ]

    assert_raises(HerdrAppPane::Refusal) { window("work").space_address("t20") }
  end

  def test_the_new_tab_lands_in_the_own_space_while_the_other_core_has_focus
    tabs("work").open(@work)

    work = @world["spaces"].find { |space| space["id"] == "work/sp3" }
    assert_equal(2, work["tabs"].size)
    assert_equal(1, @world["spaces"].find { |space| space["id"] == "sp2" }["tabs"].size)
  end

  private

  def window(core)
    line = HerdrAppHarness::FakeCommandLine.new(@world, @calls, core: core)
    HerdrAppPane::Window.new(line, machine: HerdrAppPane::Machine.new(core == "default" ? nil : core))
  end

  def tabs(core)
    HerdrAppPane::Tabs.new(own: "t20", window: window(core))
  end

  def tab_requests
    @calls.select { |call| call.first(3) == %w[herdr-app do tab.new] }.map { |call| JSON.parse(call[3]) }
  end
end
