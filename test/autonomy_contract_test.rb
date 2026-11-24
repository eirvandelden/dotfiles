#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "playbook"

# Autonomous delivery is skill and playbook text, not code. These contract tests pin the text that
# carries each boundary, so a later edit cannot drop one silently. They prove the words exist, not
# that an agent obeys them; the first real trial does that.
class AutonomyContractTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(REPO_ROOT, "agents/.agents/skills")
  PLAYBOOK = Playbook.text
  CODEX_CRITIQUE = "codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium"
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

  def test_plan_offers_autonomy_only_on_a_personal_origin
    text = skill("plan")

    assert_includes(text, "finish/scripts/change-scope")
    assert_includes(text, "Delivery: autonomous")
    assert_match(/only when .*`personal`/i, text)
    assert_match(/same paragraph as `Status:`/, text)
  end

  def test_plan_accept_starts_the_coordinator_loop
    section = delivery_reference

    assert_includes(section, "~/.agents/bin/hand-off-plan implement <slug> --auto")
    refute_match(/`spec`/, section)
    assert_match(/not .*chain/i, section_of(skill("plan"), "#### 7. Accept"))
  end

  def test_plan_coordinator_writes_the_account_and_never_merges
    section = delivery_reference

    assert_includes(section, "docs/changes/<slug>/deliver.md")
    assert_includes(section, "Never merge")
    assert_includes(section, "Decision needed:")
  end

  def test_the_account_is_committed_before_deliver_runs
    section = delivery_reference
    account = section.index("docs/changes/<slug>/deliver.md")

    assert_includes(section, "docs: delivery account for <slug>")
    assert_operator(account, :<, section.index("~/.claude/skills/deliver/SKILL.md"))
  end

  def test_the_delivery_done_line_names_the_in_repo_account_path
    section = delivery_reference
    paragraph = section[/^A stage pane started by.*$/]

    assert_includes(paragraph, "Delivery done: docs/changes/<slug>/deliver.md")
  end

  def test_the_final_message_carries_the_pull_request_url_and_the_ci_result
    section = delivery_reference
    final = section[/^\d+\. Tell Etienne.*$/]

    assert_includes(final, "PR URL")
    assert_includes(final, "CI result")
  end

  def test_nothing_names_the_old_account_path
    old_path = "herdr/deliver-" + "<slug>"
    files = Dir.glob(File.join(SKILLS, "**/*")) + Dir.glob(File.join(REPO_ROOT, "herdr/**/scripts/*")) +
            Dir.glob(File.join(REPO_ROOT, "test/*.rb"))
    offenders = files.select { |file| File.file?(file) && File.read(file).include?(old_path) }

    assert_empty(offenders)
  end

  def test_a_plan_session_started_by_a_pane_coordinates_and_sends_only_the_account
    section = delivery_reference

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

  def test_plan_auto_mode_leaves_the_status_draft_for_etienne
    section = section_of(skill("plan"), "## Auto mode")

    assert_includes(section, "Status: draft")
    assert_includes(section, 'types "accepted"')
    assert_includes(section, "`commit-plan`")
  end

  def test_plan_describes_the_interactive_autonomous_path
    plan = skill("plan")
    path = plan[/^\*\*Interactive autonomous plan\.\*\*.*$/].to_s

    assert_includes(path, "does not treat the `ExitPlanMode` approval as acceptance")
    assert_includes(path, "`Status: draft`")
    assert_includes(path, 'steps 1 to 3 of "Auto mode"')
    assert_includes(path, 'Only the typed word "accepted" or "agreed"')
    assert_includes(plan, "approving `ExitPlanMode` counts as \"accepted\", for a plan that is not autonomous only")
    assert_includes(section_of(plan, "## Auto mode"), 'from "Interactive autonomous plan"')
  end

  def test_coordinator_reviews_again_until_each_enabled_reviewer_is_clean
    section = delivery_reference

    assert_match(/run each enabled reviewer again/i, section)
    assert_match(/a round of each enabled reviewer .*no open finding/i, section)
  end

  def test_codex_coordinator_uses_the_claude_cli_review_backend
    section = delivery_reference

    assert_match(/Review.*`review`.*auto mode/, section)
    assert_match(/Codex coordinator.*read-only Claude CLI backend/, section)
  end

  def test_plan_auto_mode_runs_the_other_family_critique
    assert_critique_contract(section_of(skill("plan"), "## Auto mode"))
  end

  def test_playbook_autonomy_names_the_codex_critique
    assert_includes(autonomy_section, CODEX_CRITIQUE)
  end

  def test_review_auto_mode_skips_codex_unless_the_plan_opts_in
    section = section_of(skill("review"), "## Auto mode")

    assert_includes(section, "start-review")
    assert_includes(section, "code-review")
    assert_match(/transcribe/i, section)
    assert_match(/Codex round only when .*`Codex review: yes`/i, section)
    assert_match(/never .*`codex review`/i, section)
  end

  def test_review_auto_mode_runs_codex_first_when_the_plan_opts_in
    section = section_of(skill("review"), "## Auto mode")

    assert_includes(section, "codex review --base")
    assert_match(/`Codex review: yes`.*Codex round before the Claude round/m, section)
  end

  def test_plan_offers_codex_review_only_for_autonomous_delivery_defaulting_to_no
    delivery = section_of(skill("plan"), "#### 2. Interview")[/\*\*Delivery mode\.\*\*.*?(?=^Batch )/m]

    assert_match(/Also review with Codex\?.*default: no/i, delivery)
    assert_includes(delivery, "`Codex review: yes`")
    assert_match(/only .*autonomous/i, delivery)
  end

  def test_autonomous_delivery_waits_for_each_enabled_reviewer
    assert_match(/each enabled reviewer/i, delivery_reference)
    assert_match(/each enabled reviewer/i, skill("deliver"))
  end

  def test_playbook_names_codex_as_an_opt_in_reviewer
    line = PLAYBOOK.lines.find { |entry| entry.start_with?("- Independent review") }

    assert_match(/Claude `reviewer` agent.*always/i, line)
    assert_includes(line, "`Codex review: yes`")
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

  def test_deliver_fills_the_body_without_asking_for_confirmation
    text = skill("deliver")

    assert_includes(text, "The script asks no questions.")
    assert_match(/Fill the PR body/, text)
  end

  def test_finish_auto_mode_requires_an_accepted_autonomous_plan
    section = section_of(skill("finish"), "## Auto mode")

    assert_match(/accepted `plan.md`/, section)
    assert_includes(section, "`Delivery: autonomous`")
    assert_match(/step-by-step.*steps above unchanged/i, section)
  end

  def test_finish_overview_allows_the_autonomous_coordinator
    overview = skill("finish").split("## 1.").first

    assert_includes(overview, "or by the autonomous coordinator")
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

  def test_code_review_codex_section_gates_the_codex_findings_on_the_opt_in
    codex = section_of(skill("code-review"), "## Codex")

    assert_includes(codex, "`Codex review: yes`")
  end

  def test_plan_template_step_names_the_codex_review_field
    line = skill("plan").lines.find { |entry| entry.include?("for autonomous delivery, `Delivery: autonomous`") }

    assert_includes(line, "`Codex review: yes|no`")
  end

  def test_a_codex_session_hands_autonomous_delivery_to_claude
    section = delivery_reference

    assert_includes(section, "plan/scripts/start-delivery")
    assert_match(/Codex session.*runs .*start-delivery.*stops/i, section)
    assert_match(/Codex coordinates only on Etienne's explicit instruction/i, section)
    refute_match(/as a Codex coordinator, run each stage/i, section)
  end

  def test_codex_stays_the_plan_critic_and_reviewer_with_stdin_closed
    assert_match(%r{codex exec -m gpt-6.1-sol .*< /dev/null}, section_of(skill("plan"), "## Auto mode"))
    assert_match(%r{codex review --base <base>.*< /dev/null}, section_of(skill("review"), "## Auto mode"))
  end

  def test_plan_runs_the_preflight_before_the_implement_stage
    section = delivery_reference
    preflight = section.index("plan/scripts/delivery-preflight")

    refute_nil(preflight, "the coordinator never runs the preflight")
    assert_operator(preflight, :<, section.index("hand-off-plan implement <slug> --auto"))
    assert_match(/--needs/, section)
    assert_match(/every missing item together/i, section)
  end

  def test_plan_records_evidence_and_keeps_the_account_current
    section = delivery_reference

    assert_includes(section, "finish/scripts/delivery-evidence run")
    assert_includes(section, "delivery-evidence status")
    assert_match(/after every stage/i, section)
    assert_match(/resum/i, section)
  end

  def test_implement_auto_records_final_runs
    assert_includes(section_of(skill("implement"), "## Auto mode"), "delivery-evidence run")
  end

  def test_deliver_auto_mode_gates_on_fresh_evidence
    section = section_of(skill("deliver"), "## Auto mode")

    assert_includes(section, "delivery-evidence check --require tests,lint")
    assert_match(/stale|missing|failed/i, section)
  end

  def test_deliver_auto_mode_builds_the_body_from_the_handover
    section = section_of(skill("deliver"), "## Auto mode")

    assert_includes(section, "delivery-evidence handover")
    assert_match(/fill-pr-template/, section)
  end

  def test_deliver_auto_mode_verifies_the_pull_request_body_and_head
    assert_includes(section_of(skill("deliver"), "## Auto mode"), "delivery-evidence pr-check")
  end

  def test_finish_auto_mode_never_reports_a_pending_check_as_passing
    assert_match(/pending check is pending, never passing/, section_of(skill("finish"), "## Auto mode"))
  end

  def test_playbook_names_the_claude_coordinator_preflight_evidence_and_handover
    section = autonomy_section

    assert_match(/Claude coordinator/, section)
    assert_includes(section, "start-delivery")
    assert_match(/preflight/i, section)
    assert_match(/evidence/i, section)
    assert_match(/stale/i, section)
    assert_match(/pull request body/i, section)
  end

  def test_core_values_keep_the_autonomous_delivery_mirror
    assert_includes(CORE_VALUES, "the critique closes before Etienne types accepted on the plan")
    assert_match(/critique comes before "accepted"/i, autonomy_section)
    assert_match(/Agents never merge/, autonomy_section)
  end

  private

  def assert_critique_contract(section)
    assert_includes(section, CODEX_CRITIQUE)
    assert_includes(section, "claude -p")
    assert_includes(section, "## Critique")
    assert_includes(section, "### Round")
    assert_includes(section, "commit-plan")
    assert_match(/Decision needed:/, section)
  end

  def autonomy_section
    section_of(PLAYBOOK, "## 7a.")
  end

  def skill(name)
    File.read(File.join(SKILLS, name, "SKILL.md"))
  end

  def delivery_reference
    File.read(File.join(SKILLS, "plan/references/autonomous-delivery.md"))
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
