#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "herdr_app_harness"
%w[command_line machine].each { |name| require File.join(HerdrAppHarness::PANE_LIBRARY, name) }

# HerdrAppPane::Machine: the own core's machine and the address rule. It sends no command.
class HerdrAppMachineTest < Minitest::Test
  include HerdrAppHarness::Fixtures

  def test_own_answers_the_machine_of_hc_session
    assert_equal("work", HerdrAppPane::Machine.own("HC_SESSION" => "work").name)
  end

  def test_own_answers_this_computer_when_hc_session_is_unset_empty_or_default
    [ {}, { "HC_SESSION" => "" }, { "HC_SESSION" => "default" } ].each do |env|
      assert_nil(HerdrAppPane::Machine.own(env).name, env.inspect)
    end
  end

  def test_name_is_nil_for_this_computer
    assert_nil(HerdrAppPane::Machine.new(nil).name)
  end

  def test_hc_address_strips_the_machine_prefix
    assert_equal("t25", HerdrAppPane::Machine.new("work").hc_address("work/t25"))
  end

  def test_hc_address_answers_a_bare_address_itself
    assert_equal("t25", HerdrAppPane::Machine.new(nil).hc_address("t25"))
  end

  def test_space_answers_the_work_space_for_the_work_core
    assert_equal("work/sp3", HerdrAppPane::Machine.new("work").space(spaces, "sp3")["id"])
  end

  def test_space_answers_the_bare_space_for_the_default_core
    assert_equal("sp2", HerdrAppPane::Machine.new(nil).space(spaces, "sp2")["id"])
  end

  def test_space_never_answers_a_space_of_another_machine
    assert_equal("work/sp2", HerdrAppPane::Machine.new("work").space(spaces, "sp2")["id"])
    assert_raises(HerdrAppPane::Refusal) { HerdrAppPane::Machine.new(nil).space(spaces, "sp3") }
  end

  def test_space_refuses_when_none_matches
    error = assert_raises(HerdrAppPane::Refusal) { HerdrAppPane::Machine.new("work").space(spaces, "sp9") }

    assert_match(/sp9/, error.message)
  end

  def test_space_refuses_an_hc_address_listed_twice_on_the_own_machine
    twice = spaces + [ space("sp2", tab("tb9")) ]

    error = assert_raises(HerdrAppPane::Refusal) { HerdrAppPane::Machine.new(nil).space(twice, "sp2") }

    assert_match(/sp2/, error.message)
  end

  private

  def spaces
    [ space("sp2", tab("tb2")), space("work/sp3", tab("work/tb3"), machine: "work"),
      space("work/sp2", tab("work/tb2"), machine: "work") ]
  end
end
