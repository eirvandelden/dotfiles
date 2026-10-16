#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"
require_relative "delivery_harness"
require_relative "isolated_git"

# open-pr-dash.sh <slug> <pr-url> opens a herdr pane running gh-dash filtered to one PR, directly
# left of the pane that wrote the intent. herdr 0.9.3 can only split right or down, so it splits
# the anchor to the right and swaps the new pane into the anchor's place. herdr and gh are stubs;
# see delivery_harness.rb for their response format.
#
# Interface these tests pin, beyond the plan: the intent pane file holds the pane id on line 1 and
# the terminal id on line 2; the new pane id is read from `.result.pane.pane_id` of the split
# answer; gh-dash is started as the words `gh dash --config <file>` after the pane id.
class OpenPrDashTest < Minitest::Test
  include DeliveryHarness

  BRANCH = "feature/my-change".freeze
  SLUG = "my-change".freeze
  INTENT_PANE = "w1:pA".freeze
  NEW_PANE = "w1:pN".freeze

  def setup
    setup_harness
    build_repo(branch: BRANCH)
    record_intent_pane(INTENT_PANE, "term_A")
    stub_response("herdr pane get w1:pA", pane_answer(INTENT_PANE, "term_A"))
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

  def test_opens_gh_dash_directly_left_of_the_intent_pane
    _, stderr, status = dash

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane get #{INTENT_PANE}")
    split = herdr_calls.index("pane split #{INTENT_PANE} --direction right --cwd #{toplevel} --no-focus")
    swap = herdr_calls.index("pane swap --source-pane #{NEW_PANE} --target-pane #{INTENT_PANE}")

    assert(split, "no split of the intent pane to the right in #{herdr_calls}")
    assert(swap, "no swap of the new pane into the intent pane's place in #{herdr_calls}")
    assert_operator(split, :<, swap)
  end

  def test_runs_gh_dash_with_that_config_in_the_new_pane
    dash

    assert_includes(herdr_calls, "pane run #{NEW_PANE} gh dash --config #{config_path}")
  end

  def test_falls_back_to_the_own_pane_when_the_intent_pane_is_gone
    stub_response("herdr pane get w1:pA", { "exit" => 1, "stderr" => "pane w1:pA not found\n" })

    assert_anchored_on_own_pane
  end

  def test_falls_back_when_no_intent_pane_was_recorded
    File.delete(intent_pane_file)

    assert_anchored_on_own_pane
  end

  def test_falls_back_when_the_recorded_terminal_id_no_longer_matches
    stub_response("herdr pane get w1:pA", pane_answer(INTENT_PANE, "term_somebody_else"))

    assert_anchored_on_own_pane
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

  def assert_anchored_on_own_pane
    stub_response("herdr pane split #{OWN_PANE}", pane_answer(NEW_PANE, "term_N"))

    _, stderr, status = dash

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane split #{OWN_PANE} --direction right --cwd #{toplevel} --no-focus")
    assert_includes(herdr_calls, "pane swap --source-pane #{NEW_PANE} --target-pane #{OWN_PANE}")
    assert_empty(herdr_calls.grep(/--target-pane #{INTENT_PANE}|split #{INTENT_PANE}/))
  end

  def pane_answer(pane_id, terminal_id)
    { "stdout" => JSON.generate(result: { pane: { pane_id: pane_id, terminal_id: terminal_id } }) }
  end

  def intent_pane_file
    File.join(common_dir, "herdr", "intent-pane-#{SLUG}")
  end

  def record_intent_pane(pane_id, terminal_id)
    FileUtils.mkdir_p(File.dirname(intent_pane_file))
    File.write(intent_pane_file, "#{pane_id}\n#{terminal_id}\n")
  end

  def config_path
    File.join(common_dir, "deliver", "#{SLUG}.gh-dash.yml")
  end
end
