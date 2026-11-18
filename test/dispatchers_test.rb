#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# The dispatchers in agents/.agents/bin run the herdr-app stage script when HC_TERMINAL_ID is set and refuse
# otherwise. Each script is a stub that records its arguments and its coordinator variable.
# COORDINATOR=<address> becomes HERDR_APP_COORDINATOR.
class DispatchersTest < Minitest::Test
  BIN = File.expand_path("../agents/.agents/bin", __dir__)
  DISPATCHERS = {
    "hand-off-plan" => "hand-off-plan.sh",
    "start-review" => "start-review.sh",
    "open-pr-dash" => "open-pr-dash.sh"
  }.freeze
  # Built from parts, so this file never holds a whole retired token.
  RETIRED_SESSION = %w[REX SESSION].join("_")

  def setup
    @root = Dir.mktmpdir
    @herdr_app_scripts = File.join(@root, "herdr-app")
    @log = File.join(@root, "calls.log")
    DISPATCHERS.each_value { |script| install_herdr_app_stub(File.join(@herdr_app_scripts, script)) }
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_each_dispatcher_runs_its_herdr_app_script_when_hc_terminal_id_is_set
    DISPATCHERS.each_key do |name|
      File.delete(@log) if File.exist?(@log)

      _stdout, stderr, status = dispatch(name, "one", "two words", herdr_app: true)

      assert(status.success?, "#{name}: #{stderr}")
      assert_equal([ "herdr-app one two words" ], calls, name)
    end
  end

  def test_each_dispatcher_passes_the_arguments_through_unchanged
    DISPATCHERS.each_key do |name|
      File.delete(@log) if File.exist?(@log)

      dispatch(name, "implement", "my-change", "--auto", herdr_app: true)

      assert_equal([ "herdr-app implement my-change --auto" ], calls, name)
    end
  end

  def test_coordinator_becomes_herdr_app_coordinator
    dispatch("hand-off-plan", "implement", "some-change", herdr_app: true, env: { "COORDINATOR" => "t30" })

    assert_equal([ "herdr-app implement some-change coordinator=t30" ], calls_with_coordinator)
  end

  def test_each_dispatcher_refuses_outside_a_herdr_app_terminal_and_names_hc_terminal_id
    DISPATCHERS.each_key do |name|
      _stdout, stderr, status = dispatch(name, "plan", "some-change")

      assert_equal(1, status.exitstatus, name)
      assert_match(/HC_TERMINAL_ID/, stderr, name)
    end
    assert_empty(calls)
  end

  def test_each_dispatcher_refuses_a_herdr_pane_and_a_rex_block_and_names_hc_terminal_id
    [ { "HERDR_ENV" => "1" }, { RETIRED_SESSION => "S1" } ].each do |retired|
      DISPATCHERS.each_key do |name|
        _stdout, stderr, status = dispatch(name, "plan", "some-change", env: retired)

        assert_equal(1, status.exitstatus, "#{name} #{retired.keys.first}")
        assert_match(/HC_TERMINAL_ID/, stderr, name)
      end
    end
    assert_empty(calls)
  end

  private

  # herdr_app: true runs inside a herdr-app terminal, HC_TERMINAL_ID set in the child only.
  def dispatch(name, *arguments, herdr_app: false, env: {})
    environment = HerdrAppHarness::CLEARED_ENV.merge(
      "HC_TERMINAL_ID" => (herdr_app ? "t10" : nil), "COORDINATOR" => nil,
      "HERDR_APP_SCRIPTS_DIR" => @herdr_app_scripts, "STUB_LOG" => @log, "HOME" => @root
    ).merge(env)
    Open3.capture3(environment, File.join(BIN, name), *arguments)
  end

  def install_herdr_app_stub(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, <<~SH)
      #!/bin/sh
      printf 'herdr-app %s coordinator=%s\\n' "$*" "${HERDR_APP_COORDINATOR:-}" >> "$STUB_LOG"
    SH
    FileUtils.chmod(0o755, path)
  end

  def calls_with_coordinator
    File.exist?(@log) ? File.readlines(@log, chomp: true) : []
  end

  def calls
    calls_with_coordinator.map { |line| line.sub(/ coordinator=.*\z/, "") }
  end
end
