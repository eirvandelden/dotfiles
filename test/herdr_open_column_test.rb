#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "delivery_harness"
require_relative "isolated_git"

# open-column.sh <cwd> [--row <slug>] [--new-row | --unlisted] opens the next column of a change's
# row of herdr panes and prints its pane id. The row record is <git-common-dir>/herdr/stage-panes-<slug>,
# one "<pane id> <terminal id>" line per listed column. herdr is a stub; see delivery_harness.rb for
# its response format.
class HerdrOpenColumnTest < Minitest::Test
  include DeliveryHarness

  OPEN_COLUMN = File.join(HERDR_SCRIPTS, "open-column.sh")
  SLUG = "my-change".freeze
  NEW_PANE = "w1:pN".freeze

  def setup
    setup_harness
    build_repo(branch: "my-change")
    stub_response("herdr pane get w1:pN", pane_answer(NEW_PANE, "term_N"))
    stub_response("herdr pane split", pane_answer(NEW_PANE, "term_N"))
  end

  def teardown
    teardown_harness
  end

  def test_refuses_bad_arguments_before_any_herdr_call
    [ [],
      [ toplevel, "--bogus" ],
      [ toplevel, "--new-row" ],
      [ toplevel, "--unlisted" ],
      [ toplevel, "--row", SLUG, "--new-row", "--unlisted" ],
      [ toplevel, "--row" ] ].each do |arguments|
      _, stderr, status = open_column(*arguments)

      assert_equal(1, status.exitstatus, arguments.inspect)
      refute_empty(stderr, arguments.inspect)
      assert_empty(herdr_calls, arguments.inspect)
    end
  end

  def test_exits_1_when_the_caller_split_fails
    stub_response("herdr pane split --current", { "exit" => 1, "stderr" => "no pane\n" })

    stdout, _, status = open_column(toplevel, "--row", SLUG)

    assert_equal(1, status.exitstatus)
    assert_empty(stdout)
  end

  def test_exits_1_when_the_caller_split_returns_no_pane_id
    stub_response("herdr pane split --current", { "stdout" => '{"result":{}}' })

    stdout, _, status = open_column(toplevel, "--row", SLUG)

    assert_equal(1, status.exitstatus)
    assert_empty(stdout)
  end

  def test_skips_a_recorded_pane_whose_terminal_changed
    record_row("w1:pA term_A")
    stub_response("herdr pane get w1:pA", pane_answer("w1:pA", "term_somebody_else"))

    assert_column_opens_on_the_caller_pane
    assert_empty(herdr_calls.grep(/\Apane split w1:pA/))
  end

  def test_falls_back_to_the_caller_when_the_last_recorded_pane_is_gone_even_if_an_earlier_one_lives
    record_row("w1:pA term_A", "w1:pB term_B")
    stub_response("herdr pane get w1:pA", pane_answer("w1:pA", "term_A"))
    stub_response("herdr pane get w1:pB", { "exit" => 1 })

    assert_column_opens_on_the_caller_pane
    assert_empty(herdr_calls.grep(/\Apane split w1:p[AB]/))
  end

  def test_falls_back_to_the_caller_when_the_row_end_refuses_the_split
    record_row("w1:pB term_B")
    stub_response("herdr pane get w1:pB", pane_answer("w1:pB", "term_B"))
    stub_response("herdr pane split w1:pB", { "exit" => 1, "stderr" => "pane closed\n" })

    assert_column_opens_on_the_caller_pane
    assert_includes(herdr_calls, "pane split w1:pB --direction right --cwd #{toplevel} --no-focus")
  end

  def test_treats_an_anchored_split_without_a_pane_id_as_a_refusal
    record_row("w1:pB term_B")
    stub_response("herdr pane get w1:pB", pane_answer("w1:pB", "term_B"))
    stub_response("herdr pane split w1:pB", { "stdout" => '{"result":{}}' })

    assert_column_opens_on_the_caller_pane
  end

  def test_falls_back_to_the_caller_without_a_row_record
    assert_column_opens_on_the_caller_pane
  end

  def test_splits_right_of_the_last_recorded_pane_when_it_is_live
    record_row("w1:pA term_A", "w1:pB term_B")
    stub_response("herdr pane get w1:pB", pane_answer("w1:pB", "term_B"))

    _, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane split w1:pB --direction right --cwd #{toplevel} --no-focus")
    assert_empty(herdr_calls.grep(/--current|w1:pA/))
  end

  def test_prints_only_the_new_pane_id
    stdout, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_equal("#{NEW_PANE}\n", stdout)
  end

  def test_without_a_row_splits_right_of_the_caller_and_records_nothing
    stdout, stderr, status = open_column(toplevel)

    assert(status.success?, stderr)
    assert_equal("#{NEW_PANE}\n", stdout)
    assert_includes(herdr_calls, "pane split --current --direction right --cwd #{toplevel} --no-focus")
    assert_empty(Dir.glob(File.join(common_dir, "herdr", "stage-panes-*")))
  end

  def test_a_new_row_splits_down_from_the_caller_whatever_the_record_holds
    record_row("w1:pB term_B")
    stub_response("herdr pane get w1:pB", pane_answer("w1:pB", "term_B"))

    _, stderr, status = open_column(toplevel, "--row", SLUG, "--new-row")

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane split --current --direction down --cwd #{toplevel} --no-focus")
    assert_empty(herdr_calls.grep(/\Apane split w1:pB/))
  end

  def test_appends_the_new_pane_and_its_terminal_to_the_row_record
    record_row("w1:pB term_B")
    stub_response("herdr pane get w1:pB", pane_answer("w1:pB", "term_B"))

    open_column(toplevel, "--row", SLUG)

    assert_equal([ "w1:pB term_B", "#{NEW_PANE} term_N" ], row_record)
  end

  def test_records_nothing_when_the_new_terminal_cannot_be_read
    stub_response("herdr pane get w1:pN", { "exit" => 1 })

    stdout, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_equal("#{NEW_PANE}\n", stdout)
    assert_empty(row_record)
  end

  def test_an_unlisted_column_is_placed_but_not_recorded
    record_row("w1:pB term_B")
    stub_response("herdr pane get w1:pB", pane_answer("w1:pB", "term_B"))

    _, stderr, status = open_column(toplevel, "--row", SLUG, "--unlisted")

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane split w1:pB --direction right --cwd #{toplevel} --no-focus")
    assert_equal([ "w1:pB term_B" ], row_record)
  end

  private

  def assert_column_opens_on_the_caller_pane
    stdout, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_equal("#{NEW_PANE}\n", stdout)
    assert_includes(herdr_calls, "pane split --current --direction right --cwd #{toplevel} --no-focus")
  end

  def open_column(*arguments)
    run_script(OPEN_COLUMN, *arguments, herdr: true)
  end

  def pane_answer(pane_id, terminal_id)
    { "stdout" => JSON.generate(result: { pane: { pane_id: pane_id, terminal_id: terminal_id } }) }
  end

  def row_record_path
    File.join(common_dir, "herdr", "stage-panes-#{SLUG}")
  end

  def record_row(*lines)
    FileUtils.mkdir_p(File.dirname(row_record_path))
    File.write(row_record_path, lines.map { |line| "#{line}\n" }.join)
  end

  def row_record
    File.exist?(row_record_path) ? File.readlines(row_record_path, chomp: true) : []
  end
end
