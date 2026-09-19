#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# The core values hook re-injects a handful of behavioral rules on SessionStart
# ("full" mode) and on every UserPromptSubmit ("motto" mode), so they survive
# context compaction the way CLAUDE.md does not. A hook whose only job is to
# guarantee those rules are present must never go quiet about failing to do so.
class CoreValuesTest < Minitest::Test
  HOOK = File.expand_path("../claude/.claude/hooks/core-values.rb", __dir__)

  def setup
    @home = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@home, ".claude"))
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_full_mode_prints_the_motto_and_every_section
    write_config(<<~YAML)
      ---
      motto: "Plan first."
      sections:
        workflow:
          - "Never write code before a plan."
    YAML

    stdout, stderr, status = run_hook("full")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes(stdout, "Plan first.")
    assert_includes(stdout, "workflow:")
    assert_includes(stdout, "Never write code before a plan.")
  end

  def test_motto_mode_prints_only_the_motto
    write_config(<<~YAML)
      ---
      motto: "Plan first."
      sections:
        workflow:
          - "Never write code before a plan."
    YAML

    stdout, stderr, status = run_hook("motto")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes(stdout, "Plan first.")
    assert_nil(stdout[/workflow:/])
  end

  def test_output_names_itself_so_it_reads_as_a_rule_not_stray_text
    write_config(<<~YAML)
      ---
      motto: "Plan first."
      sections: {}
    YAML

    full_stdout, = run_hook("full")
    motto_stdout, = run_hook("motto")

    assert_match(/core values/i, full_stdout)
    assert_match(/core value/i, motto_stdout)
  end

  def test_a_missing_config_file_warns_instead_of_going_quiet
    stdout, stderr, status = run_hook("full")

    assert_equal(0, status.exitstatus)
    assert_empty(stdout)
    assert_match(/\S/, stderr)
  end

  def test_malformed_yaml_warns_instead_of_going_quiet
    write_config("motto: [unterminated")

    stdout, stderr, status = run_hook("full")

    assert_equal(0, status.exitstatus)
    assert_empty(stdout)
    assert_match(/\S/, stderr)
  end

  def test_a_config_that_is_not_a_mapping_warns_instead_of_going_quiet
    write_config("- just a list")

    stdout, stderr, status = run_hook("full")

    assert_equal(0, status.exitstatus)
    assert_empty(stdout)
    assert_match(/\S/, stderr)
  end

  def test_an_empty_sections_key_does_not_crash
    write_config(<<~YAML)
      ---
      motto: "Plan first."
      sections:
    YAML

    stdout, stderr, status = run_hook("full")

    assert_equal(0, status.exitstatus, stderr)
    assert_includes(stdout, "Plan first.")
  end

  def test_an_unknown_mode_warns_instead_of_going_quiet
    write_config(<<~YAML)
      ---
      motto: "Plan first."
    YAML

    stdout, stderr, status = run_hook("ful")

    assert_equal(0, status.exitstatus)
    assert_empty(stdout)
    assert_match(/\S/, stderr)
  end

  private

  def write_config(yaml)
    File.write(File.join(@home, ".claude", "core-values.yml"), yaml)
  end

  def run_hook(mode)
    Open3.capture3({ "HOME" => @home }, HOOK, mode)
  end
end
