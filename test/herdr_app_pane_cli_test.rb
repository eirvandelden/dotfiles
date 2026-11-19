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
      %w[close-idle], %w[close-at], %w[tab], [ "tab", @repo, "--name" ], [ "tab", @repo, "--bogus" ],
      [ "tab", "--name", "x" ] ].each do |arguments|
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

  def test_tab_prints_the_terminal_address
    stdout, stderr, status = pane_cli("tab", @repo, "--name", "docs", "--", "tail", "-f", "log")

    assert(status.success?, stderr)
    assert_equal("t61\n", stdout)
    assert_equal([ { "folder" => @repo, "name" => "docs", "argv" => %w[tail -f log], "focus" => false,
                    "space" => "sp1" } ], herdr_app_actions("tab.new"))
  end

  def test_tab_runs_outside_a_git_repository
    outside = Dir.mktmpdir("outside")

    _, stderr, status = Open3.capture3(herdr_app_env, RbConfig.ruby, PANE_CLI, "tab", outside, chdir: outside)

    assert(status.success?, stderr)
  ensure
    FileUtils.rm_rf(outside)
  end

  def test_tab_from_the_work_core_opens_in_the_work_space_while_a_personal_space_has_focus
    use_work_world

    stdout, stderr, status = pane_cli("tab", @repo, "--name", "probe", own: "t20", core: "work")

    assert(status.success?, stderr)
    assert_equal("t61\n", stdout)
    assert_equal([ "work/sp3" ], herdr_app_actions("tab.new").map { |request| request["space"] })
    assert_equal("p11", herdr_app_world[FOCUS_KEY])
    herdr_app_assert_hc_addresses
  end

  def test_tab_from_the_default_core_opens_in_the_personal_space_while_a_work_space_has_focus
    use_work_world
    herdr_app_world_change { |world| world[FOCUS_KEY] = "work/p11" }

    stdout, stderr, status = pane_cli("tab", @repo, "--name", "probe", own: "t20")

    assert(status.success?, stderr)
    assert_equal("t61\n", stdout)
    assert_equal([ "sp2" ], herdr_app_actions("tab.new").map { |request| request["space"] })
    assert_equal("work/p11", herdr_app_world[FOCUS_KEY])
    herdr_app_assert_hc_addresses
  end

  def test_open_from_a_work_terminal_splits_beside_it_and_prints_an_hc_address
    use_work_world

    stdout, stderr, status = pane_cli("open", @repo, "--", "claude", own: "t20", core: "work")

    assert(status.success?, stderr)
    assert_equal("t61\n", stdout)
    assert_equal([ %w[work/p20 right] ], herdr_app_splits.map { |request| request.values_at("pane", "direction") })
    herdr_app_assert_hc_addresses
  end

  def test_close_from_a_work_terminal_closes_its_own_pane
    use_work_world

    _, stderr, status = pane_cli("close", own: "t20", core: "work")

    assert(status.success?, stderr)
    assert_equal([ { "pane" => "work/p20" } ], herdr_app_actions("pane.close"))
    herdr_app_assert_hc_addresses
  end

  private

  def use_work_world
    herdr_app_world_write(work_world(cwd: @repo, work_cwd: @repo))
  end

  def pane_cli(*arguments, own: COORDINATOR, core: "default")
    Open3.capture3(herdr_app_env(own: own, core: core), RbConfig.ruby, PANE_CLI, *arguments, chdir: @repo)
  end
end
