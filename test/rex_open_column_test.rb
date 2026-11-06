#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "delivery_harness"
require_relative "rex_harness_compat"
require_relative "isolated_git"

# open-column.sh <cwd> [--row <slug>] [--new-row | --unlisted] [-- <command>...] opens the next column of
# a change's row of Rex blocks and prints its block id. The row record is
# <git-common-dir>/rex/stage-panes-<slug>, one block id per line. A recorded block is a live anchor only
# while `rex block ls` lists it. rex is a stub; see delivery_harness.rb for its response format. The caller
# is the block named by $REX_BLOCK.
class RexOpenColumnTest < Minitest::Test
  include DeliveryHarness

  OPEN_COLUMN = File.join(REX_SCRIPTS, "open-column.sh")
  SLUG = "my-change".freeze
  NEW_BLOCK = "blkN".freeze

  def setup
    setup_harness
    build_repo(branch: "my-change")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK))
    stub_response("rex split", split_answer(NEW_BLOCK))
  end

  def teardown
    teardown_harness
  end

  def test_refuses_bad_arguments_before_any_rex_call
    [ [],
      [ toplevel, "--bogus" ],
      [ toplevel, "--new-row" ],
      [ toplevel, "--unlisted" ],
      [ toplevel, "--row", SLUG, "--new-row", "--unlisted" ],
      [ toplevel, "--row" ] ].each do |arguments|
      _, stderr, status = open_column(*arguments)

      assert_equal(1, status.exitstatus, arguments.inspect)
      refute_empty(stderr, arguments.inspect)
      assert_empty(rex_calls, arguments.inspect)
    end
  end

  def test_exits_1_when_the_caller_split_fails
    stub_response("rex split", { "exit" => 1, "stderr" => "no block\n" })

    stdout, _, status = open_column(toplevel, "--row", SLUG)

    assert_equal(1, status.exitstatus)
    assert_empty(stdout)
  end

  def test_exits_1_when_the_caller_split_returns_no_block_id
    stub_response("rex split", { "stdout" => '{"block_ids":[]}' })

    stdout, _, status = open_column(toplevel, "--row", SLUG)

    assert_equal(1, status.exitstatus)
    assert_empty(stdout)
  end

  def test_skips_dead_blocks
    record_row("blkA")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK))

    assert_column_opens_on_the_caller_block
    assert_empty(split_calls.grep(/-b blkA\b/))
  end

  def test_falls_back_to_the_caller_when_the_last_block_is_gone
    record_row("blkA", "blkB")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK, "blkA"))

    assert_column_opens_on_the_caller_block
    assert_empty(split_calls.grep(/-b blk[AB]\b/))
  end

  def test_falls_back_to_the_caller_when_the_row_end_refuses_the_split
    record_row("blkB")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK, "blkB"))
    stub_response("rex split blkB", { "exit" => 1, "stderr" => "block closed\n" })

    assert_column_opens_on_the_caller_block
    assert(split_calls.any? { |call| call.match?(/-b blkB\b/) }, split_calls.inspect)
  end

  def test_treats_an_anchored_split_without_a_block_id_as_a_refusal
    record_row("blkB")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK, "blkB"))
    stub_response("rex split blkB", { "stdout" => '{"block_ids":[]}' })

    assert_column_opens_on_the_caller_block
  end

  def test_falls_back_to_the_caller_without_a_row_record
    assert_column_opens_on_the_caller_block
  end

  def test_places_right_of_the_last_live_block
    record_row("blkA", "blkB")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK, "blkA", "blkB"))

    _, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_match(/-b blkB\b.*--split[= ]right\b.*-c #{Regexp.escape(toplevel)}\b.*--focus=false/, split_calls.first)
    assert_empty(split_calls.grep(/-b #{OWN_BLOCK}\b|-b blkA\b/))
  end

  def test_places_the_split_with_json_and_reads_the_block_id_from_it
    _, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_match(/--json/, split_calls.first)
  end

  def test_prints_only_the_new_block_id
    stdout, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_equal("#{NEW_BLOCK}\n", stdout)
  end

  def test_without_a_row_splits_right_of_the_caller_and_records_nothing
    stdout, stderr, status = open_column(toplevel)

    assert(status.success?, stderr)
    assert_equal("#{NEW_BLOCK}\n", stdout)
    assert_match(/-b #{OWN_BLOCK}\b.*--split[= ]right/, split_calls.first)
    assert_empty(Dir.glob(File.join(common_dir, "rex", "stage-panes-*")))
  end

  def test_new_row_splits_below_the_caller
    record_row("blkB")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK, "blkB"))

    _, stderr, status = open_column(toplevel, "--row", SLUG, "--new-row")

    assert(status.success?, stderr)
    assert_match(/-b #{OWN_BLOCK}\b.*--split[= ]below/, split_calls.first)
    assert_empty(split_calls.grep(/-b blkB\b/))
  end

  def test_lists_the_block_in_the_row_record
    record_row("blkB")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK, "blkB"))

    open_column(toplevel, "--row", SLUG)

    assert_equal([ "blkB", NEW_BLOCK ], row_record)
  end

  def test_never_lists_an_unlisted_block
    record_row("blkB")
    stub_response("rex block ls", blocks_answer(OWN_BLOCK, "blkB"))

    _, stderr, status = open_column(toplevel, "--row", SLUG, "--unlisted")

    assert(status.success?, stderr)
    assert_match(/-b blkB\b.*--split[= ]right/, split_calls.first)
    assert_equal([ "blkB" ], row_record)
  end

  def test_runs_the_command_after_the_dashes_in_the_new_block
    _, stderr, status = open_column(toplevel, "--row", SLUG, "--", "claude", "--model", "opus")

    assert(status.success?, stderr)
    assert_match(/ -- claude --model opus\z/, split_calls.first)
  end

  private

  def assert_column_opens_on_the_caller_block
    stdout, stderr, status = open_column(toplevel, "--row", SLUG)

    assert(status.success?, stderr)
    assert_equal("#{NEW_BLOCK}\n", stdout)
    assert_match(/-b #{OWN_BLOCK}\b.*--split[= ]right/, split_calls.last)
  end

  def split_calls
    rex_calls.grep(/\Asplit\b/)
  end

  def open_column(*arguments)
    run_script(OPEN_COLUMN, *arguments, rex: true)
  end

  def split_answer(block_id)
    { "stdout" => JSON.generate(anchor_id: OWN_BLOCK, block_ids: [ block_id ], split_ids: [ "s1" ], revision: 1) }
  end

  def blocks_answer(*ids)
    { "stdout" => JSON.generate(blocks: ids.map { |id| { block_id: id, label: "shell", flavor: "shell" } }) }
  end

  def row_record_path
    File.join(common_dir, "rex", "stage-panes-#{SLUG}")
  end

  def record_row(*lines)
    FileUtils.mkdir_p(File.dirname(row_record_path))
    File.write(row_record_path, lines.map { |line| "#{line}\n" }.join)
  end

  def row_record
    File.exist?(row_record_path) ? File.readlines(row_record_path, chomp: true) : []
  end
end
