#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# The no-hardwrap markdownlint rule reports (or, in unwrap mode, fixes) a paragraph that source
# control hardwraps across several lines with a soft line break, so agents stop copying that
# habit from wrapped markdown they read. Runs the real markdownlint CLI against the committed
# rule and config files, the same way the pre-commit hook and the Claude PostToolUse hook do.
class NoHardwrapRuleTest < Minitest::Test
  PACKAGE_DIR = File.expand_path("../markdownlint/.config/markdownlint", __dir__)
  RULE_PATH = File.join(PACKAGE_DIR, "no-hardwrap.cjs")
  CHECK_CONFIG_PATH = File.join(PACKAGE_DIR, "no-hardwrap.json")
  UNWRAP_CONFIG_PATH = File.join(PACKAGE_DIR, "unwrap.json")
  GLOBAL_CONFIG_DIR = PACKAGE_DIR

  def self.locate_markdownlint
    found = `which markdownlint 2>/dev/null`.strip
    found unless found.empty?
  end

  MARKDOWNLINT = locate_markdownlint
  MISSING_MARKDOWNLINT_MESSAGE = "markdownlint not found on PATH (CI installs markdownlint-cli)"

  def setup
    skip(MISSING_MARKDOWNLINT_MESSAGE) unless MARKDOWNLINT

    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_paragraph_over_three_lines_is_reported_once_at_its_first_line
    _stdout, stderr, status = check(<<~MARKDOWN)
      This is line one
      and line two
      and line three.
    MARKDOWN

    assert_equal(1, status.exitstatus)
    assert_match(/:1 .*no-hardwrap.*join lines 1–3 into one line/, stderr)
  end

  def test_a_list_item_continuing_on_an_indented_line_is_reported
    _stdout, stderr, status = check(<<~MARKDOWN)
      - item one
        continues here
      - item two
    MARKDOWN

    assert_equal(1, status.exitstatus)
    assert_match(/:1 .*no-hardwrap.*join lines 1–2 into one line/, stderr)
  end

  def test_a_block_quote_over_two_lines_is_reported
    _stdout, stderr, status = check(<<~MARKDOWN)
      > line one
      > line two
    MARKDOWN

    assert_equal(1, status.exitstatus)
    assert_match(/:1 .*no-hardwrap.*join lines 1–2 into one line/, stderr)
  end

  def test_one_line_paragraphs_code_tables_headings_and_front_matter_are_not_reported
    _stdout, stderr, status = check(<<~MARKDOWN)
      ---
      title: front matter
      ---

      # Heading

      One line paragraph.

      ```
      long code line one
      long code line two
      ```

      | a | b |
      | - | - |
      | c | d |
    MARKDOWN

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_lines_joined_by_a_hard_line_break_are_not_reported
    _stdout, _stderr, status = check("line one\\\nline two\n")

    assert_equal(0, status.exitstatus)
  end

  def test_a_paragraph_mixing_a_hard_break_and_a_soft_wrap_is_reported
    trailing_spaces = " " * 2
    _stdout, stderr, status = check("line one#{trailing_spaces}\nline two\nline three\n")

    assert_equal(1, status.exitstatus)
    assert_match(/no-hardwrap/, stderr)
  end

  def test_unwrapping_a_three_line_paragraph_leaves_one_line_joined_by_single_spaces
    file = fix(<<~MARKDOWN)
      This is line one
      and line two
      and line three.
    MARKDOWN

    assert_equal("This is line one and line two and line three.\n", File.read(file))
  end

  def test_unwrapping_a_list_item_leaves_one_bullet_line_without_the_indentation
    file = fix(<<~MARKDOWN)
      - item one
        continues here
      - item two
    MARKDOWN

    assert_equal("- item one continues here\n- item two\n", File.read(file))
  end

  def test_a_nested_list_item_is_unwrapped_at_its_own_indentation
    file = fix(<<~MARKDOWN)
      - outer
        - inner item
          continues
    MARKDOWN

    assert_equal("- outer\n  - inner item continues\n", File.read(file))
  end

  def test_unwrapping_keeps_inline_markup_on_a_continuation_line
    file = fix("one two\nthree *bold* four `code` five\n")

    assert_equal("one two three *bold* four `code` five\n", File.read(file))
  end

  def test_unwrapping_keeps_an_indented_continuation_line
    file = fix("para one\n   indented two\n")

    assert_equal("para one indented two\n", File.read(file))
  end

  def test_unwrapping_a_block_quote_keeps_the_whole_second_line
    file = fix("> line one\n> line two *b* c\n")

    assert_equal("> line one line two *b* c\n", File.read(file))
  end

  def test_a_wrap_inside_emphasis_is_reported_and_unwrapped
    content = "one *bold\nspan* rest\n"
    _stdout, stderr, status = check(content)

    assert_equal(1, status.exitstatus)
    assert_match(/:1 .*no-hardwrap.*join lines 1–2 into one line/, stderr)
    assert_equal("one *bold span* rest\n", File.read(fix(content)))
  end

  def test_a_wrap_inside_a_link_label_is_reported_and_unwrapped
    content = "see [a link\ntext](http://x) end\n"
    _stdout, stderr, status = check(content)

    assert_equal(1, status.exitstatus)
    assert_match(/:1 .*no-hardwrap.*join lines 1–2 into one line/, stderr)
    assert_equal("see [a link text](http://x) end\n", File.read(fix(content)))
  end

  def test_a_hard_break_then_a_soft_wrap_reports_only_the_soft_run
    _stdout, stderr, _status = check("line one\\\nline two\nline three\n")

    assert_match(/:2 .*no-hardwrap.*join lines 2–3 into one line/, stderr)
    assert_no_match(/join lines 1–/, stderr)
  end

  def test_unwrapping_does_not_leave_a_double_space_after_trailing_whitespace
    file = fix("line one \nline two\n")

    assert_equal("line one line two\n", File.read(file))
  end

  def test_unwrapping_keeps_a_trailing_hard_break_at_the_end_of_a_run
    trailing_spaces = " " * 2
    file = fix("line one\nline two#{trailing_spaces}\nline three\n")

    assert_equal("line one line two#{trailing_spaces}\nline three\n", File.read(file))
  end

  def test_unwrapping_keeps_the_words_of_an_inline_html_comment
    file = fix("x <!-- one\ntwo three --> y\n")

    assert_equal("x <!-- one two three --> y\n", File.read(file))
  end

  def test_unwrapping_trims_trailing_spaces_inside_an_inline_html_comment
    trailing_spaces = " " * 2
    file = fix("x <!-- a#{trailing_spaces}\nb --> y\n")

    assert_equal("x <!-- a b --> y\n", File.read(file))
  end

  def test_unwrapping_a_footnote_definition_drops_its_continuation_indentation
    file = fix("[^1]: note one\n    note two\n")

    assert_equal("[^1]: note one note two\n", File.read(file))
  end

  def test_the_global_config_does_not_report_a_long_paragraph_line
    home = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(home, ".config"))
    File.symlink(GLOBAL_CONFIG_DIR, File.join(home, ".config", "markdownlint"))
    file = write_markdown("#{'A' * 300}\n")

    _stdout, stderr, _status = Open3.capture3({ "HOME" => home }, MARKDOWNLINT, file)

    assert_no_match(/MD013/, stderr)
  ensure
    FileUtils.rm_rf(home)
  end

  private

  def write_markdown(content)
    path = File.join(@dir, "test.md")
    File.write(path, content)
    path
  end

  def check(content)
    file = write_markdown(content)
    Open3.capture3(MARKDOWNLINT, "--config", CHECK_CONFIG_PATH, "--rules", RULE_PATH, file)
  end

  def fix(content)
    file = write_markdown(content)
    Open3.capture3(MARKDOWNLINT, "--config", UNWRAP_CONFIG_PATH, "--rules", RULE_PATH, "--fix", file)
    file
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end

  def assert_no_match(pattern, value, message = nil)
    assert_not(pattern.match?(value), message || "Expected #{value.inspect} not to match #{pattern.inspect}")
  end
end
