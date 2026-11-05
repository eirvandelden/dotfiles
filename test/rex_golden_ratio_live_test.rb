#!/usr/bin/env ruby
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"

# Integration tests: the golden-ratio action and watcher against real Rex sessions. Each test makes
# throwaway sessions and kills them in teardown. They skip when no Rex server answers.
class RexGoldenRatioLiveTest < Minitest::Test
  LUA_DIR = File.expand_path("../rex/.config/rex", __dir__)
  WATCH = File.join(LUA_DIR, "golden_ratio_watch.lua")
  TARGET = 0.618
  TOLERANCE = 0.02

  def setup
    skip("rex is not on PATH") unless system("command -v rex >/dev/null 2>&1")
    skip("no Rex server answers") unless system("rex", "--autostart=false", "ls", out: File::NULL, err: File::NULL)
    @sessions = []
    @watchers = []
    @dir = Dir.mktmpdir("golden-ratio-live")
    @apply_script = File.join(@dir, "apply.lua")
    File.write(@apply_script, <<~LUA)
      package.path = "#{LUA_DIR}/?.lua;" .. package.path
      return require("golden_ratio_apply").apply()
    LUA
  end

  def teardown
    @watchers&.each { |pid| stop(pid) }
    @sessions&.each { |session| system("rex", "kill", session, out: File::NULL, err: File::NULL) }
    FileUtils.remove_entry(@dir) if @dir
  end

  def test_apply_gives_the_focused_pane_the_golden_width
    session, (_, middle, _) = three_panes
    rex("focus", "-s", session, middle)

    run_apply(session)

    assert_in_delta(TARGET, rect(session, middle)[2], TOLERANCE)
  end

  def test_apply_gives_a_nested_pane_the_golden_share_after_real_resizes
    session, (_, _, right) = three_panes
    nested = split(session, right, "below")

    run_apply(session)

    width, height = rect(session, nested).values_at(2, 3)
    assert_in_delta(TARGET, width, TOLERANCE, "width")
    assert_in_delta(TARGET, height, TOLERANCE, "height")
  end

  def test_apply_leaves_a_single_pane_unchanged
    session, block = new_session
    before = rects(session)

    run_apply(session)

    assert_equal(before, rects(session))
    assert_equal([ 0.0, 0.0, 1.0, 1.0 ], rect(session, block).map(&:to_f))
  end

  def test_apply_skips_a_zoomed_window
    session, (first, _, _) = three_panes
    rex("focus", "-s", session, first)
    rex("zoom", "-s", session, "-b", first, "--on")
    before = rects(session)

    run_apply(session)

    assert_equal(before, rects(session))
  end

  def test_the_watcher_resizes_after_a_focus_move
    session, (_, middle, _) = three_panes
    start_watcher

    rex("focus", "-s", session, middle)

    assert(wait_for { (rect(session, middle)[2] - TARGET).abs <= TOLERANCE }, watcher_report(session, middle))
  end

  def test_the_watcher_resizes_the_session_that_changed
    changed, (_, middle, _) = three_panes
    untouched, = three_panes
    untouched_before = rects(untouched)
    start_watcher

    rex("focus", "-s", changed, middle)

    assert(wait_for { (rect(changed, middle)[2] - TARGET).abs <= TOLERANCE }, watcher_report(changed, middle))
    assert_equal(untouched_before, rects(untouched))
  end

  def test_the_watcher_resizes_after_a_focus_move_ends_a_zoom
    session, (first, middle, _) = three_panes
    rex("focus", "-s", session, first)
    rex("zoom", "-s", session, "-b", first, "--on")
    start_watcher

    rex("focus", "-s", session, middle)

    assert(wait_for { (rect(session, middle)[2] - TARGET).abs <= TOLERANCE }, watcher_report(session, middle))
  end

  def test_the_watcher_makes_one_resize_round_per_focus_move
    session, (_, middle, _) = three_panes
    start_watcher
    rex("focus", "-s", session, middle)
    assert(wait_for { (rect(session, middle)[2] - TARGET).abs <= TOLERANCE }, watcher_report(session, middle))

    settled = revision(session)
    sleep(2.5)

    assert_equal(settled, revision(session), "the watcher kept resizing after the layout settled")
  end

  private

  def new_session
    name = "gr-test-#{Process.pid}-#{@sessions.size}"
    created = JSON.parse(rex("new", name, "--window", "T", "--json"))
    @sessions << created.fetch("session_id")
    [ created.fetch("session_id"), created.fetch("initial_windows").first.fetch("block_ids").first ]
  end

  def split(session, block, direction)
    out = rex("split", "-s", session, "-b", block, "--split=#{direction}", "--json", "--", "sh", "-c", "sleep 120")
    JSON.parse(out).fetch("block_ids").first
  end

  def three_panes
    session, first = new_session
    second = split(session, first, "right")
    third = split(session, second, "right")
    [ session, [ first, second, third ] ]
  end

  def run_apply(session)
    rex("do", "-s", session, @apply_script)
  end

  def start_watcher
    @watcher_log = File.join(@dir, "watcher.log")
    env = { "LUA_PATH" => "#{LUA_DIR}/?.lua;;" }
    @watchers << Process.spawn(env, "rex", "do", WATCH, "--all", "--autostart=false", "--for", "8s",
                               out: @watcher_log, err: @watcher_log)
    sleep(1.5)
  end

  def watcher_report(session, block)
    log = File.exist?(@watcher_log.to_s) ? File.read(@watcher_log) : ""
    "pane width #{rect(session, block)[2]}, not #{TARGET}; watcher output: #{log.strip}"
  end

  def stop(pid)
    Process.kill("TERM", pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def wait_for(timeout: 6)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      return true if yield

      sleep(0.2)
    end
    false
  end

  def rex(*args)
    stdout, stderr, status = Open3.capture3("rex", *args)
    raise("rex #{args.join(' ')} failed: #{stderr.strip}") unless status.success?

    stdout
  end

  def inspect_session(session)
    JSON.parse(rex("session", "inspect", session, "--json"))
  end

  def revision(session)
    inspect_session(session).fetch("revision")
  end

  def rects(session)
    leaves(tiled_layout(session)).to_h { |node| [ node.fetch("block_id"), node.fetch("rect").map(&:to_f) ] }
  end

  def rect(session, block)
    rects(session).fetch(block)
  end

  def tiled_layout(session)
    window = inspect_session(session).fetch("windows").first
    window.fetch("layers").find { |layer| layer["kind"] == "tiled" }.fetch("layout")
  end

  def leaves(node)
    return [ node ] if node.key?("block_id")

    leaves(node.dig("split", "before")) + leaves(node.dig("split", "after"))
  end
end
