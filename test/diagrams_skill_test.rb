#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require "open3"

# The diagrams skill tells an agent how to draw the "before" picture and how to show a diagram
# in the terminal.
class DiagramsSkillTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  PACKAGES_CONF = File.join(ROOT, "packages.conf")

  def test_the_before_erd_comes_from_rails_erd_or_schema_rb
    text = diagrams_skill

    assert_includes(text, "rails-erd")
    assert_includes(text, "Gemfile.lock")
    assert_includes(text, "bundle exec erd")
    assert_includes(text, "only=")
    assert_match(/\bask/i, text)
    assert_includes(text, "db/schema.rb")
    assert_includes(text, "erDiagram")
  end

  def test_packages_conf_declares_the_diagram_tools
    brew = bash_array("BREW")
    npm = bash_array("NPM_PACKAGES")

    assert_includes(brew, "mermaid-cli")
    assert_includes(brew, "timg")
    assert_includes(npm, "beautiful-mermaid")
  end

  private

  def diagrams_skill
    path = File.join(ROOT, "claude/.claude/skills/diagrams/SKILL.md")
    flunk("#{path} does not exist") unless File.exist?(path)
    File.read(path)
  end

  def bash_array(name)
    stdout, stderr, status = Open3.capture3(
      "bash", "-c", %(source "$0"; printf "%s\\n" "${#{name}[@]}"), PACKAGES_CONF
    )
    raise stderr unless status.success?

    stdout.split("\n")
  end
end
