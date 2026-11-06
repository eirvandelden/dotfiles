#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# sync-solunized-theme.sh copies the Solunized light and dark dist tables into the config between
# the BEGIN and END markers. Tests run it with fixture dist tables in a scratch HOME and the
# system PATH, so they exercise the system bash and awk.
class HerdrSyncSolunizedThemeTest < Minitest::Test
  SCRIPT = File.expand_path("../herdr/.config/herdr/scripts/sync-solunized-theme.sh", __dir__)
  REAL_CONFIG = File.expand_path("../herdr/.config/herdr/config.toml", __dir__)
  SYSTEM_PATH = "/usr/bin:/bin".freeze
  LIGHT = "[theme.custom.light]\naccent        = \"#111111\"\n".freeze
  DARK = "[theme.custom.dark]\naccent        = \"#222222\"\n".freeze
  BEGIN_MARKER = "# BEGIN solunized\n".freeze
  END_MARKER = "# END solunized\n".freeze

  def setup
    @home = Dir.mktmpdir
    @dist = File.join(@home, "Developer", "solunized", "dist", "herdr")
    FileUtils.mkdir_p(@dist)
    File.write(File.join(@dist, "solunized-light.toml"), LIGHT)
    File.write(File.join(@dist, "solunized-dark.toml"), DARK)
    @config = File.join(@home, "config.toml")
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_the_sync_writes_the_dist_tables_between_the_markers
    File.write(@config, fixture_config)

    _, stderr, status = run_script

    assert(status.success?, stderr)
    assert_equal("# top\n#{BEGIN_MARKER}#{LIGHT}\n#{DARK}#{END_MARKER}\n[ui]\npane_gaps = true\n", File.read(@config))
  end

  def test_a_second_run_leaves_the_config_byte_identical
    File.write(@config, fixture_config)
    run_script
    first = File.binread(@config)
    first_mtime = File.mtime(@config)

    sleep(0.05)
    _, stderr, status = run_script

    assert(status.success?, stderr)
    assert_equal(first, File.binread(@config))
    assert_equal(first_mtime, File.mtime(@config))
  end

  def test_an_edited_colour_is_put_back
    File.write(@config, fixture_config.sub("#stale", "#000000"))
    run_script
    run_script

    refute_includes(File.read(@config), "#000000")
    assert_includes(File.read(@config), "#111111")
  end

  def test_lines_outside_the_markers_are_kept
    real = File.read(REAL_CONFIG)
    File.write(@config, real)

    _, stderr, status = run_script

    assert(status.success?, stderr)
    assert_equal(outside_block(real), outside_block(File.read(@config)))
  end

  def test_a_symlinked_config_stays_a_link
    target = File.join(@home, "real.toml")
    File.write(target, fixture_config)
    File.symlink(target, @config)

    _, stderr, status = run_script

    assert(status.success?, stderr)
    assert(File.symlink?(@config))
    assert_includes(File.read(target), "#111111")
  end

  def test_a_missing_dist_table_leaves_the_config_unchanged
    File.write(@config, fixture_config)
    File.delete(File.join(@dist, "solunized-dark.toml"))

    _, stderr, status = run_script

    refute(status.success?)
    assert_includes(stderr, "sync-solunized-theme.sh: no dist table")
    assert_equal(fixture_config, File.read(@config))
  end

  def test_a_table_without_its_mode_header_is_refused
    File.write(@config, fixture_config)
    File.write(File.join(@dist, "solunized-light.toml"), "[theme.custom]\naccent = \"#111111\"\n")

    _, stderr, status = run_script

    refute(status.success?)
    assert_includes(stderr, "sync-solunized-theme.sh: not a light table")
    assert_equal(fixture_config, File.read(@config))
  end

  def test_a_missing_marker_is_refused
    original = fixture_config.sub(END_MARKER, "")
    File.write(@config, original)

    _, stderr, status = run_script

    refute(status.success?)
    assert_includes(stderr, "sync-solunized-theme.sh: expected one '# END solunized' line, found 0")
    assert_equal(original, File.read(@config))
  end

  def test_a_doubled_marker_is_refused
    original = fixture_config.sub(BEGIN_MARKER, BEGIN_MARKER * 2)
    File.write(@config, original)

    _, stderr, status = run_script

    refute(status.success?)
    assert_includes(stderr, "sync-solunized-theme.sh: expected one '# BEGIN solunized' line, found 2")
    assert_equal(original, File.read(@config))
  end

  def test_reversed_markers_are_refused
    original = "#{END_MARKER}#{LIGHT}#{BEGIN_MARKER}"
    File.write(@config, original)

    _, stderr, status = run_script

    refute(status.success?)
    assert_includes(stderr, "sync-solunized-theme.sh: '# END solunized' comes before '# BEGIN solunized'")
    assert_equal(original, File.read(@config))
  end

  def test_the_default_checkout_is_under_home
    File.write(@config, fixture_config)
    _, stderr, status = run_script

    assert(status.success?, stderr)
    assert_includes(File.read(@config), "#111111")
  end

  def test_an_argument_prints_the_usage
    File.write(@config, fixture_config)

    _, stderr, status = run_script("--now")

    refute(status.success?)
    assert_includes(stderr, "usage: sync-solunized-theme.sh")
    assert_equal(fixture_config, File.read(@config))
  end

  private

  def fixture_config
    "# top\n#{BEGIN_MARKER}[theme.custom.light]\naccent = \"#stale\"\n#{END_MARKER}\n[ui]\npane_gaps = true\n"
  end

  def outside_block(text)
    text.sub(/^# BEGIN solunized\n.*?^# END solunized\n/m, "")
  end

  def run_script(*args)
    env = { "HOME" => @home, "PATH" => SYSTEM_PATH, "HERDR_CONFIG_PATH" => @config, "SOLUNIZED_DIR" => nil }
    Open3.capture3(env, SCRIPT, *args)
  end
end
