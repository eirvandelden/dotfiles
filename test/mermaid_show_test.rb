#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require "fileutils"
require "open3"
require "tmpdir"

# mermaid-show renders Mermaid as Unicode text (through a Node helper around beautiful-mermaid)
# or as an image (mmdc, then timg). The tests put stub node, mmdc and timg on PATH that log
# their arguments, the way editor_test.rb stubs its binaries.
class MermaidShowTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(REPO_ROOT, "claude/.claude/skills/diagrams/scripts/mermaid-show")
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
    markdown = "# Title\n\n  trailing  \n\n| a | b |\n|---|---|\n\n~~~mermaid\nnot a backtick fence\n~~~\n\n- item\n\n```sh\necho hi\n```\n"

    result = run_script("--markdown", stdin: markdown)

    assert_predicate(result[:status], :success?, result[:stderr])
    assert_equal(markdown, result[:stdout])
    refute_match(/^node /, logged)
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
    stub("node", "exit 1")
    path = write("card.mmd", DIAGRAM)

    result = run_script(path)

    assert_equal(1, result[:status].exitstatus)
    assert_includes(result[:stdout] + result[:stderr], "npm install -g beautiful-mermaid")
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

  def run_script(*args, stdin: "")
    flunk("#{SCRIPT} does not exist") unless File.exist?(SCRIPT)
    env = { "PATH" => "#{@bin_dir}:#{ENV.fetch("PATH")}", "HOME" => @tmpdir }
    stdout, stderr, status = Open3.capture3(env, SCRIPT, *args, stdin_data: stdin, chdir: @tmpdir)
    { stdout: stdout, stderr: stderr, status: status }
  end
end
