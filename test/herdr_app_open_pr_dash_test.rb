#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"
require_relative "delivery_harness"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# The herdr-app open-pr-dash.sh <slug> <pr-url> writes a gh-dash config filtered to this branch, then asks
# herdr-app-pane for an unlisted pane in the change's row that runs gh-dash. herdr-app-pane is a stub that
# logs its arguments; gh is the DeliveryHarness stub.
class HerdrAppOpenPrDashTest < Minitest::Test
  include DeliveryHarness
  include HerdrAppHarness
  include HerdrAppHarness::Fixtures

  BRANCH = "feature/my-change".freeze
  SLUG = "my-change".freeze
  SCRIPT = File.join(HerdrAppHarness::SCRIPTS, "open-pr-dash.sh")

  def setup
    setup_harness
    build_repo(branch: BRANCH)
    herdr_app_setup(default_world(cwd: toplevel))
  end

  def teardown
    herdr_app_teardown
    teardown_harness
  end

  def test_prints_the_url_and_opens_nothing_outside_herdr_app
    stdout, stderr, status = dash(own: nil)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_empty(herdr_app_pane_cli_calls)
    assert_empty(herdr_app_calls)
  end

  def test_opens_gh_dash_unlisted_in_the_row
    _, stderr, status = dash

    assert(status.success?, stderr)
    assert_equal([ [ "open", toplevel, "--row", SLUG, "--unlisted", "--", "gh", "dash", "--config", config_path ] ],
                 herdr_app_pane_cli_calls)
    config = YAML.safe_load_file(config_path)
    assert_equal([ { "title" => SLUG, "filters" => "repo:eirvandelden/dots head:#{BRANCH}" } ], config["prSections"])
  end

  private

  def dash(own: COORDINATOR)
    env = herdr_app_env(own: own).merge("PATH" => "#{@herdr_app_bin}:#{@stub_bin}:#{ENV.fetch('PATH')}")
    run_script(SCRIPT, SLUG, PR_URL, env: env)
  end

  def config_path
    File.join(common_dir, "deliver", "#{SLUG}.gh-dash.yml")
  end
end
