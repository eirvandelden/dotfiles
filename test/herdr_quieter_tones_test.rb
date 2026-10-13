#!/usr/bin/env ruby
require "minitest/autorun"
require "digest"
require "fileutils"
require "open3"
require "tmpdir"

# herdr plays each notification tone at full level and has no volume setting. quieter-tones.sh
# writes a 0.3-level mp3 copy of each source tone into ~/Documents/Tones/herdr. Stub tests put a
# fake `ffmpeg` first on PATH and run anywhere; real tests need ffmpeg and skip without it.
class HerdrQuieterTonesTest < Minitest::Test
  SCRIPT = File.expand_path("../herdr/.config/herdr/scripts/quieter-tones.sh", __dir__)
  SYSTEM_PATH = "/usr/bin:/bin".freeze

  def setup
    @home = Dir.mktmpdir
    @stub_bin = Dir.mktmpdir
    @sources = Dir.mktmpdir
    @copies = File.join(@home, "Documents", "Tones", "herdr")
  end

  def teardown
    FileUtils.rm_rf([ @home, @stub_bin, @sources ])
  end

  def test_one_run_copies_every_source_given
    install_ffmpeg_stub
    first = source("jobs-done.mp3")
    second = source("ForTheMaster02.mp3")

    stdout, stderr, status = run_script(first, second)

    assert(status.success?, stderr)
    assert(File.exist?(File.join(@copies, "jobs-done.mp3")))
    assert(File.exist?(File.join(@copies, "ForTheMaster02.mp3")))
    assert_includes(stdout, File.join(@copies, "jobs-done.mp3"))
    assert_includes(stdout, File.join(@copies, "ForTheMaster02.mp3"))
  end

  def test_the_copy_keeps_the_source_file_name_in_the_herdr_tones_folder
    install_ffmpeg_stub

    stdout, = run_script(source("milord.mp3"))

    assert_equal("#{File.join(@copies, 'milord.mp3')}\n", stdout)
  end

  def test_ffmpeg_is_asked_for_three_tenths_volume_as_mp3
    install_ffmpeg_stub
    original = source("milord.mp3")

    run_script(original)

    call = ffmpeg_calls.first
    assert_includes(call, "volume=0.3")
    assert_includes(call, "libmp3lame")
    assert_equal(original, call[call.index("-i") + 1])
  end

  def test_the_copy_is_readable_like_an_ordinary_file
    install_ffmpeg_stub

    run_script(source("milord.mp3"))

    assert_equal(0o644, File.stat(File.join(@copies, "milord.mp3")).mode & 0o777)
  end

  def test_the_output_folder_is_created_when_missing
    install_ffmpeg_stub

    run_script(source("milord.mp3"))

    assert(File.directory?(@copies))
  end

  def test_no_arguments_prints_usage_and_fails
    install_ffmpeg_stub

    _, stderr, status = run_script

    assert_equal(1, status.exitstatus)
    assert_match(/usage/i, stderr)
  end

  def test_a_missing_source_is_refused_and_nothing_is_written
    install_ffmpeg_stub

    _, stderr, status = run_script(source("jobs-done.mp3"), File.join(@sources, "gone.mp3"))

    assert_equal(1, status.exitstatus)
    assert_match(/gone\.mp3/, stderr)
    refute(File.exist?(@copies))
  end

  def test_a_source_that_is_not_mp3_is_refused
    install_ffmpeg_stub

    _, stderr, status = run_script(source("tone.wav"))

    assert_equal(1, status.exitstatus)
    assert_match(/mp3/i, stderr)
    refute(File.exist?(@copies))
  end

  def test_a_source_inside_the_herdr_tones_folder_is_refused
    install_ffmpeg_stub
    FileUtils.mkdir_p(@copies)
    copy = File.join(@copies, "milord.mp3")
    File.write(copy, "copy")

    _, stderr, status = run_script(copy)

    assert_equal(1, status.exitstatus)
    assert_match(/copy|already/i, stderr)
    assert_empty(ffmpeg_calls)
  end

  def test_a_link_to_a_quieter_copy_is_refused
    install_ffmpeg_stub
    FileUtils.mkdir_p(@copies)
    copy = File.join(@copies, "milord.mp3")
    File.write(copy, "copy")
    link = File.join(@sources, "milord.mp3")
    FileUtils.ln_s(copy, link)

    _, stderr, status = run_script(link)

    assert_equal(1, status.exitstatus)
    assert_match(/copy|already/i, stderr)
    assert_equal("copy", File.read(copy))
  end

  def test_ffmpeg_is_told_to_overwrite_and_write_mp3_to_a_temporary_file
    install_ffmpeg_stub

    run_script(source("milord.mp3"))

    call = ffmpeg_calls.first
    assert_includes(call, "-y")
    assert_equal("mp3", call[call.index("-f") + 1])
    refute_equal(File.join(@copies, "milord.mp3"), call.last)
    assert_equal(@copies, File.dirname(call.last))
  end

  def test_a_failed_conversion_leaves_no_partial_copy
    install_ffmpeg_stub(fail: true)

    _, _, status = run_script(source("milord.mp3"))

    refute(status.success?)
    refute(File.exist?(File.join(@copies, "milord.mp3")))
  end

  def test_a_failed_conversion_keeps_an_existing_copy_unchanged
    install_ffmpeg_stub(fail: true)
    FileUtils.mkdir_p(@copies)
    File.write(File.join(@copies, "milord.mp3"), "earlier copy")

    run_script(source("milord.mp3"))

    assert_equal("earlier copy", File.read(File.join(@copies, "milord.mp3")))
  end

  def test_a_failed_conversion_leaves_no_temporary_file
    install_ffmpeg_stub(fail: true)

    run_script(source("milord.mp3"))

    assert_empty(Dir.children(@copies))
  end

  def test_a_missing_ffmpeg_is_reported
    FileUtils.ln_s(bash_path, File.join(@stub_bin, "bash"))

    _, stderr, status = run_script(source("milord.mp3"), path: @stub_bin)

    assert_equal(1, status.exitstatus)
    assert_match(/ffmpeg/i, stderr)
  end

  def test_the_copy_is_an_mp3
    skip("ffmpeg is not installed") unless ffmpeg_installed?
    original = sine_tone

    convert(original)

    codec, = Open3.capture2("ffprobe", "-v", "error", "-show_entries", "stream=codec_name",
                            "-of", "csv=p=0", File.join(@copies, "sine.mp3"))
    assert_equal("mp3", codec.strip)
  end

  def test_the_copy_is_three_tenths_of_the_source_level
    skip("ffmpeg is not installed") unless ffmpeg_installed?
    original = sine_tone

    convert(original)

    drop = mean_volume(File.join(@copies, "sine.mp3")) - mean_volume(original)
    assert_in_delta(20 * Math.log10(0.3), drop, 0.5)
  end

  def test_the_source_is_left_byte_for_byte_unchanged
    skip("ffmpeg is not installed") unless ffmpeg_installed?
    original = sine_tone
    before = Digest::SHA256.file(original).hexdigest

    convert(original)

    assert_equal(before, Digest::SHA256.file(original).hexdigest)
  end

  private

  def run_script(*arguments, path: "#{@stub_bin}:#{SYSTEM_PATH}")
    Open3.capture3({ "HOME" => @home, "PATH" => path }, SCRIPT, *arguments)
  end

  def convert(original)
    _, stderr, status = run_script(original, path: ENV.fetch("PATH"))
    assert(status.success?, stderr)
    assert(File.exist?(File.join(@copies, File.basename(original))), "no copy written")
  end

  def bash_path
    ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, "bash") }.find { |bash| File.executable?(bash) }
  end

  def source(name)
    File.join(@sources, name).tap { |path| File.write(path, "audio") }
  end

  def install_ffmpeg_stub(fail: false)
    stub = File.join(@stub_bin, "ffmpeg")
    File.write(stub, <<~BASH)
      #!/bin/bash
      printf '%s\\n' "$@" | paste -sd '\\t' - >> "#{@stub_bin}/calls"
      #{fail ? 'exit 1' : 'for last; do :; done; printf "quiet" > "$last"'}
    BASH
    FileUtils.chmod(0o755, stub)
  end

  def ffmpeg_calls
    log = File.join(@stub_bin, "calls")
    File.exist?(log) ? File.readlines(log, chomp: true).map { |line| line.split("\t") } : []
  end

  def sine_tone
    path = File.join(@sources, "sine.mp3")
    _, status = Open3.capture2e("ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi",
                                "-i", "sine=frequency=440:duration=2", "-c:a", "libmp3lame", path)
    flunk("could not make the test tone") unless status.success?
    path
  end

  def mean_volume(file)
    output, = Open3.capture2e("ffmpeg", "-hide_banner", "-i", file, "-af", "volumedetect", "-f", "null", "-")
    output[/mean_volume:\s*(-?[\d.]+) dB/, 1].to_f
  end

  def ffmpeg_installed?
    system("command -v ffmpeg >/dev/null 2>&1")
  end
end
