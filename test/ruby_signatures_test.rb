#!/usr/bin/env ruby
require "minitest/autorun"

# New Ruby code carries a prose summary and an inline RBS signature per method, never YARD tags.
class RubySignaturesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(ROOT, "claude/.claude/skills")
  YARD_SKILL_FILES = %w[
    ruby-style/SKILL.md rails-architecture/SKILL.md rails-architecture/references/examples.md
    implement/SKILL.md object-oriented-design/SKILL.md
  ].freeze
  YARD_ASK = /YARD-document|use YARD|@param\b|@return\b|@action\b|@route\b|YARD tags `@/

  def test_ruby_style_asks_for_a_summary_and_inline_rbs_per_method
    text = File.read(File.join(SKILLS, "ruby-style/SKILL.md"))

    assert_match(/inline RBS/i, text)
    assert_includes(text, "#:")
    assert_includes(text, "# @rbs")
    assert_match(/prose summary|summary/i, text)
    assert_match(/every (class and )?method/i, text)
  end

  def test_no_skill_asks_for_yard_tags
    offences = YARD_SKILL_FILES.flat_map { |relative| yard_lines(relative) }

    assert_empty(offences)
  end

  def test_signatures_are_checked_by_steep_or_marked_not_checked
    text = File.read(File.join(SKILLS, "plan/SKILL.md"))

    assert_includes(text, "Checked by: steep check")
    assert_includes(text, "Not checked:")
  end

  private

  def yard_lines(relative)
    File.readlines(File.join(SKILLS, relative)).each_with_index.filter_map do |line, index|
      next unless line.match?(YARD_ASK)

      "#{relative}:#{index + 1}: #{line.strip}"
    end
  end
end
