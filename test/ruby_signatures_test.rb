#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# Ruby documentation follows ruby-style: inline RBS signatures, never hand-written sig files.
class RubySignaturesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(ROOT, "claude/.claude/skills")
  YARD_ASK = /YARD-document|use YARD|@param\b|@return\b|@action\b|@route\b|YARD tags `@/

  def test_implement_and_object_oriented_design_defer_to_ruby_style
    %w[implement/SKILL.md object-oriented-design/SKILL.md].each do |relative|
      text = File.read(File.join(SKILLS, relative))

      assert_includes(text, "`ruby-style`", "#{relative} does not point at ruby-style")
      refute_match(YARD_ASK, text, "#{relative} states its own YARD rule")
    end
  end

  def test_ruby_style_asks_for_a_colon_signature_above_each_method
    section = File.read(File.join(SKILLS, "ruby-style/SKILL.md"))[/^## Documentation comments.*?(?=^## |\z)/m]

    assert_includes(section, "`#: (String) -> String`")
    refute_includes(section, "# @rbs")
  end

  def test_rails_architecture_and_plan_ask_for_colon_signatures_only
    %w[rails-architecture/SKILL.md plan/SKILL.md].each do |relative|
      text = File.read(File.join(SKILLS, relative))

      refute_match(/`#:` (or|and) `# @rbs`/, text, "#{relative} still offers `# @rbs` as a method signature")
    end
  end

  def test_ruby_style_forbids_hand_written_sig_files
    text = File.read(File.join(SKILLS, "ruby-style/SKILL.md"))

    assert_match(%r{never in a hand-written `sig/\*\.rbs` file}, text)
  end

  def test_design_templates_ask_for_a_class_summary_and_a_signature_per_method
    templates = {
      "plan/SKILL.md" => File.join(SKILLS, "plan/SKILL.md"),
      "software-design/SKILL.md" => File.join(SKILLS, "software-design/SKILL.md"),
      "architect.md" => File.join(ROOT, "claude/.claude/agents/architect.md")
    }
    templates.each do |name, path|
      text = File.read(path)

      refute_match(/prose summary/i, text, "#{name} asks for a prose summary per method")
      assert_match(/one-line summary/i, text, "#{name} does not ask for the class summary")
    end
  end

  def test_signatures_are_checked_by_steep_or_marked_not_checked
    text = File.read(File.join(SKILLS, "plan/SKILL.md"))

    assert_includes(text, "Checked by: steep check")
    assert_includes(text, "Not checked:")
  end
end
