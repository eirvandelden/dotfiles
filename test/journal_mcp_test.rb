#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# The journal_administration app answers MCP requests behind a per-user bearer token. Codex reads
# the token from JOURNAL_ASSISTANT_TOKEN through its config; Claude gets it from a one-time
# `claude mcp add` command documented in MCP.md. Both files are read as text: Ruby has
# no TOML parser in its standard library, and a gem would be a new dependency.
class JournalMcpTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  CODEX_CONFIG = File.join(REPO_ROOT, "codex/.codex/config.toml")
  MCP_DOC = File.join(REPO_ROOT, "claude/.claude/MCP.md")
  URL = "http://finances.home.arpa/mcp".freeze

  def test_codex_declares_journal_with_its_url_and_token_variable
    table = codex_table("mcp_servers.journal")

    assert_match setting("url", URL), table
    assert_match setting("bearer_token_env_var", "JOURNAL_ASSISTANT_TOKEN"), table
  end

  def test_codex_runs_every_journal_tool_without_asking
    assert_match setting("default_tools_approval_mode", "approve"), codex_table("mcp_servers.journal")
  end

  def test_no_journal_tool_has_its_own_approval_override
    tool_tables = codex_tables.keys.select { |name| name.start_with?("mcp_servers.journal.tools.") }

    assert_empty tool_tables
  end

  def test_mcp_doc_registers_journal_for_claude_with_the_token_left_unexpanded
    section = mcp_doc_section_naming("journal")
    command = "claude mcp add --scope user --transport http journal #{URL} \\\n" \
              "  --header 'Authorization: Bearer ${JOURNAL_ASSISTANT_TOKEN}'"

    assert_includes section, command
  end

  def test_mcp_doc_says_to_unlock_before_starting_claude_for_journal
    section = mcp_doc_section_naming("journal")

    assert_match(/run `unlock` before `claude`/, section)
  end

  private

  # An active `key = "value"` line, at any spacing; a commented-out line does not match.
  def setting(key, value)
    /^\s*#{Regexp.escape(key)}\s*=\s*"#{Regexp.escape(value)}"/
  end

  def codex_table(name)
    codex_tables.fetch(name) { flunk "config.toml has no [#{name}] table" }
  end

  def codex_tables
    File.read(CODEX_CONFIG).split(/^(?=\[[^\]]+\]\s*$)/).each_with_object({}) do |chunk, tables|
      header = chunk[/\A\[([^\]]+)\]/, 1]
      tables[header] = chunk if header
    end
  end

  def mcp_doc_section_naming(name)
    File.read(MCP_DOC).split(/^(?=### )/).find { |section| section.lines.first.include?(name) } ||
      flunk("MCP.md has no ### section naming #{name}")
  end
end
