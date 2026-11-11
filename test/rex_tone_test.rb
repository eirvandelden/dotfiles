#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# play-tone.sh <ready|request|done> plays one quiet tone from ~/Documents/Tones/herdr/ with afplay. The
# tone files are the three mp3 copies the previous multiplexer package installed; a missing file is not an error. afplay
# is a stub on PATH that logs its arguments.
class RexToneTest < Minitest::Test
  SCRIPT = File.expand_path("../rex/.config/rex/scripts/play-tone.sh", __dir__)
  TONES = { "ready" => "ready-to-serve.mp3", "request" => "milord.mp3", "done" => "jobs-done.mp3" }.freeze

  def setup
    @home = Dir.mktmpdir
    @stub_bin = Dir.mktmpdir
    @tones = File.join(@home, "Documents/Tones/herdr")
    FileUtils.mkdir_p(@tones)
    TONES.each_value { |name| File.write(File.join(@tones, name), "tone") }
    install_afplay_stub
  end

  def teardown
    FileUtils.rm_rf([ @home, @stub_bin ])
  end

  def test_ready_plays_ready_to_serve
    assert_plays("ready", "ready-to-serve.mp3")
  end

  def test_request_plays_milord
    assert_plays("request", "milord.mp3")
  end

  def test_done_plays_jobs_done
    assert_plays("done", "jobs-done.mp3")
  end

  def test_a_terminal_outside_rex_plays_no_tone
    _, stderr, status = run_script("ready", env: { "REX_SESSION" => nil })

    assert_equal(0, status.exitstatus, stderr)
    refute(File.exist?(log), "afplay must not run outside Rex")
  end

  def test_missing_tone_file_exits_zero
    FileUtils.rm(File.join(@tones, "milord.mp3"))

    _, stderr, status = run_script("request")

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(afplay_calls)
  end

  def test_a_missing_tones_folder_exits_zero
    FileUtils.rm_rf(@tones)

    _, stderr, status = run_script("done")

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(afplay_calls)
  end

  def test_an_unknown_tone_plays_nothing
    run_script("bogus")

    assert_empty(afplay_calls)
  end

  def test_a_herdr_pane_plays_no_rex_tone
    TONES.each_key do |tone|
      _, stderr, status = run_script(tone, env: { "HERDR_ENV" => "1", "REX_SESSION" => "S1" })

      assert_equal(0, status.exitstatus, stderr)
    end

    assert_empty(afplay_calls)
  end

  def test_plays_nothing_in_a_herdr_app_terminal_with_a_leaked_rex_session
    TONES.each_key do |tone|
      _, stderr, status = run_script(tone, env: { "HC_TERMINAL_ID" => "t10", "REX_SESSION" => "S1" })

      assert_equal(0, status.exitstatus, stderr)
    end

    assert_empty(afplay_calls)
  end

  private

  def assert_plays(tone, file)
    _, stderr, status = run_script(tone)

    assert_equal(0, status.exitstatus, stderr)
    assert_equal([ File.join(@tones, file) ], afplay_calls.map { |call| call.split.last })
  end

  def run_script(*arguments, env: {})
    environment = HerdrAppHarness::CLEARED_ENV.merge("PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}", "HOME" => @home,
                                                     "AFPLAY_LOG" => log, "HERDR_ENV" => nil, "REX_SESSION" => "S1")
                                              .merge(env)
    Open3.capture3(environment, SCRIPT, *arguments)
  end

  def log
    File.join(@stub_bin, "afplay.log")
  end

  def afplay_calls
    File.exist?(log) ? File.readlines(log, chomp: true) : []
  end

  def install_afplay_stub
    stub = File.join(@stub_bin, "afplay")
    File.write(stub, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$AFPLAY_LOG\"\n")
    FileUtils.chmod(0o755, stub)
  end
end
