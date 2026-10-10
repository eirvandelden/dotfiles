#!/usr/bin/env ruby
require "minitest/autorun"

# Home Assistant's MCP server sits behind a gate that wants a bearer token. Codex reads the
# token from HA_MCP_GATE_TOKEN through its config; Claude gets it from a one-time
# `claude mcp add` command documented in HEADROOM.md. Both files are read as text: Ruby has
# no TOML parser in its standard library, and a gem would be a new dependency.
class HomeAssistantMcpTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  CODEX_CONFIG = File.join(REPO_ROOT, "codex/.codex/config.toml")
  HEADROOM = File.join(REPO_ROOT, "claude/.claude/HEADROOM.md")
  URL = "http://ha-mcp.home.arpa/mcp".freeze

  def test_codex_reaches_home_assistant_through_the_gate_with_the_unlocked_token
    table = codex_table("mcp_servers.homeassistant")

    assert_match setting("url", URL), table
    assert_match setting("bearer_token_env_var", "HA_MCP_GATE_TOKEN"), table
  end

  def test_codex_asks_before_every_home_assistant_tool_that_is_not_read_only
    assert_match setting("default_tools_approval_mode", "writes"), codex_table("mcp_servers.homeassistant")
  end

  def test_no_home_assistant_tool_skips_the_approval_prompt
    tool_tables = codex_tables.select { |name, _| name.start_with?("mcp_servers.homeassistant.tools.") }

    tool_tables.each do |name, body|
      refute_match setting("approval_mode", "approve"), body, "#{name} never asks before it runs"
    end
  end

  def test_headroom_registers_home_assistant_for_claude_with_the_token_left_unexpanded
    section = headroom_section_naming("homeassistant")
    command = "claude mcp add --scope user --transport http homeassistant #{URL} \\\n" \
              "  --header 'Authorization: Bearer ${HA_MCP_GATE_TOKEN}'"

    assert_includes section, command
  end

  def test_headroom_says_to_unlock_before_starting_claude_for_home_assistant
    section = headroom_section_naming("homeassistant")

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

  def headroom_section_naming(name)
    File.read(HEADROOM).split(/^(?=### )/).find { |section| section.lines.first.include?(name) } ||
      flunk("HEADROOM.md has no ### section naming #{name}")
  end
end
