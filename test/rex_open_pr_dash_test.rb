#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"
require_relative "delivery_harness"
require_relative "rex_harness_compat"
require_relative "isolated_git"

# open-pr-dash.sh <slug> <pr-url> opens a Rex block running gh-dash filtered to one PR, right of
# the last block of the change's row (open-column.sh finds it in the stage-panes record and never
# lists the gh-dash block there). rex and gh are stubs; see delivery_harness.rb for their response
# format.
#
# Interface these tests pin, beyond the plan: the new block id is read from `.block_ids[0]` of the
# split answer; gh-dash is the split command, the words `gh dash --config <file>` after `--`. A
# recorded block is a live anchor only while `rex block ls` lists it.
class RexOpenPrDashTest < Minitest::Test
  include DeliveryHarness

  BRANCH = "feature/my-change".freeze
  SLUG = "my-change".freeze
  NEW_BLOCK = "blkN".freeze
  DISPATCHER = File.join(REPO_ROOT, "agents/.agents/bin/open-pr-dash")

  def setup
    setup_harness
    build_repo(branch: BRANCH)
    record_row("blkA", "blkB")
    stub_response("rex block ls", blocks_answer("blkA", "blkB", OWN_BLOCK))
    stub_response("rex split", { "stdout" => JSON.generate(block_ids: [ NEW_BLOCK ]) })
  end

  def teardown
    teardown_harness
  end

  def test_writes_a_config_that_filters_on_the_branch
    dash

    config = YAML.safe_load_file(config_path)

    assert_equal("prs", config.dig("defaults", "view"))
    assert_equal([ { "title" => SLUG, "filters" => "repo:eirvandelden/dots head:#{BRANCH}" } ], config["prSections"])
  end

  def test_opens_gh_dash_right_of_the_last_block_of_the_change
    _, stderr, status = dash

    assert(status.success?, stderr)
    assert_equal(1, split_calls.size)
    assert_match(/-b blkB\b.*--split[= ]right/, split_calls.first)
    assert_empty(split_calls.grep(/-b blkA\b/))
  end

  def test_leaves_the_row_record_unchanged
    dash

    assert_equal(%w[blkA blkB], File.readlines(row_record_path, chomp: true))
  end

  def test_runs_gh_dash_with_that_config_as_the_split_command
    dash

    assert_match(/ -- gh dash --config #{Regexp.escape(config_path)}\z/, split_calls.first)
  end

  def test_falls_back_to_the_caller_when_no_block_of_the_change_is_live
    stub_response("rex block ls", blocks_answer(OWN_BLOCK))

    assert_anchored_on_the_caller_block
  end

  def test_falls_back_without_a_row_record
    File.delete(row_record_path)

    assert_anchored_on_the_caller_block
  end

  def test_outside_rex_prints_the_pr_url_and_opens_no_block
    stdout, stderr, status = dash(rex: false)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_match(/no block|not inside rex/i, stdout)
    assert_empty(rex_calls)
  end

  def test_an_unlisted_gh_dash_block_is_never_recorded_in_the_row
    dash

    refute_includes(File.read(row_record_path), NEW_BLOCK)
  end

  def test_the_dispatcher_opens_the_rex_block_in_a_rex_block
    _, stderr, status = run_script(DISPATCHER, SLUG, PR_URL, rex: true, env: { "REX_SCRIPTS_DIR" => REX_SCRIPTS })

    assert(status.success?, stderr)
    assert_match(/ -- gh dash --config #{Regexp.escape(config_path)}\z/, split_calls.first.to_s)
  end

  private

  def dash(rex: true)
    run_script(REX_OPEN_PR_DASH, SLUG, PR_URL, rex: rex)
  end

  def split_calls
    rex_calls.grep(/\Asplit\b/)
  end

  def assert_anchored_on_the_caller_block
    _, stderr, status = dash

    assert(status.success?, stderr)
    assert_match(/-b #{OWN_BLOCK}\b.*--split[= ]right/, split_calls.first.to_s)
    assert_empty(split_calls.grep(/-b blk[AB]\b/))
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

  def config_path
    File.join(common_dir, "deliver", "#{SLUG}.gh-dash.yml")
  end
end
