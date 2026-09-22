#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Codex has no shared agent-definition format with Claude, so each Claude agent under
# claude/.claude/agents/<name>.md is compiled into a Codex codex/.codex/agents/<name>.toml —
# one source, a generated adapter (spec.md §3). This is the drift guard: every committed
# Codex agent must equal what the generator produces from the Claude source right now.
class CodexAgentGenerationTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  GENERATOR = File.join(REPO_ROOT, "bin/generate-codex-agents")
  CLAUDE_AGENTS = File.join(REPO_ROOT, "claude/.claude/agents")
  CODEX_AGENTS = File.join(REPO_ROOT, "codex/.codex/agents")

  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_a_read_only_agent_generates_a_read_only_sandboxed_toml
    claude_dir = write_fixture_agent("zubat", tools: "[Read, Grep, Glob, Bash]",
      description: "Read-only code locator.", body: "You find things. You do not change things.\n")
    codex_dir = File.join(@tmpdir, "codex")

    run_generator(claude_dir, codex_dir)

    toml = File.read(File.join(codex_dir, "zubat.toml"))

    assert_includes(toml, %(name = "zubat"))
    assert_includes(toml, %(description = "Read-only code locator."))
    assert_includes(toml, %(sandbox_mode = "read-only"))
    assert_includes(toml, "You find things. You do not change things.")
  end

  def test_an_editing_agent_generates_no_sandbox_restriction
    claude_dir = write_fixture_agent("implementer", tools: "[Read, Grep, Glob, Bash, Write, Edit]",
      description: "Makes failing tests pass.", body: "You make failing tests pass.\n")
    codex_dir = File.join(@tmpdir, "codex")

    run_generator(claude_dir, codex_dir)

    toml = File.read(File.join(codex_dir, "implementer.toml"))

    assert_not(toml.include?("sandbox_mode"))
  end

  def test_the_developer_instructions_carry_the_full_markdown_body
    claude_dir = write_fixture_agent("reviewer", tools: "[Read, Grep, Glob, Bash, Write]",
      description: "Reviews a branch.",
      body: "You review. You do not fix.\n\n## Job\n\nRead the diff.\n")
    codex_dir = File.join(@tmpdir, "codex")

    run_generator(claude_dir, codex_dir)

    toml = File.read(File.join(codex_dir, "reviewer.toml"))

    assert_includes(toml, "## Job")
    assert_includes(toml, "Read the diff.")
  end

  def test_every_committed_codex_agent_matches_what_the_generator_produces_now
    generated_dir = File.join(@tmpdir, "generated")

    run_generator(CLAUDE_AGENTS, generated_dir)

    Dir.children(CODEX_AGENTS).select { |name| name.end_with?(".toml") }.each do |file|
      committed = File.read(File.join(CODEX_AGENTS, file))
      freshly_generated = File.read(File.join(generated_dir, file))

      assert_equal(freshly_generated, committed, "#{file} is stale — re-run bin/generate-codex-agents")
    end
  end

  private

  def write_fixture_agent(name, tools:, description:, body:)
    dir = File.join(@tmpdir, "claude-#{name}")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{name}.md"), <<~MARKDOWN)
      ---
      name: #{name}
      description: #{description}
      tools: #{tools}
      ---

      #{body}
    MARKDOWN
    dir
  end

  def run_generator(claude_dir, codex_dir)
    _, stderr, status = Open3.capture3(GENERATOR, claude_dir, codex_dir)
    assert(status.success?, stderr)
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end
end
