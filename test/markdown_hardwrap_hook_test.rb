#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# Claude Code PostToolUse hook: after an Edit/Write/MultiEdit touches a Markdown file, tells
# Claude about any hardwrapped paragraph the no-hardwrap markdownlint rule finds, so the habit
# gets caught right after it's written rather than at commit time.
class MarkdownHardwrapHookTest < Minitest::Test
  HOOK = File.expand_path("../claude/.claude/hooks/markdown-hardwrap.rb", __dir__)
  PACKAGE_DIR = File.expand_path("../markdownlint/.config/markdownlint", __dir__)

  def self.locate_markdownlint_dir
    found = `which markdownlint 2>/dev/null`.strip
    File.dirname(found) unless found.empty?
  end

  MARKDOWNLINT_DIR = locate_markdownlint_dir
  MISSING_MARKDOWNLINT_MESSAGE = "markdownlint not found on PATH (CI installs markdownlint-cli)"

  def setup
    @dir = Dir.mktmpdir
    @home = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@home, ".config"))
    File.symlink(PACKAGE_DIR, File.join(@home, ".config", "markdownlint"))
  end

  def teardown
    FileUtils.rm_rf(@dir)
    FileUtils.rm_rf(@home)
  end

  def test_a_wrapped_markdown_file_tells_claude_the_file_line_and_fix
    skip(MISSING_MARKDOWNLINT_MESSAGE) unless MARKDOWNLINT_DIR

    file = write_markdown("wrapped.md", "This is line one\nand line two.\n")

    stdout, stderr, status = run_hook(file)

    assert_equal(0, status.exitstatus, stderr)
    output = JSON.parse(stdout)
    context = output.dig("hookSpecificOutput", "additionalContext")
    assert_equal("PostToolUse", output.dig("hookSpecificOutput", "hookEventName"))
    assert_includes(context, file)
    assert_includes(context, "line 1")
    assert_includes(context, "join lines 1–2 into one line")
    assert_includes(context, "--fix")
  end

  def test_a_clean_markdown_file_tells_claude_nothing
    skip(MISSING_MARKDOWNLINT_MESSAGE) unless MARKDOWNLINT_DIR

    file = write_markdown("clean.md", "One line paragraph.\n")

    stdout, stderr, status = run_hook(file)

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
  end

  def test_a_markdown_file_with_a_long_extension_or_upper_case_is_checked
    skip(MISSING_MARKDOWNLINT_MESSAGE) unless MARKDOWNLINT_DIR

    %w[wrapped.markdown WRAPPED.MD].each do |name|
      stdout, stderr, status = run_hook(write_markdown(name, "This is line one\nand line two.\n"))

      assert_equal(0, status.exitstatus, stderr)
      assert_includes(stdout, "join lines 1–2 into one line", name)
    end
  end

  def test_the_fix_command_quotes_a_path_with_a_space
    skip(MISSING_MARKDOWNLINT_MESSAGE) unless MARKDOWNLINT_DIR

    file = write_markdown("my notes.md", "This is line one\nand line two.\n")

    stdout, _stderr, _status = run_hook(file)

    context = JSON.parse(stdout).dig("hookSpecificOutput", "additionalContext")
    assert_includes(context, "--fix #{file.gsub(' ', '\\ ')}")
  end

  def test_a_non_markdown_file_is_not_checked
    file = write_markdown("notes.rb", "This is line one\nand line two.\n")

    stdout, stderr, status = run_hook(file)

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
  end

  def test_a_missing_file_tells_claude_nothing
    stdout, stderr, status = run_hook(File.join(@dir, "missing.md"))

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
  end

  def test_missing_markdownlint_tells_claude_nothing
    file = write_markdown("wrapped.md", "This is line one\nand line two.\n")

    stdout, stderr, status = run_hook(file, path: ruby_only_bin_dir)

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
  end

  def test_the_hook_always_exits_zero
    _stdout, _stderr, status = Open3.capture3({ "HOME" => @home }, HOOK, stdin_data: "not json")

    assert_equal(0, status.exitstatus)
  end

  private

  def write_markdown(name, content)
    path = File.join(@dir, name)
    File.write(path, content)
    path
  end

  # Only Ruby, so the hook cannot find markdownlint even where both live in one directory.
  def ruby_only_bin_dir
    bin_dir = File.join(@dir, "ruby-bin")
    FileUtils.mkdir_p(bin_dir)
    File.symlink(`which ruby`.strip, File.join(bin_dir, "ruby"))
    bin_dir
  end

  def run_hook(file_path, path: nil)
    payload = { "tool_input" => { "file_path" => file_path } }
    env = { "HOME" => @home }
    env["PATH"] = path if path
    Open3.capture3(env, HOOK, stdin_data: JSON.generate(payload))
  end
end
