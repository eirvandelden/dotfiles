#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# The global fallback `rubocop/.rubocop.yml` lints every repo without its own RuboCop config.
# Plain Minitest has no `assert_not` or `assert_no_match`: those exist only in Rails'
# ActiveSupport::TestCase. So the fallback must neither report nor autocorrect `refute`,
# `refute_match` and `assert !` into them.
class RubocopFallbackTest < Minitest::Test
  FALLBACK_CONFIG = File.expand_path("../rubocop/.rubocop.yml", __dir__)
  FIXTURE_PATH = "test/sample_test.rb".freeze
  RAILS_ASSERTION_COPS = [ "Rails/RefuteMethods", "Rails/AssertNot" ].freeze
  PLAIN_ASSERTIONS = [ "refute(false)", "refute_match(/a/, \"b\")", "assert !false" ].freeze

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

  YARD_FIXTURE_PATH = "lib/sample.rb".freeze
  YARD_FIXTURE = <<~RUBY.freeze
    # @param name [String]
    class Sample
    end
  RUBY

  # The fixtures avoid endless methods: in CI no .ruby-version sits above the config, so RuboCop
  # parses as Ruby 2.7 and reports them as Lint/Syntax.
  RBS_FIXTURE_PATH = "lib/typed.rb".freeze
  RBS_COP_PATTERN = %r{\AStyle/RbsInline/}
  VALID_RBS_FIXTURE = <<~RUBY.freeze
    class Typed
      attr_reader :count #: Integer

      #: (Integer) -> String
      def label(count)
        count.to_s
      end

      #: (Integer) -> String
      def title(count)
        count.to_s
      end
    end
  RUBY

  PRIVATE_METHOD_FIXTURE = <<~RUBY.freeze
    class Greeter
      private

      def greet(name)
        name
      end
    end
  RUBY

  MIGRATION_PATH = "db/migrate/20260101000000_create_greetings.rb".freeze
  MIGRATION_FIXTURE = <<~RUBY.freeze
    class CreateGreetings < ActiveRecord::Migration[8.0]
      def change
        create_table :greetings
      end
    end
  RUBY

  def setup
    skip_unless_ci(MISSING_RUBOCOP_MESSAGE) unless RUBOCOP

    @project = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@project, "test"))
    File.write(fixture_file, PLAIN_MINITEST_FIXTURE)
  end

  def teardown
    FileUtils.rm_rf(@project) if @project
  end

  def test_fallback_reports_no_rails_assertion_offense_in_a_plain_minitest_file
    report = run_fallback

    assert_equal([ FIXTURE_PATH ], inspected_paths(report))
    assert_empty(cop_names(report) & RAILS_ASSERTION_COPS)
  end

  def test_fallback_autocorrect_leaves_refute_and_assert_bang_unchanged
    run_fallback("-a")

    corrected_lines = File.readlines(fixture_file, chomp: true).map(&:strip)

    PLAIN_ASSERTIONS.each { |assertion| assert_includes(corrected_lines, assertion) }
  end

  def test_fallback_reports_no_yard_cop
    write_fixture(YARD_FIXTURE_PATH, YARD_FIXTURE)

    report = run_fallback(path: YARD_FIXTURE_PATH)

    assert_empty(cop_names(report).grep(%r{\AYARD/}))
  end

  def test_fallback_reports_malformed_rbs_inline_type
    report = run_rbs_fixture("#: (Integer -> String\ndef label(count)\n  count.to_s\nend\n")

    assert_includes(cop_names(report), "Style/RbsInline/InvalidTypes")
  end

  def test_fallback_reports_rbs_inline_comment_without_colon_prefix
    report = run_rbs_fixture("# : (Integer) -> String\ndef label(count)\n  count.to_s\nend\n")

    assert_includes(cop_names(report), "Style/RbsInline/InvalidComment")
  end

  def test_fallback_accepts_valid_rbs_inline_signature
    report = run_rbs_fixture(VALID_RBS_FIXTURE)

    assert_empty(cop_names(report))
  end

  def test_fallback_autocorrect_keeps_valid_rbs_inline_signature
    run_rbs_fixture(VALID_RBS_FIXTURE, "-a")

    assert_equal(VALID_RBS_FIXTURE, File.read(File.join(@project, RBS_FIXTURE_PATH)))
  end

  def test_fallback_reports_public_method_without_signature
    report = run_rbs_fixture("class Greeter\n  def greet(name)\n    name\n  end\nend\n")

    assert_includes(cop_names(report), "Style/RbsInline/MissingTypeAnnotation")
  end

  def test_fallback_accepts_an_unannotated_private_method
    report = run_rbs_fixture(PRIVATE_METHOD_FIXTURE)

    assert_empty(cop_names(report))
  end

  def test_fallback_reports_untyped_data_and_struct_attributes
    report = run_rbs_fixture("Point = Data.define(:x, :y)\nPair = Struct.new(:left, :right)\n")

    assert_includes(cop_names(report), "Style/RbsInline/MissingDataClassAnnotation")
    assert_includes(cop_names(report), "Style/RbsInline/MissingStructClassAnnotation")
  end

  def test_fallback_reports_a_leftover_rbs_inline_magic_comment
    report = run_rbs_fixture("# rbs_inline: enabled\n\n#{VALID_RBS_FIXTURE}")

    assert_includes(cop_names(report), "Style/RbsInline/RequireRbsInlineComment")
  end

  def test_fallback_skips_a_file_that_opts_out
    report = run_rbs_fixture("# rbs_inline: disabled\n\nclass Greeter\n  def greet(name)\n    name\n  end\nend\n")

    assert_empty(cop_names(report).grep(RBS_COP_PATTERN))
  end

  def test_fallback_does_not_demand_a_signature_in_a_nested_test_folder
    report = run_with_project_fallback("tools/test/greeter_test.rb", "class Greeter\n  def greet(name)\n    name\n  end\nend\n")

    assert_empty(cop_names(report).grep(RBS_COP_PATTERN))
  end

  def test_fallback_does_not_demand_a_signature_on_a_migration
    report = run_with_project_fallback(MIGRATION_PATH, MIGRATION_FIXTURE)

    assert_equal([ MIGRATION_PATH ], inspected_paths(report))
    assert_empty(cop_names(report).grep(RBS_COP_PATTERN))
  end

  def test_fallback_leaves_nodoc_comment_alone
    report = run_rbs_fixture("# :nodoc:\nclass Hidden\nend\n")

    assert_empty(cop_names(report).grep(RBS_COP_PATTERN))
  end

  private

  def run_rbs_fixture(source, *options)
    write_fixture(RBS_FIXTURE_PATH, source)
    run_fallback(*options, path: RBS_FIXTURE_PATH)
  end

  # Copies the fallback into the temporary project as .rubocop.yml and lints with it there.
  # The fallback's Exclude globs resolve against the directory that holds it, as `~/.rubocop.yml` does.
  def run_with_project_fallback(path, source)
    write_fixture(path, source)
    FileUtils.cp(FALLBACK_CONFIG, File.join(@project, ".rubocop.yml"))
    stdout, stderr, status = Open3.capture3(RUBOCOP, "--format", "json", path, chdir: @project)
    skip_unless_ci("rubocop could not load #{FALLBACK_CONFIG}: #{stderr.lines.first}") if status.exitstatus == 2

    assert_empty(stderr)
    JSON.parse(stdout)
  end

  def write_fixture(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@project, path)))
    File.write(File.join(@project, path), content)
  end

  def fixture_file
    File.join(@project, FIXTURE_PATH)
  end

  def skip_unless_ci(message)
    ENV["CI"] ? flunk(message) : skip(message)
  end

  def inspected_paths(report)
    report.fetch("files").map { |file| file.fetch("path") }
  end

  def cop_names(report)
    report.fetch("files").flat_map { |file| file.fetch("offenses") }.map { |offense| offense.fetch("cop_name") }
  end

  # Exit status 1 means offenses were found, which is the behaviour under test and must never
  # skip. Only status 2, RuboCop failing to load the config or its plugins, skips, and only
  # outside CI, since CI installs RuboCop and its plugins. Anything on stderr otherwise, such as a
  # cop crashing, fails.
  def run_fallback(*options, path: FIXTURE_PATH)
    stdout, stderr, status = Open3.capture3(
      RUBOCOP, "-c", FALLBACK_CONFIG, "--format", "json", *options, path, chdir: @project
    )
    skip_unless_ci("rubocop could not load #{FALLBACK_CONFIG}: #{stderr.lines.first}") if status.exitstatus == 2

    assert_empty(stderr)
    JSON.parse(stdout)
  end
end
