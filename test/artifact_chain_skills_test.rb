#!/usr/bin/env ruby
require "minitest/autorun"

# The change workflow is intent -> plan -> implement. These tests read the skill, agent and
# playbook text, since that text is the behaviour: an agent does what the skill says.
class ArtifactChainSkillsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(ROOT, "claude/.claude/skills")

  LIVE_PATHS = %w[claude agents codex herdr git bin agents.md SKILLS-INDEX.md].freeze
  STAGE_SHAPED_SPEC = [
    /`spec`/,
    /(?<!ai-native-workflow\/)\bspec\.md/,
    /hand-off-plan\.sh spec/,
    /\$spec\b/,
    /\bspec skill/i,
    /intent\/spec/,
    /spec\/plan/,
    /intent, spec/
  ].freeze

  def test_the_intent_interview_asks_what_is_in_and_out_of_scope
    interview = section(skill("intent"), "## 2. Interview", "## Red flags")

    assert_match(/in scope/i, interview)
    assert_match(/out of scope/i, interview)
  end

  def test_the_interview_stops_when_every_section_can_be_filled_without_guessing
    assert_match(/every (template )?section[^.]*without guessing/i, skill("intent"))
  end

  def test_the_interview_has_no_fixed_question_count
    refute_match(/three to five questions/i, skill("intent"))
    assert_match(/no fixed (question )?count/i, skill("intent"))
  end

  def test_the_template_holds_in_scope_out_of_scope_acceptance_criteria_and_flagged_concerns
    template = section(skill("intent"), "## 3. Write", "## 4. Accept")

    [ "## In scope", "## Out of scope", "## Acceptance criteria", "## Flagged concerns" ].each do |heading|
      assert_includes(template, heading)
    end
  end

  def test_intent_refuses_acceptance_without_acceptance_criteria
    accept = section(skill("intent"), "## 4. Accept", "## Codex")

    assert_match(/refuse/i, accept)
    assert_match(/acceptance criteria/i, accept)
    assert_match(/name[s]? what is missing/i, accept)
  end

  def test_intent_refuses_acceptance_with_open_questions_or_an_undecided_concern
    accept = section(skill("intent"), "## 4. Accept", "## Codex")

    assert_match(/## Open questions/, accept)
    assert_match(/flagged concern/i, accept)
  end

  def test_accepting_chains_to_plan
    accept = section(skill("intent"), "## 4. Accept", "## Codex")

    assert_includes(accept, "hand-off-plan.sh plan '<slug>'")
    refute_includes(accept, "hand-off-plan.sh spec")
  end

  def test_there_is_no_spec_skill_for_claude_or_codex
    [ "claude/.claude/skills/spec", "agents/.agents/skills/spec" ].each do |relative|
      path = File.join(ROOT, relative)

      refute(File.exist?(path) || File.symlink?(path), "#{relative} must not exist")
    end
  end

  def test_intent_creates_its_worktree_without_opening_a_pane
    step_one = section(skill("intent"), "## 1. Find the folder", "## 2. Interview")

    assert_match(/worktree-first/, step_one)
    assert_match(/no-pane/i, step_one)
    assert_includes(skill("worktree-first"), "--no-pane")
  end

  def test_a_plain_worktree_first_invocation_still_opens_a_pane
    assert_match(/Inside herdr, a pane rooted in the new worktree opens below/, skill("worktree-first"))
    assert_match(/plain invocation[^.]*pane/i, skill("worktree-first"))
  end

  def test_plan_reads_only_an_accepted_intent
    plan = skill("plan")

    assert_match(/Use once intent\.md is accepted/, plan)
    assert_match(/refuse[^.]*intent\.md/i, plan)
    refute_match(/\bspec\b/i, plan)
  end

  def test_the_plan_template_holds_design_decisions_and_integration_points
    plan = skill("plan")

    assert_includes(plan, "## Design decisions")
    assert_includes(plan, "## Integration points")
    assert_includes(plan, "Domain skills applied:")
  end

  def test_plan_applies_domain_skills
    assert_match(/apply (the )?domain skills/i, skill("plan"))
  end

  def test_the_reviewer_and_test_writer_read_acceptance_criteria_from_intent
    [ "claude/.claude/agents/reviewer.md", "claude/.claude/agents/test-writer.md" ].each do |relative|
      text = File.read(File.join(ROOT, relative))

      assert_match(/intent\.md/, text, relative)
      refute_match(/\bspec\.md/, text, relative)
    end
  end

  def test_nothing_live_names_the_spec_stage
    offences = live_files.flat_map { |path| offences_in(path) }

    assert_empty(offences, "live files still name the spec stage:\n#{offences.join("\n")}")
  end

  private

  def skill(name)
    File.read(File.join(SKILLS, name, "SKILL.md"))
  end

  def section(text, from, to)
    start = text.index(from) || flunk("no #{from.inspect} in text")
    finish = text.index(to, start + from.size) || text.size
    text[start...finish]
  end

  def live_files
    LIVE_PATHS.flat_map do |relative|
      path = File.join(ROOT, relative)
      File.file?(path) ? [ path ] : Dir.glob(File.join(path, "**/{*,.*}")).select { |file| File.file?(file) }
    end.reject { |file| binary?(file) || file == __FILE__ }
  end

  def binary?(path)
    File.read(path, 1024).to_s.include?("\0")
  end

  def offences_in(path)
    File.foreach(path, chomp: true).each_with_index.filter_map do |line, index|
      next unless STAGE_SHAPED_SPEC.any? { |pattern| line.valid_encoding? && line.match?(pattern) }

      "#{path.delete_prefix("#{ROOT}/")}:#{index + 1}: #{line.strip}"
    end
  end
end
