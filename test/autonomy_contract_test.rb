#!/usr/bin/env ruby
require "minitest/autorun"

# Autonomous delivery is skill and playbook text, not code. These contract tests pin the text that
# carries each boundary, so a later edit cannot drop one silently. They prove the words exist, not
# that an agent obeys them; the first real trial does that.
class AutonomyContractTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")
  PLAYBOOK = File.read(File.join(REPO_ROOT, "agents.md"))
  CORE_VALUES = File.read(File.join(REPO_ROOT, "claude/.claude/core-values.yml"))

  def test_playbook_carves_rule_17_out_for_personal_autonomy
    rule = PLAYBOOK[/^17\. Plan before implementing:.*?(?=^18\. )/m]

    assert_match(/personal/i, rule)
    assert_includes(rule, "§7a")
  end

  def test_core_values_mirror_the_carve_out
    assert_match(/personal.*autonomous|autonomous.*personal/i, CORE_VALUES)
  end

  def test_core_values_say_agents_never_merge
    assert_match(/never merge/i, CORE_VALUES)
  end

  def test_core_values_scope_never_merge_to_autonomous_delivery
    line = CORE_VALUES.lines.find { |entry| entry.match?(/never merge/i) }

    assert_match(/autonomous delivery/i, line)
  end

  def test_playbook_autonomy_keeps_checks_strict
    section = autonomy_section

    assert_match(/skipped test/i, section)
    assert_match(/disable comment/i, section)
    assert_match(/linter config/i, section)
  end

  def test_playbook_lists_the_four_escalation_triggers
    section = autonomy_section

    assert_match(/changes the agreed behaviour/i, section)
    assert_match(/permission/i, section)
    assert_match(/three failed attempts/i, section)
    assert_match(/two rounds/i, section)
  end

  def test_intent_offers_autonomy_only_on_a_personal_origin
    text = skill("intent")

    assert_includes(text, "finish/scripts/change-scope")
    assert_includes(text, "Delivery: autonomous")
    assert_match(/only when .*`personal`/i, text)
  end

  def test_intent_accept_starts_the_coordinator_loop
    section = section_of(skill("intent"), "## Autonomous delivery")

    assert_includes(section, "hand-off-plan.sh <stage> <slug> --auto")
    assert_match(/`plan`, then `implement`/, section)
    refute_match(/`spec`/, section)
    assert_match(/not .*chain/i, skill("intent")[/^## 4\. Accept.*?(?=^## )/m])
  end

  def test_intent_coordinator_writes_the_account_and_never_merges
    section = section_of(skill("intent"), "## Autonomous delivery")

    assert_includes(section, "deliver-<slug>.md")
    assert_includes(section, "Never merge")
    assert_includes(section, "Decision needed:")
  end

  def test_an_intent_session_started_by_a_pane_coordinates_and_sends_only_the_account
    section = section_of(skill("intent"), "## Autonomous delivery")

    assert_match(/starting prompt/i, section)
    assert_includes(section, "Delivery done:")
  end

  def test_implement_and_plan_frontmatter_name_the_auto_argument
    %w[implement plan].each do |name|
      frontmatter = skill(name)[/\A---\n.*?\n---\n/m]

      assert_match(/\bauto\b/, frontmatter, name)
    end
  end

  def test_plan_keeps_the_literal_accepted_outside_auto
    %w[plan].each do |name|
      text = skill(name)

      assert_includes(text, 'literal word "accepted"', name)
      assert_includes(text, "`Delivery: autonomous`", name)
    end
  end

  def test_plan_auto_mode_rules_out_plan_mode_before_anything_else
    section = section_of(skill("plan"), "## Auto mode")
    first_step = section.index("\n1. ")

    assert_operator(section.index("EnterPlanMode"), :<, first_step)
    assert_operator(section.index("`/plan`"), :<, first_step)
  end

  def test_plan_auto_mode_passes_auto_accept_the_folder_path
    assert_includes(section_of(skill("plan"), "## Auto mode"), "auto-accept <folder>/plan.md")
  end

  def test_coordinator_reviews_again_until_both_reviewers_are_clean
    section = section_of(skill("intent"), "## Autonomous delivery")

    assert_match(/run both reviewers again/i, section)
    assert_match(/a round of each .*no open finding/i, section)
  end

  def test_codex_coordinator_uses_the_claude_cli_review_backend
    section = section_of(skill("intent"), "## Autonomous delivery")

    assert_match(/Review.*`review`.*auto mode/, section)
    assert_match(/Codex coordinator.*read-only Claude CLI backend/, section)
  end

  def test_plan_auto_mode_runs_the_other_family_critique
    assert_critique_contract(section_of(skill("plan"), "## Auto mode"))
  end

  def test_review_auto_mode_runs_claude_and_codex_reviewers
    section = section_of(skill("review"), "## Auto mode")

    assert_includes(section, "start-review.sh")
    assert_includes(section, "codex review --base")
    assert_includes(section, "code-review")
    assert_match(/transcribe/i, section)
  end

  def test_codex_auto_review_uses_a_read_only_claude_cli_backend
    section = section_of(skill("review"), "## Auto mode")

    assert_includes(section, "claude -p --model opus --permission-mode plan")
    assert_match(/Codex coordinator/i, section)
    assert_match(/read-only/i, section)
    assert_includes(section, "(claude)")
    assert_match(/unavailable.*Decision needed:/i, section)
    assert_includes(section_of(skill("review"), "## Codex"), "Auto mode")
  end

  def test_claude_cli_review_replaces_the_reviewer_write_and_fetch_steps
    section = section_of(skill("review"), "### Read-only Claude CLI backend")

    assert_match(/replaces.*fetch.*write.*commit.*Output/, section)
    assert_includes(section, "Do not fetch")
    assert_includes(section, "stdout")
  end

  def test_implement_auto_reports_a_decision_instead_of_adding_a_dependency
    section = section_of(skill("implement"), "## Auto mode")

    assert_includes(section, "Decision needed:")
    assert_match(/dependency/i, section)
    assert_match(/three failed attempts/i, section)
  end

  def test_code_review_escalates_a_finding_disputed_for_two_rounds
    section = section_of(skill("code-review"), "## Auto mode")

    assert_match(/two rounds/i, section)
    assert_match(/Etienne/, section)
  end

  def test_finish_auto_mode_is_personal_only
    section = section_of(skill("finish"), "## Auto mode")

    assert_match(/personal/i, section)
    assert_match(/work.*refuses/i, section)
  end

  def test_finish_auto_mode_skips_the_actual_body_confirmation_step
    section = section_of(skill("finish"), "## Auto mode")

    assert_includes(section, "§3 step 3")
    assert_match(/capture.*body.*without waiting for confirmation/i, section)
  end

  def test_plan_forbids_an_arrow_inside_a_closure
    %w[plan].each do |name|
      assert_match(/may not contain `→`/, section_of(skill(name), "## Auto mode"), name)
      assert_includes(section_of(skill(name), "## Auto mode"), "`No findings.`", name)
      assert_match(/last thing in the file/, section_of(skill(name), "## Auto mode"), name)
      assert_match(/further `### Round` heading/, section_of(skill(name), "## Auto mode"), name)
    end
  end

  def test_plan_names_the_claude_critique_in_its_codex_section
    %w[plan].each do |name|
      codex = section_of(skill(name), "## Codex")

      assert_includes(codex, "claude -p", name)
    end
  end

  private

  def assert_critique_contract(section)
    assert_includes(section, "codex exec -p terra")
    assert_includes(section, "claude -p")
    assert_includes(section, "## Critique")
    assert_includes(section, "### Round")
    assert_includes(section, "auto-accept")
    assert_match(/Decision needed:/, section)
  end

  def autonomy_section
    section_of(PLAYBOOK, "## 7a.")
  end

  def skill(name)
    File.read(File.join(SKILLS, name, "SKILL.md"))
  end

  # The text from a heading to the next heading of the same or higher level. A missing heading
  # fails the test, so a dropped section is a red test, not a vacuous pass.
  def section_of(text, heading)
    level = heading[/\A#+/].length
    lines = text.lines
    start = lines.index { |line| line.start_with?(heading) }
    flunk("missing section #{heading}") unless start

    stop = lines[(start + 1)..].index { |line| line.match?(/\A#{'#'}{1,#{level}} /) }
    stop ? lines[start, stop + 1].join : lines[start..].join
  end
end
