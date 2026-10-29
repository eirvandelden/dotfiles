#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"
require_relative "delivery_harness"
require_relative "isolated_git"

# open-pr-dash.sh <slug> <pr-url> opens a herdr pane running gh-dash filtered to one PR, right of
# the last pane of the change's row (open-column.sh finds it in the stage-panes record and never
# lists the gh-dash pane there). herdr and gh are stubs; see delivery_harness.rb for their response
# format.
#
# Interface these tests pin, beyond the plan: the new pane id is read from `.result.pane.pane_id`
# of the split answer; gh-dash is started as the words `gh dash --config <file>` after the pane id.
class OpenPrDashTest < Minitest::Test
  include DeliveryHarness

  BRANCH = "feature/my-change".freeze
  SLUG = "my-change".freeze
  NEW_PANE = "w1:pN".freeze

  def setup
    setup_harness
    build_repo(branch: BRANCH)
    record_row("w1:pA term_A", "w1:pB term_B")
    stub_response("herdr pane get w1:pA", pane_answer("w1:pA", "term_A"))
    stub_response("herdr pane get w1:pB", pane_answer("w1:pB", "term_B"))
    stub_response("herdr pane split", pane_answer(NEW_PANE, "term_N"))
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

  def test_opens_gh_dash_right_of_the_last_pane_of_the_change
    _, stderr, status = dash

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane split w1:pB --direction right --cwd #{toplevel} --no-focus")
    assert_empty(herdr_calls.grep(/split w1:pA/))
  end

  def test_never_swaps_panes
    dash

    assert_empty(herdr_calls.grep(/pane swap/))
  end

  def test_leaves_the_row_record_unchanged
    dash

    assert_equal([ "w1:pA term_A", "w1:pB term_B" ], File.readlines(row_record_path, chomp: true))
  end

  def test_runs_gh_dash_with_that_config_in_the_new_pane
    dash

    assert_includes(herdr_calls, "pane run #{NEW_PANE} gh dash --config #{config_path}")
  end

  def test_falls_back_to_the_caller_when_no_pane_of_the_change_is_live
    %w[w1:pA w1:pB].each do |pane|
      stub_response("herdr pane get #{pane}", { "exit" => 1, "stderr" => "pane #{pane} not found\n" })
    end

    assert_anchored_on_the_caller_pane
  end

  def test_falls_back_without_a_row_record
    File.delete(row_record_path)

    assert_anchored_on_the_caller_pane
  end

  def test_outside_herdr_prints_the_pr_url_and_opens_no_pane
    stdout, stderr, status = dash(herdr: false)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_match(/no pane/i, stdout)
    assert_empty(herdr_calls)
  end

  private

  def dash(herdr: true)
    run_script(OPEN_PR_DASH, SLUG, PR_URL, herdr: herdr)
  end

  def assert_anchored_on_the_caller_pane
    _, stderr, status = dash

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane split --current --direction right --cwd #{toplevel} --no-focus")
    assert_empty(herdr_calls.grep(/pane swap|split w1:pB/))
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

  def config_path
    File.join(common_dir, "deliver", "#{SLUG}.gh-dash.yml")
  end
end
