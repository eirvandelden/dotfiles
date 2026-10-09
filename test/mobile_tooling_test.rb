#!/usr/bin/env ruby
require "minitest/autorun"

# Claude registers MobileBuildMCP by a command in references/ios.md, Codex by a block in config.toml.
# The two must name the same pinned version and the same telemetry opt-out, so this guards the drift
# between them, as guard_parity_test.rb does for the guards (docs/changes/hotwire-native-agent-guidance/plan.md).
class MobileToolingTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  IOS_REFERENCE = File.join(REPO_ROOT, "claude/.claude/skills/hotwire-native/references/ios.md")
  CODEX_CONFIG = File.join(REPO_ROOT, "codex/.codex/config.toml")
  TELEMETRY_OFF = "MOBILEBUILDMCP_SENTRY_DISABLED"

  def test_claude_and_codex_pin_the_same_exact_mobilebuildmcp_version
    claude = versions(File.read(IOS_REFERENCE))
    codex = versions(codex_block)
    assert_equal(1, claude.uniq.length, "ios.md must name exactly one mobilebuildmcp version")
    assert_equal(claude.uniq, codex.uniq)
    assert_match(/\A\d+\.\d+\.\d+\z/, claude.first)
  end

  def test_no_mobilebuildmcp_registration_uses_latest
    refute_match(/mobilebuildmcp@latest/, File.read(IOS_REFERENCE))
    refute_match(/mobilebuildmcp@latest/, File.read(CODEX_CONFIG))
  end

  def test_both_registrations_disable_sentry_telemetry
    assert_includes(File.read(IOS_REFERENCE), "#{TELEMETRY_OFF}=true")
    assert_match(/#{TELEMETRY_OFF}\s*=\s*"true"/, codex_block)
  end

  def test_ios_setup_warns_that_a_live_session_rewrites_claude_json
    assert_match(/live Claude session rewrites `~\/\.claude\.json`/, File.read(IOS_REFERENCE))
  end

  private

  def versions(text)
    text.scan(/mobilebuildmcp@([\w.]+)/).flatten
  end

  def codex_block
    block = File.read(CODEX_CONFIG)[/^\[mcp_servers\.MobileBuildMCP\]\n.*?(?=^\[|\z)/m]
    assert(block, "config.toml has no [mcp_servers.MobileBuildMCP] block")
    block
  end
end
