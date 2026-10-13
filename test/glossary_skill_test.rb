#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require "fileutils"
require "open3"
require "tmpdir"

# The glossary outlives every change folder. Personal repositories commit GLOSSARY.md; work
# repositories keep GLOSSARY.local.md, which git never tracks.
class GlossarySkillTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(ROOT, "claude/.claude/skills")
  IGNORE_GLOBAL = File.join(ROOT, "git/.config/git/ignore.global")

  def test_the_glossary_lives_outside_the_change_folder_by_scope
    text = glossary_skill

    assert_includes(text, "GLOSSARY.md")
    assert_includes(text, "GLOSSARY.local.md")
    assert_includes(text, "change-scope")
    assert_match(/personal/i, text)
    assert_match(/work/i, text)
    assert_match(/finish/i, text)
    assert_match(/glossary/i, File.read(File.join(SKILLS, "intent/SKILL.md")))
    assert_match(/glossary/i, File.read(File.join(SKILLS, "plan/SKILL.md")))
  end

  def test_an_avoided_word_gets_the_glossary_term_and_a_question
    text = glossary_skill

    assert_includes(text, "Avoid:")
    assert_match(/name the (glossary )?term/i, text)
    assert_match(/ask which/i, text)
  end

  def test_git_ignores_glossary_local_md
    Dir.mktmpdir do |dir|
      git(dir, "init", "-q")
      git(dir, "config", "core.excludesFile", IGNORE_GLOBAL)

      _, _, status = git(dir, "check-ignore", "-q", "GLOSSARY.local.md")
      assert(status.success?, "GLOSSARY.local.md is not ignored by ignore.global")

      _, _, status = git(dir, "check-ignore", "-q", "GLOSSARY.md")
      refute(status.success?, "GLOSSARY.md must stay committable")
    end
  end

  private

  def glossary_skill
    path = File.join(SKILLS, "glossary/SKILL.md")
    flunk("#{path} does not exist") unless File.exist?(path)
    File.read(path)
  end

  def git(dir, *args)
    Open3.capture3("git", "-C", dir, *args)
  end
end
