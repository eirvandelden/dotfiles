#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

# mermaid-show renders Mermaid as Unicode text (through a Node helper around beautiful-mermaid)
# or as an image (mmdc, then timg). The tests put stub node, mmdc and timg on PATH that log
# their arguments, the way editor_test.rb stubs its binaries.
class MermaidShowTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(REPO_ROOT, "agents/.agents/skills/diagrams/scripts/mermaid-show")
  DIAGRAM = "classDiagram\n  Card --> Closure\n"

  def setup
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log = File.join(@tmpdir, "invocations.log")
    FileUtils.mkdir_p(@bin_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_prints_a_diagram_as_text
    stub_node
    path = write("card.mmd", DIAGRAM)

    result = run_script(path)

    assert_predicate(result[:status], :success?, result[:stderr])
    assert_includes(result[:stdout], "TEXT-DIAGRAM")
    assert_match(/^node /, logged)
  end

  def test_prints_each_fence_of_a_md_file
    stub_node
    path = write("plan.md", "# Plan\n\n```mermaid\n#{DIAGRAM}```\n\ntext\n\n```mermaid\nerDiagram\n  A ||--o{ B : has\n```\n")

    result = run_script(path)

    assert_predicate(result[:status], :success?, result[:stderr])
    assert_equal(2, result[:stdout].scan("TEXT-DIAGRAM").length)
  end

  def test_markdown_mode_replaces_only_mermaid_fences
    stub_node
    markdown = "# Title\n\nSome *prose*.\n\n```mermaid\n#{DIAGRAM}```\n\n```ruby\nputs 1\n```\n"

    result = run_script("--markdown", stdin: markdown)

    assert_predicate(result[:status], :success?, result[:stderr])
    refute_includes(result[:stdout], "mermaid")
    assert_includes(result[:stdout], "TEXT-DIAGRAM")
    assert_includes(result[:stdout], "```ruby\nputs 1\n```\n")
  end

  def test_markdown_mode_leaves_everything_but_mermaid_fences_alone
    stub_node
    markdown = "# Title\n\n  trailing  \n\n| a | b |\n|---|---|\n\n~~~ruby\nnot a mermaid fence\n~~~\n\n- item\n\n```sh\necho hi\n```\n"

    result = run_script("--markdown", stdin: markdown)

    assert_predicate(result[:status], :success?, result[:stderr])
    assert_equal(markdown, result[:stdout])
    refute_match(/^node /, logged)
  end

  def test_markdown_mode_renders_an_indented_fence_and_keeps_its_indent
    stub("node", "cat")
    markdown = "- item\n\n  ```mermaid\n  classDiagram\n    Card --> Closure\n  ```\n"

    result = run_script("--markdown", stdin: markdown)

    assert_predicate(result[:status], :success?, result[:stderr])
    assert_equal("- item\n\n  ```text\n  classDiagram\n    Card --> Closure\n  ```\n", result[:stdout])
  end

  def test_a_backtick_line_with_a_backtick_in_its_info_string_opens_no_fence
    stub_node
    markdown = "```foo```\n\n```mermaid\n#{DIAGRAM}```\n"

    result = run_script("--markdown", stdin: markdown)

    assert_predicate(result[:status], :success?, result[:stderr])
    assert_equal("```foo```\n\n```text\nTEXT-DIAGRAM\n```\n", result[:stdout])
  end

  def test_markdown_mode_renders_a_tilde_fence
    stub_node
    markdown = "~~~mermaid\n#{DIAGRAM}~~~\n"

    result = run_script("--markdown", stdin: markdown)

    assert_predicate(result[:status], :success?, result[:stderr])
    assert_equal("```text\nTEXT-DIAGRAM\n```\n", result[:stdout])
  end

  def test_image_mode_calls_mmdc_then_timg
    stub_mmdc
    stub_timg
    path = write("card.mmd", DIAGRAM)

    result = run_script("--image", path)

    assert_predicate(result[:status], :success?, result[:stderr])
    commands = logged.lines.map { |line| line.split.first }
    assert_equal(%w[mmdc timg], commands)
    assert_match(/^timg .*\.png/, logged)
  end

  def test_a_missing_beautiful_mermaid_prints_the_install_hint_and_exits_1
    stub("node", "echo 'stack trace' >&2; exit 3")
    path = write("card.mmd", DIAGRAM)

    result = run_script(path)

    assert_equal(1, result[:status].exitstatus)
    assert_equal("mermaid-show needs beautiful-mermaid: npm install -g beautiful-mermaid", result[:stderr].strip)
  end

  def test_a_diagram_the_renderer_rejects_shows_its_error_without_the_install_hint
    stub("node", "echo 'Parse error on line 2' >&2; exit 1")
    path = write("card.mmd", DIAGRAM)

    result = run_script(path)

    assert_equal(1, result[:status].exitstatus)
    assert_includes(result[:stderr], "Parse error on line 2")
    refute_includes(result[:stderr], "npm install -g beautiful-mermaid")
  end

  def test_a_rejected_diagram_reports_the_error_line_and_names_the_fence_without_a_stack_trace
    stub("node", "echo 'Error: Parse error on line 2' >&2; echo '    at parse (file.js:1:1)' >&2; exit 1")
    markdown = "```mermaid\n#{DIAGRAM}```\n\n```mermaid\n#{DIAGRAM}```\n"

    result = run_script("--markdown", stdin: markdown)

    assert_equal(1, result[:status].exitstatus)
    assert_equal("mermaid-show: diagram 1: Error: Parse error on line 2\n", result[:stderr])
  end

  def test_a_missing_tool_is_named_with_its_install_command
    path = write("card.mmd", DIAGRAM)
    stub_mmdc
    { [ path ] => "node", [ "--image", path ] => "mmdc" }.each do |args, tool|
      File.delete(File.join(@bin_dir, tool)) if File.exist?(File.join(@bin_dir, tool))

      result = run_script(*args, only_stubs: true)

      assert_equal(1, result[:status].exitstatus)
      assert_match(/^mermaid-show needs #{tool}: /, result[:stderr])
      refute_match(/Errno|\.rb:\d+/, result[:stderr])
    end
  end

  def test_a_missing_timg_is_named_with_its_install_command
    stub_mmdc
    path = write("card.mmd", DIAGRAM)

    result = run_script("--image", path, only_stubs: true)

    assert_equal(1, result[:status].exitstatus)
    assert_equal("mermaid-show needs timg: brew install timg", result[:stderr].strip)
  end

  def test_an_unknown_flag_prints_usage_and_exits_2
    result = run_script("--bogus")

    assert_equal(2, result[:status].exitstatus)
    assert_match(/usage/i, result[:stdout] + result[:stderr])
  end

  def test_every_method_has_an_inline_signature
    flunk("#{SCRIPT} does not exist") unless File.exist?(SCRIPT)
    lines = File.readlines(SCRIPT)

    lines.each_with_index do |line, index|
      next unless line.match?(/^\s*def /)

      assert(comment_block_above(lines, index).any? { |text| text.start_with?("#:") },
             "#{line.strip} has no inline RBS signature")
    end
  end

  private

  def comment_block_above(lines, index)
    lines[0...index].reverse.take_while { |line| line.strip.start_with?("#") }.map(&:strip)
  end

  def stub_node
    stub("node", %(cat > /dev/null; echo "TEXT-DIAGRAM"))
  end

  def stub_mmdc
    stub("mmdc", <<~SH)
      while [ $# -gt 0 ]; do
        if [ "$1" = "-o" ] || [ "$1" = "--output" ]; then : > "$2"; fi
        shift
      done
    SH
  end

  def stub_timg
    stub("timg", "exit 0")
  end

  def stub(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, "#!/bin/sh\necho \"#{name} $*\" >> \"#{@log}\"\n#{body}\n")
    FileUtils.chmod(0o755, path)
  end

  def logged
    File.exist?(@log) ? File.read(@log) : ""
  end

  def write(name, content)
    path = File.join(@tmpdir, name)
    File.write(path, content)
    path
  end

  def run_script(*args, stdin: "", only_stubs: false)
    flunk("#{SCRIPT} does not exist") unless File.exist?(SCRIPT)
    rest = only_stubs ? "#{File.dirname(RbConfig.ruby)}:/usr/bin:/bin" : ENV.fetch("PATH")
    env = { "PATH" => "#{@bin_dir}:#{rest}", "HOME" => @tmpdir }
    stdout, stderr, status = Open3.capture3(env, SCRIPT, *args, stdin_data: stdin, chdir: @tmpdir)
    { stdout: stdout, stderr: stderr, status: status }
  end
end
