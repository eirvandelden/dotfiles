#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# The global fallback `rubocop/.rubocop.yml` lints every repo without its own RuboCop config.
# Plain Minitest has no `assert_not` or `assert_no_match`: those exist only in Rails'
# ActiveSupport::TestCase. So the fallback must neither report nor autocorrect `refute`,
# `refute_match` and `assert !` into them.
class RubocopFallbackTest < Minitest::Test
  FALLBACK_CONFIG = File.expand_path("../rubocop/.rubocop.yml", __dir__)
  FIXTURE_PATH = "test/sample_test.rb".freeze
  RAILS_ASSERTION_COPS = %r{Rails/(RefuteMethods|AssertNot)}

  def self.locate_rubocop
    found = `which rubocop 2>/dev/null`.strip
    found unless found.empty?
  end

  RUBOCOP = locate_rubocop
  MISSING_RUBOCOP_MESSAGE = "rubocop not found on PATH, so the global fallback cannot be checked".freeze

  PLAIN_MINITEST_FIXTURE = <<~RUBY.freeze
    require "minitest/autorun"

    class SampleTest < Minitest::Test
      def test_sample
        refute(false)
        refute_match(/a/, "b")
        assert !false
      end
    end
  RUBY

  def setup
    skip(MISSING_RUBOCOP_MESSAGE) unless RUBOCOP

    @project = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@project, "test"))
    File.write(fixture_file, PLAIN_MINITEST_FIXTURE)
  end

  def teardown
    FileUtils.rm_rf(@project) if @project
  end

  def test_fallback_reports_no_rails_assertion_offense_in_a_plain_minitest_file
    offenses = run_fallback.lines.grep(RAILS_ASSERTION_COPS)

    assert_empty(offenses)
  end

  def test_fallback_autocorrect_leaves_refute_and_assert_bang_unchanged
    run_fallback("-a")

    assert_equal(PLAIN_MINITEST_FIXTURE, File.read(fixture_file))
  end

  private

  def fixture_file
    File.join(@project, FIXTURE_PATH)
  end

  # Exit status 1 means offenses were found, which is the behaviour under test and must never
  # skip. Only status 2, RuboCop failing to load the config or its plugins, skips.
  def run_fallback(*options)
    stdout, stderr, status = Open3.capture3(
      RUBOCOP, "-c", FALLBACK_CONFIG, "--format", "emacs", *options, FIXTURE_PATH, chdir: @project
    )
    skip("rubocop could not load #{FALLBACK_CONFIG}: #{stderr.lines.first}") if status.exitstatus == 2

    stdout
  end
end
