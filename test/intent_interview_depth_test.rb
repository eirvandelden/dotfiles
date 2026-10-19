#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# The deeper intent interview is skill text: an agent does what the skill says. These tests read it.
class IntentInterviewDepthTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(ROOT, "agents/.agents/skills")
  MIRROR_SENTENCES = [
    "Intent interviews read the repository first, split bundled requests, probe edge cases, read the draft back and record decisions.",
    "Bug fixes and chores stay at 1–3 questions; features and refactors probe fully."
  ].freeze

  def test_a_feature_interview_reads_the_repository_before_its_first_question
    interview = section(skill("intent"), "## 2. Interview", "## Red flags")
    first_paragraph = interview.split("\n\n")[1]

    assert_match(/\A\*\*Explore first\.\*\*/, first_paragraph)
    assert_match(/before the first (interview )?question/i, first_paragraph)
    assert_match(/only what the repository cannot answer/i, first_paragraph)
  end

  def test_a_bundled_request_is_flagged_and_split_before_details_are_refined
    interview = section(skill("intent"), "## 2. Interview", "## Red flags")
    scope_check = paragraph(interview, "**Scope check.**")

    assert_match(/bundles independent changes/i, scope_check)
    assert_match(/split/i, scope_check)
    assert_operator(interview.index("**Scope check.**"), :<, interview.index("\n1. What can someone not do today?"))
  end

  def test_a_feature_interview_probes_edge_cases_and_failure_modes
    probe = section(skill("intent"), "**Probe.**", "**Record decisions.**")

    assert_match(/`feature` and `refactor`/, probe)
    assert_match(/edge cases/i, probe)
    assert_match(/failure modes/i, probe)
    assert_match(/what happens when/i, probe)
  end

  def test_a_clear_bug_fix_still_ends_after_one_to_three_questions
    interview = section(skill("intent"), "## 2. Interview", "## Red flags")
    depth = paragraph(interview, "**Depth by type.**")

    assert_match(/`bugfix` and `chore`[^.]*1[–-]3 questions/, depth)
    assert_match(/no fixed question count/i, interview)
    assert_match(/For `feature` and `refactor` there is no fixed question count/, interview)
  end

  def test_the_draft_is_self_reviewed_before_the_read_back
    accept = section(skill("intent"), "## 4. Accept", "## Autonomous delivery")
    self_review = paragraph(accept, "**Self-review.**")

    %w[placeholders contradictions scope ambiguous].each { |word| assert_match(/#{word}/i, self_review) }
    assert_operator(accept.index("**Self-review.**"), :<, accept.index("**Read-back.**"))
  end

  def test_the_draft_is_read_back_section_by_section_before_asking_for_accepted
    accept = section(skill("intent"), "## 4. Accept", "## Autonomous delivery")
    read_back = paragraph(accept, "**Read-back.**")

    assert_match(/section by section/i, read_back)
    assert_match(/template order/i, read_back)
    assert_match(/not counted as an interview question/i, read_back)
    assert_operator(accept.index("**Read-back.**"), :<, accept.index("Refuse to flip"))
  end

  def test_the_template_records_each_decision_with_its_rationale
    template = section(skill("intent"), "## 3. Write", "## 4. Accept")
    concerns = template.index("## Flagged concerns") || flunk("no concerns")
    decisions = template.index("## Decisions") || flunk("no decisions")
    questions = template.index("## Open questions") || flunk("no questions")

    assert_operator(concerns, :<, decisions)
    assert_operator(decisions, :<, questions)
    assert_match(/- <decision[^>]*> — <[^>]*rationale[^>]*>/i, template)
  end

  def test_a_decision_rationale_is_asked_for_never_invented
    record = paragraph(section(skill("intent"), "## 2. Interview", "## Red flags"), "**Record decisions.**")

    assert_match(/never invent a rationale/i, record)
    assert_match(/ask for it/i, record)
    assert_includes(record, "no reason given")
  end

  def test_plan_reports_a_step_that_contradicts_a_recorded_decision
    plan = skill("plan")
    here = section(plan, "### `here` backend", "## Auto mode")
    auto = section(plan, "## Auto mode", "## Critique")

    assert_includes(here, "## Decisions")
    assert_match(/never resolved silently/i, here)
    assert_includes(auto, "## Decisions")
    assert_includes(auto, "`Decision needed:`")
  end

  def test_the_plan_critique_checks_the_recorded_decisions
    critique = section(skill("plan"), "## Critique\n\nRead the plan", "## Execute a handed-over plan")

    assert_includes(critique, "## Decisions")
  end

  def test_the_vendored_comment_names_what_was_adapted_and_left_out
    comment = skill("intent")[/<!--.*?-->/m] || flunk("no vendored comment")

    assert_match(/explore project context/i, comment)
    assert_match(/scope[^\n]*decomposition|decomposition/i, comment)
    assert_match(/self-review/i, comment)
    assert_includes(comment, "visual companion")
    assert_includes(comment, "`writing-plans`")
    assert_match(/reviewer subagent/i, comment)
    assert_includes(comment, "2026-10")
  end

  def test_core_values_and_rule_17_name_the_deeper_interview
    values = File.read(File.join(ROOT, "claude/.claude/core-values.yml"))
    rule = File.read(File.join(ROOT, "agents.md"))[/^17\. .*?(?=^18\. )/m] || flunk("no rule 17")

    MIRROR_SENTENCES.each do |sentence|
      assert_includes(values, sentence)
      assert_includes(rule, sentence)
      assert_operator(sentence.split.size, :<=, 20)
    end
  end

  def test_the_codex_section_keeps_the_deeper_interview
    codex = section(skill("intent"), "## Codex", "\u0000")

    assert_match(/explore first/i, codex)
    assert_match(/read-back/i, codex)
  end

  private

  def skill(name)
    File.read(File.join(SKILLS, name, "SKILL.md"))
  end

  def paragraph(text, label)
    text.split("\n\n").find { |block| block.start_with?(label) } || flunk("no paragraph #{label.inspect}")
  end

  def section(text, from, to)
    start = text.index(from) || flunk("no #{from.inspect} in text")
    finish = text.index(to, start + from.size) || text.size
    text[start...finish]
  end
end
