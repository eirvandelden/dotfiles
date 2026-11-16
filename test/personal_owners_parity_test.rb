#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require_relative "../claude/.claude/hooks/remote_matcher"
require_relative "isolated_git"

# The rule texts that define a personal repository name the same owners as
# RemoteMatcher::PERSONAL_OWNERS. Adding an owner there fails these until each text follows.
class PersonalOwnersParityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  TRUST_LABELS = [ "Source control", "Trusted repo", "Routine pushes" ].freeze

  def test_the_glossary_names_every_personal_owner
    entry = File.readlines(File.join(ROOT, "GLOSSARY.md")).find { |line| line.start_with?("- **Personal repository**") }

    assert_names_every_owner(entry)
  end

  def test_playbook_rule_19_and_7a_name_every_personal_owner
    lines = File.readlines(File.join(ROOT, "agents/.agents/PLAYBOOK.md"))

    assert_names_every_owner(lines.find { |line| line.include?("Agents may push without asking") })
    assert_names_every_owner(lines.find { |line| line.start_with?("Applies only when `origin`") })
  end

  def test_the_settings_trust_lines_name_every_personal_owner
    lines = JSON.parse(File.read(File.join(ROOT, "claude/.claude/settings.json"))).dig("autoMode", "environment")

    TRUST_LABELS.each do |label|
      assert_names_every_owner(lines.find { |line| line.start_with?("**#{label}**") })
    end
  end

  private

  def assert_names_every_owner(line)
    refute_nil(line)
    RemoteMatcher::PERSONAL_OWNERS.each do |owner|
      assert_match(%r{(?<![\w-])#{Regexp.escape(owner)}(?![\w-])}, line, owner)
    end
  end
end
