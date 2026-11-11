#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# herdr-app-pane, the CLI over HerdrAppPane::Panes, run as a child process inside a git repository, with
# stub herdr-app and hc. HC_TERMINAL_ID is set in the child only. See herdr_app_harness.rb for the World.
class HerdrAppPaneCliTest < Minitest::Test
  include HerdrAppHarness
  include HerdrAppHarness::Fixtures

  def setup
    @repo = Dir.mktmpdir("pane-cli-repo")
    system("git", "init", "--quiet", "--initial-branch=main", @repo, exception: true)
    @repo = File.realpath(@repo)
    @world = default_world(cwd: @repo)
    herdr_app_setup(@world)
  end

  def teardown
    herdr_app_teardown
    FileUtils.rm_rf(@repo)
  end

  def test_refuses_bad_arguments_before_any_call
    [ [], %w[bogus], %w[open], [ "open", @repo, "--new-row", "--unlisted" ], [ "open", @repo, "--row" ],
      %w[close-idle], %w[close-at] ].each do |arguments|
      _, stderr, status = pane_cli(*arguments)

      assert_equal(1, status.exitstatus, arguments.inspect)
      assert_match(/usage/i, stderr, arguments.inspect)
    end
    assert_empty(herdr_app_calls)
  end

  def test_open_exits_1_with_the_reason
    herdr_app_world_change { |world| world["refuse_split"] = { "p10" => "pane p10 is zoomed" } }

    stdout, stderr, status = pane_cli("open", @repo, "--", "claude")

    assert_equal(1, status.exitstatus)
    assert_empty(stdout)
    assert_equal(1, stderr.lines.count, stderr)
    assert_match(/zoomed/, stderr)
  end

  def test_open_prints_the_terminal_address
    stdout, stderr, status = pane_cli("open", @repo, "--", "claude", "--model", "sonnet", "Reply OK.")

    assert(status.success?, stderr)
    assert_equal("t61\n", stdout)
    assert_equal([ %w[p10 right] ], herdr_app_splits.map { |request| request.values_at("pane", "direction") })
  end

  def test_close_defaults_to_the_own_terminal
    herdr_app_world_change do |world|
      add_terminal(world, agent_row("t61", "p61", "working"), terminal("t61", cwd: @repo, status: agent("working")))
    end

    _, stderr, status = pane_cli("close", own: "t61")

    assert(status.success?, stderr)
    assert_equal([ { "pane" => "p61" } ], herdr_app_actions("pane.close"))
    assert_equal(%w[p10 p11], herdr_app_listed_panes)
  end

  def test_close_idle_and_close_at_reach_the_class
    worktree = File.join(@repo, "worktree")
    FileUtils.mkdir_p(worktree)
    herdr_app_world_change do |world|
      add_terminal(world, agent_row("t20", "p20", "idle"), terminal("t20", cwd: @repo, status: agent))
      add_terminal(world, terminal_row("t21", "p21"), terminal("t21", cwd: @repo, foreground_cwd: worktree))
    end
    record = File.join(@repo, ".git", "herdr-app", "stage-panes-some-change")
    FileUtils.mkdir_p(File.dirname(record))
    File.write(record, "t20\n")

    _, idle_error, idle_status = pane_cli("close-idle", "some-change")
    _, at_error, at_status = pane_cli("close-at", worktree)

    assert(idle_status.success?, idle_error)
    assert(at_status.success?, at_error)
    assert_equal([ { "pane" => "p20" }, { "pane" => "p21" } ], herdr_app_actions("pane.close"))
    refute_path_exists(record)
  end

  private

  def pane_cli(*arguments, own: COORDINATOR)
    Open3.capture3(herdr_app_env(own: own), RbConfig.ruby, PANE_CLI, *arguments, chdir: @repo)
  end
end
