#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# The herdr-app-tabs skill tells agents to open tabs with `herdr-app-pane tab` and nothing else.
class HerdrAppTabsSkillTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SKILL = File.read(File.join(ROOT, "agents/.agents/skills/herdr-app-tabs/SKILL.md"))

  def test_the_skill_opens_tabs_with_herdr_app_pane_tab
    assert_match(/^herdr-app-pane tab "<folder>" --name "<name>"/, SKILL)
  end

  def test_the_skill_forbids_the_herdr_tui_herdr_env_and_the_stale_skills
    never = SKILL[/^## Never\n(.*)/m, 1]

    %w[herdr\ pane herdr\ tab HERDR_ENV herdr-automate herdr-gpui-browser herdr-automations].each do |word|
      assert_includes(never, word)
    end
    assert_match(/bare `herdr-app do tab.new` without `space`/, never)
  end

  def test_no_code_fence_runs_the_herdr_tui
    fences = SKILL.scan(/```.*?\n(.*?)```/m).flatten.join

    refute_match(/^\s*herdr\s/, fences)
    refute_match(/HERDR_ENV|herdr-automate/, fences)
  end

  def test_the_skill_states_how_hc_session_names_the_own_core
    assert_match(/`HC_SESSION=work` is the work core/, SKILL)
    assert_match(/unset, empty or `default` is the personal core/, SKILL)
  end

  def test_skills_index_lists_herdr_app_tabs
    index = File.read(File.join(ROOT, "SKILLS-INDEX.md"))

    assert_includes(index, "agents/.agents/skills/herdr-app-tabs/SKILL.md")
  end

  def test_the_skill_never_names_the_old_app_by_its_glossary_avoided_word
    refute_match(/Herdr UI/, SKILL)
  end
end
