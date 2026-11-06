#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# The dispatchers in agents/.agents/bin choose the herdr or the Rex stage script from the environment:
# HERDR_ENV=1 runs the herdr script, REX_SESSION runs the Rex script, herdr wins when both are set, and
# neither refuses. Each script is a stub that records its arguments and its coordinator variables.
# COORDINATOR=<id> becomes HERDR_PANE_ID for herdr and REX_BLOCK for Rex.
class DispatchersTest < Minitest::Test
  BIN = File.expand_path("../agents/.agents/bin", __dir__)
  DISPATCHERS = {
    "hand-off-plan" => "hand-off-plan.sh",
    "start-review" => "start-review.sh",
    "open-pr-dash" => "open-pr-dash.sh"
  }.freeze

  def setup
    @root = Dir.mktmpdir
    @herdr_scripts = File.join(@root, "herdr")
    @rex_scripts = File.join(@root, "rex")
    @log = File.join(@root, "calls.log")
    DISPATCHERS.each_value do |script|
      install_stub(File.join(@herdr_scripts, script), "herdr")
      install_stub(File.join(@rex_scripts, script), "rex")
    end
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_hand_off_plan_runs_the_herdr_script_in_a_herdr_pane
    _stdout, stderr, status = dispatch("hand-off-plan", "plan", "some-change", herdr: true)

    assert(status.success?, stderr)
    assert_equal([ "herdr plan some-change" ], calls)
  end

  def test_hand_off_plan_runs_the_rex_script_in_a_rex_block
    _stdout, stderr, status = dispatch("hand-off-plan", "plan", "some-change", rex: true)

    assert(status.success?, stderr)
    assert_equal([ "rex plan some-change" ], calls)
  end

  def test_each_dispatcher_runs_its_herdr_script_when_herdr_env_is_set
    DISPATCHERS.each_key do |name|
      File.delete(@log) if File.exist?(@log)

      _stdout, stderr, status = dispatch(name, "one", "two words", herdr: true)

      assert(status.success?, "#{name}: #{stderr}")
      assert_equal([ "herdr one two words" ], calls, name)
    end
  end

  def test_each_dispatcher_runs_its_rex_script_when_rex_session_is_set
    DISPATCHERS.each_key do |name|
      File.delete(@log) if File.exist?(@log)

      _stdout, stderr, status = dispatch(name, "one", "two words", rex: true)

      assert(status.success?, "#{name}: #{stderr}")
      assert_equal([ "rex one two words" ], calls, name)
    end
  end

  def test_each_dispatcher_passes_the_arguments_through_unchanged
    DISPATCHERS.each_key do |name|
      File.delete(@log) if File.exist?(@log)

      dispatch(name, "implement", "my-change", "--auto", herdr: true)

      assert_equal([ "herdr implement my-change --auto" ], calls, name)
    end
  end

  def test_herdr_wins_when_both_environments_are_set
    DISPATCHERS.each_key do |name|
      File.delete(@log) if File.exist?(@log)

      _stdout, stderr, status = dispatch(name, "plan", "some-change", herdr: true, rex: true)

      assert(status.success?, "#{name}: #{stderr}")
      assert_equal([ "herdr plan some-change" ], calls, name)
    end
  end

  def test_each_dispatcher_refuses_outside_both_tools_and_names_both
    DISPATCHERS.each_key do |name|
      _stdout, stderr, status = dispatch(name, "plan", "some-change")

      assert_equal(1, status.exitstatus, name)
      assert_match(/herdr/i, stderr, name)
      assert_match(/rex/i, stderr, name)
    end
    assert_empty(calls)
  end

  def test_a_herdr_env_other_than_one_does_not_count_as_herdr
    _stdout, _stderr, status = dispatch("hand-off-plan", "plan", "some-change", env: { "HERDR_ENV" => "0" })

    assert_equal(1, status.exitstatus)
    assert_empty(calls)
  end

  def test_the_coordinator_becomes_the_herdr_pane_id_in_a_herdr_pane
    dispatch("hand-off-plan", "implement", "some-change", herdr: true, env: { "COORDINATOR" => "w1:pCoord" })

    assert_equal([ "herdr implement some-change pane=w1:pCoord block=" ], calls_with_coordinator)
  end

  def test_the_coordinator_becomes_the_rex_block_in_a_rex_block
    dispatch("hand-off-plan", "implement", "some-change", rex: true, env: { "COORDINATOR" => "blkCoord" })

    assert_equal([ "rex implement some-change pane= block=blkCoord" ], calls_with_coordinator)
  end

  def test_without_a_coordinator_the_callers_own_variables_stay
    dispatch("start-review", "some-change", herdr: true, env: { "HERDR_PANE_ID" => "w1:pOwn" })
    dispatch("start-review", "some-change", rex: true, env: { "REX_BLOCK" => "blkOwn" })

    assert_equal([ "herdr some-change pane=w1:pOwn block=", "rex some-change pane= block=blkOwn" ],
                 calls_with_coordinator)
  end

  private

  def dispatch(name, *arguments, herdr: false, rex: false, env: {})
    environment = {
      "HERDR_ENV" => (herdr ? "1" : nil), "REX_SESSION" => (rex ? "S1" : nil),
      "HERDR_PANE_ID" => nil, "REX_BLOCK" => nil, "COORDINATOR" => nil,
      "HERDR_SCRIPTS_DIR" => @herdr_scripts, "REX_SCRIPTS_DIR" => @rex_scripts,
      "STUB_LOG" => @log, "HOME" => @root
    }.merge(env)
    Open3.capture3(environment, File.join(BIN, name), *arguments)
  end

  def install_stub(path, label)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, <<~SH)
      #!/bin/sh
      printf '%s %s pane=%s block=%s\\n' '#{label}' "$*" "${HERDR_PANE_ID:-}" "${REX_BLOCK:-}" >> "$STUB_LOG"
    SH
    FileUtils.chmod(0o755, path)
  end

  def calls_with_coordinator
    File.exist?(@log) ? File.readlines(@log, chomp: true) : []
  end

  def calls
    calls_with_coordinator.map { |line| line.sub(/ pane=.*\z/, "") }
  end
end
