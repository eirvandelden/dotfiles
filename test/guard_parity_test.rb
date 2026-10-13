#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require_relative "../claude/.claude/hooks/remote_matcher"
require_relative "isolated_git"

# The consent guard and the test guard run in both tools from one script each under
# claude/.claude/hooks/. Claude calls them from settings.json, Codex from the inline [hooks]
# table in its config.toml. Codex's rules/default.rules is the second layer under the hook:
# Codex appends an `allow` rule there on every "always allow" approval, and that cannot be
# turned off, so this test is what keeps an approval from quietly loosening a guarded command
# or leaking a machine path into this public repository.
class GuardParityTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  RULES = File.join(REPO_ROOT, "codex/.codex/rules/default.rules")
  CODEX_CONFIG = File.join(REPO_ROOT, "codex/.codex/config.toml")
  CLAUDE_SETTINGS = File.join(REPO_ROOT, "claude/.claude/settings.json")

  GUARDED_COMMANDS = [
    %w[git push --force], %w[git commit --no-verify], %w[git push --no-verify],
    %w[gh pr comment], %w[gh pr review], %w[gh issue comment],
    %w[kamal deploy], %w[kamal app exec], %w[cap deploy],
    %w[bundle install], %w[bundle i], %w[bin/bundle install], %w[bin/bundle i]
  ].freeze
  GEM_INSTALL_FORMS = [ %w[bundle install], %w[bundle i], %w[bin/bundle install], %w[bin/bundle i] ].freeze
  MACHINE_PATHS = %w[/Users/ /private/ /opt/ /Applications/].freeze

  def test_no_allow_rule_begins_with_a_guarded_command
    allow_patterns = rules.select { |rule| rule[:decision] == "allow" }.map { |rule| rule[:pattern] }

    GUARDED_COMMANDS.each do |guarded|
      offender = allow_patterns.find { |pattern| pattern.first(guarded.length) == guarded }
      assert_nil(offender, "an allow rule loosens the guarded #{guarded.join(' ')}: #{offender.inspect}")
    end
  end

  def test_every_guarded_command_has_a_prompt_or_forbidden_rule_under_the_hook
    GUARDED_COMMANDS.each do |guarded|
      covered = rules.any? do |rule|
        rule[:decision] != "allow" && guarded.first(rule[:pattern].length) == rule[:pattern]
      end
      assert(covered, "no prompt or forbidden rule covers #{guarded.join(' ')}")
    end
  end

  def test_a_plain_force_push_is_forbidden_rather_than_prompted
    force_push = rules.find { |rule| rule[:pattern] == %w[git push --force] }

    assert_equal("forbidden", force_push&.fetch(:decision))
  end

  def test_gem_install_forms_are_forbidden_for_codex
    GEM_INSTALL_FORMS.each do |form|
      rule = rules.find { |candidate| candidate[:pattern] == form }

      assert_equal("forbidden", rule&.fetch(:decision), "no forbidden rule for #{form.join(' ')}")
    end
  end

  def test_non_install_bundler_commands_are_not_forbidden_for_codex
    [ %w[bundle exec rake], %w[bundle update rails], %w[bundle show] ].each do |command|
      forbidding = rules.select do |rule|
        rule[:decision] == "forbidden" && command.first(rule[:pattern].length) == rule[:pattern]
      end

      assert_empty(forbidding, "a forbidden rule also catches #{command.join(' ')}")
    end
  end

  def test_no_rule_names_a_machine_path
    leaking = File.readlines(RULES).grep_v(/\A\s*#/).select { |line| MACHINE_PATHS.any? { |path| line.include?(path) } }

    assert_empty(leaking, "rules name a machine path")
  end

  def test_codex_runs_the_same_consent_guard_command_as_claude_for_shell_commands
    assert_same_hook(claude_hook("Bash", "consent-guard.rb"), codex_hook("^Bash$", "consent-guard.rb"), "^Bash$")
  end

  def test_codex_runs_the_same_test_guard_command_as_claude_for_file_edits
    assert_same_hook(claude_hook("Edit|Write|MultiEdit", "test-guard.rb"), codex_hook("^apply_patch$", "test-guard.rb"), "^apply_patch$")
  end

  def test_codex_runs_the_same_worktree_guard_command_as_claude_for_shell_commands
    assert_same_hook(claude_hook("Bash", "worktree-guard.rb"), codex_hook("^Bash$", "worktree-guard.rb"), "^Bash$")
  end

  def test_codex_routes_approvals_to_the_automatic_reviewer
    assert_equal("auto_review", codex_setting("approvals_reviewer"))
  end

  def test_codex_still_approves_on_request_in_the_workspace_write_sandbox
    assert_equal("on-request", codex_setting("approval_policy"))
    assert_equal("workspace-write", codex_setting("sandbox_mode"))
  end

  # Reads the private allowlist that dotfiles-work installs. Without that file the list is empty and
  # this passes vacuously, so it only proves something on a machine that has the file.
  def test_codex_config_and_rules_name_no_work_owner
    committed = [ CODEX_CONFIG, RULES ].map { |path| File.read(path).downcase }.join("\n")

    allowlist_owners.each do |owner|
      refute_includes(committed, owner, "the Codex config or rules name the work owner #{owner}")
    end
  end

  private

  def assert_same_hook(claude_command, codex_command, matcher)
    refute_nil(claude_command, "claude/.claude/settings.json has no PreToolUse hook for that script")
    refute_nil(codex_command, "codex/.codex/config.toml has no [[hooks.PreToolUse]] entry with matcher #{matcher}")
    assert_equal(claude_command, codex_command)
  end

  # Every prefix_rule as { pattern:, decision: }. The rules language is not JSON, but its rules only use
  # string lists, which read as JSON.
  def rules
    @rules ||= File.read(RULES).scan(/prefix_rule\(\s*pattern\s*=\s*(\[.*?\])\s*,\s*decision\s*=\s*"(\w+)"/m)
                   .map { |pattern, decision| { pattern: JSON.parse(pattern), decision: decision } }
  end

  def claude_hook(matcher, script)
    entry = JSON.parse(File.read(CLAUDE_SETTINGS)).dig("hooks", "PreToolUse").find { |hook| hook["matcher"] == matcher }
    entry.fetch("hooks").map { |hook| hook["command"] }.find { |command| command.include?(script) }
  end

  # The command naming this script in the inline [[hooks.PreToolUse]] entry with this matcher. The entry can hold
  # several commands. Codex runs it through a shell, so the same "$HOME/..." string Claude uses expands the same way.
  def codex_hook(matcher, script)
    entries = File.read(CODEX_CONFIG).split(/^\[\[hooks\.PreToolUse\]\]\n/).drop(1)
    entry = entries.find { |text| text[/^matcher = "(.*)"$/, 1] == matcher }
    entry && entry.scan(/^command = '(.*)'$/).flatten.find { |command| command.include?(script) }
  end

  def codex_setting(key)
    File.read(CODEX_CONFIG)[/^#{key} = "(.*)"$/, 1]
  end

  def allowlist_owners
    path = File.expand_path(RemoteMatcher::ALLOWLIST_FILE)
    return [] unless File.exist?(path)

    File.readlines(path, chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
        .map { |entry| entry.split("/").first.downcase }
  end
end
