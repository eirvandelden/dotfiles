#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require_relative "isolated_git"

# herdr and Rex run side by side, so the Claude hooks and the Codex rules for both tools must stay
# in their files. The herdr literals below are copied from the base branch (rex-agent-switcher).
class AgentCoexistenceConfigTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SETTINGS = File.join(ROOT, "claude/.claude/settings.json")
  RULES = File.join(ROOT, "codex/.codex/rules/default.rules")

  HERDR_TITLE = "sh '/Users/etienne.vandelden/.claude/hooks/herdr-claude-session-title.sh'".freeze
  HERDR_STATE = "bash '/Users/etienne.vandelden/.claude/hooks/herdr-agent-state.sh' session".freeze
  # event => [matcher or nil, command]
  HERDR_HOOKS = [
    [ "SessionStart", "*", HERDR_TITLE ],
    [ "SessionStart", "^(startup|resume|clear|compact|fork)$", HERDR_STATE ],
    [ "UserPromptSubmit", nil, HERDR_TITLE ],
    [ "Stop", nil, HERDR_TITLE ]
  ].freeze
  REX_GUARD = %q([ "${HERDR_ENV:-}" = 1 ] ||).freeze
  TONES = { "SessionStart" => "ready", "Notification" => "request", "Stop" => "done" }.freeze

  HERDR_RULES = [
    %w[herdr agent list], %w[herdr agent prompt], %w[herdr agent start], %w[herdr pane capture],
    %w[herdr pane list], %w[herdr pane read], %w[herdr pane send-keys], %w[herdr pane split],
    %w[herdr worktree create]
  ].freeze
  REX_RULES = [
    %w[rex split], %w[rex block ls], %w[rex send], %w[rex send-key], %w[rex capture],
    %w[rex block rename], %w[rex block close]
  ].freeze

  def test_settings_keep_every_herdr_hook_command_and_matcher
    HERDR_HOOKS.each do |event, matcher, command|
      entry = hook_entries(event).find { |candidate| candidate[:command] == command && candidate[:matcher] == matcher }

      refute_nil(entry, "#{event} lost its herdr hook #{command} (matcher #{matcher.inspect}): #{hook_entries(event).inspect}")
    end
  end

  def test_settings_add_guarded_rex_hooks
    start = hook_entries("SessionStart").find { |entry| entry[:command].include?("rex __internal session-start --agent claude") }

    refute_nil(start, "no Rex session-start hook")
    assert_includes(start[:command], REX_GUARD)
    assert_operator(start[:command].index(REX_GUARD), :<, start[:command].index("rex __internal"))
    TONES.each do |event, tone|
      commands = hook_entries(event).map { |entry| entry[:command] }
      assert(commands.any? { |command| command.match?(%r{play-tone\.sh #{tone}\b}) }, "#{event} has no #{tone} tone: #{commands.inspect}")
    end
  end

  def test_codex_rules_keep_herdr_entries_and_add_rex_entries
    rules = File.read(RULES)

    (HERDR_RULES + REX_RULES).each do |pattern|
      assert_includes(rules, %(prefix_rule(pattern=[#{pattern.map { |word| %("#{word}") }.join(', ')}], decision="allow")), pattern.join(" "))
    end
  end

  private

  def hook_entries(event)
    JSON.parse(File.read(SETTINGS)).dig("hooks", event).flat_map do |entry|
      entry["hooks"].map { |hook| { matcher: entry["matcher"], command: hook["command"].to_s } }
    end
  end
end
