# Plan: Autonomous delivery for personal projects

From `intent.md` and `spec.md` (2026-10-01). Status: accepted.

## Context

Etienne accepts every intent, spec and plan by hand and relays reports between stage panes. On personal repos (origin `github.com/eirvandelden/…`) this plan removes the spec and plan "accepted" gates. A cross-model critique replaces them. One coordinator, the session that ran the intent interview, then drives spec, plan, implement, review, fixes and the PR. Two human gates stay: "accepted" on the intent, and the merge. Work repos keep the current flow unchanged.

Decisions taken in planning (Etienne, 2026-10-01):

- The coordinator loop lives in a new `## Autonomous delivery` section of the `intent` skill. No new skill.
- One mechanical gate: a new `auto-accept` script. Everything else is skill and playbook text, proven by contract tests in the style of `test/markdown_rule_mirror_test.rb`.

Facts the implementer relies on:

- `agents.md` is the one playbook. `CLAUDE.md`, `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md` are symlinks to it, so one edit reaches both CLIs.
- Codex reads skills through symlinks in `agents/.agents/skills/` into `claude/.claude/skills/`. `code-review` is Claude-only today (`CLAUDE_ONLY` in `test/skill_parity_test.rb`).
- `RemoteMatcher.personal?` lives in `claude/.claude/hooks/remote_matcher.rb`. `finish/scripts/change-scope` already loads it with `require_relative "../../../hooks/remote_matcher"`.
- `codex exec -p terra -s read-only -o <file> "<prompt>"` runs a read-only Codex critique. `codex review --base <branch>` reviews a branch. `claude -p --model opus --permission-mode plan "<prompt>"` is the Claude counterpart. Re-check each flag with `--help` before writing it into a skill.
- Tests run as `ruby test/<name>_test.rb`. CI runs every `test/*_test.rb` (`.github/workflows/dotfiles-tests.yml`).

## Files that change

- `claude/.claude/skills/plan/scripts/auto-accept` (new, Ruby, executable) — `auto-accept <artifact.md>`. Exits 1 with a reason when: `origin` is not `RemoteMatcher.personal?`, or missing; the artifact has no `## Critique` section; that section has no `### Round` heading; any finding line under it has an empty `→` slot; the status line is not `Status: draft`. Otherwise it rewrites `Status: draft` to `Status: accepted` and changes nothing else. It never commits.
- `test/auto_accept_test.rb` (new) — behaviour tests for that script, temp repos, isolated `HOME`, same setup as `test/change_scope_test.rb`.
- `agents.md` — rule 17 gets a personal carve-out that points to a new `§7a Autonomous delivery (Personal)`. That section states: the scope test; the two human gates; critique replaces "accepted" on spec and plan; independent review by the Claude `reviewer` agent and Codex; checks stay strict (no skipped test, no disable comment, no linter config edit); verify behaviour as a human would; the four escalation triggers; agents never merge; deployment is out of scope; rules 6, 8, 9, 11, 12 and 13 stay in force.
- `claude/.claude/core-values.yml` — a new `workflow` line after the first rule carries the same carve-out, and a consent line says agents never merge in autonomous delivery.
- `claude/.claude/skills/intent/SKILL.md` — the interview runs `~/.claude/skills/finish/scripts/change-scope`. On `personal`, it asks for known permission needs (gems, system tools, migrations, deploy files) and offers autonomous or step-by-step delivery. Autonomous adds a `Delivery: autonomous` line to `intent.md`. On "accepted" with that line, the session does not chain to `hand-off-plan.sh spec`; it follows the new `## Autonomous delivery` section:
  1. `hand-off-plan.sh spec <slug> --auto`, wait for `Spec ready:`, read the report.
  2. Same for `plan`, then `implement`.
  3. Run tests, linters, Brakeman and Bundler Audit where the repo has them.
  4. Exercise the behaviour as a human would and record the evidence.
  5. Review: `start-review.sh` and `codex review --base <base>`, the latter transcribed as its own round in `review.md` in the reviewer's format and committed alone. Fix through `code-review`. Repeat until no open finding.
  6. Follow `~/.claude/skills/finish/SKILL.md` in auto mode.
  7. Write the account (behaviour, evidence, check results, review outcome, PR URL) to `<git-common-dir>/herdr/deliver-<slug>.md` and tell Etienne. Never merge.
  - Escalation: stop and ask Etienne one concrete question on a behaviour-changing choice, a permission need, three failed attempts at one problem, or a finding disputed after two rounds. A `Decision needed:` line in a stage report is how panes raise these.
  - Outside herdr, or as a Codex coordinator, run each stage's `here` backend in sequence instead of panes.
- `claude/.claude/skills/spec/SKILL.md` and `claude/.claude/skills/plan/SKILL.md` — new `auto` argument. Only valid when `intent.md` has `Delivery: autonomous`. Auto mode: write the artifact; run the other family's critique (Claude author → `codex exec -p terra`, Codex author → `claude -p`); record a `## Critique` round with each finding closed as `fixed (<what changed>)` or `dismissed: <reason>`; run `auto-accept`; commit alone; push; report. It never asks Etienne and never chains to the next stage; a behaviour-changing choice becomes a `Decision needed:` line in the report. The non-auto Accept steps keep the literal "accepted".
- `claude/.claude/skills/implement/SKILL.md` — `auto` note: ask nothing; after three failed attempts at one problem, stop and report `Decision needed:`; a new dependency is a `Decision needed:`, never added.
- `claude/.claude/skills/review/SKILL.md` — auto section: the coordinator runs both reviewers, and "stop, do not start fixing" does not apply; the coordinator fixes through `code-review`.
- `claude/.claude/skills/code-review/SKILL.md` — auto rule: a finding still disputed after two rounds goes to Etienne, never dismissed by the coordinator alone. Plus a `## Codex` section.
- `claude/.claude/skills/code-review/agents/openai.yaml` (new) and `agents/.agents/skills/code-review` (new symlink, `../../../claude/.claude/skills/code-review`) — Codex coordinators need the fix loop. `test/skill_parity_test.rb` drops `code-review` from `CLAUDE_ONLY`.
- `claude/.claude/skills/finish/SKILL.md` — auto mode for personal scope only: no confirmation in §3, and §4 closes every matching idle stage pane without asking. Work scope refuses auto. The description says a coordinator may run it on a personal repo.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` — optional third argument `--auto` for `spec`, `plan` and `implement`; `intent --auto` is refused. Auto prompts tell the worker to invoke the skill with `auto`, not to wait for "accepted", not to chain, and to put open decisions as `Decision needed:` lines in its report. Report-back and pane-close text stay the same.
- `test/herdr_worker_scripts_test.rb` — tests for `--auto`.
- `test/autonomy_contract_test.rb` (new) — text contracts on `agents.md`, `core-values.yml` and the skills.

Unchanged on purpose: `start-review.sh` (already reports back and never waits), `consent-guard.rb`, `test-guard.rb`, `remote_matcher.rb`, `codex/.codex/config.toml`.

## Order of work

1. Write `test/auto_accept_test.rb` `test_accepts_a_personal_artifact_with_a_closed_critique`. Run it. Watch it fail: no script.
2. Write `auto-accept` until that test passes. Then the refusal tests one at a time, red then green.
3. Write `test/herdr_worker_scripts_test.rb` auto tests, red, then `--auto` in `hand-off-plan.sh`, green. Run `shellcheck -x -S warning` on it.
4. Write `test/autonomy_contract_test.rb`, all red. Then edit `agents.md` and `core-values.yml`, green for their tests.
5. Edit `intent`, `spec`, `plan`, `implement`, `review`, `code-review`, `finish` skills, one commit each, each turning its contract tests green.
6. Link `code-review` for Codex, add its `openai.yaml`, update `skill_parity_test.rb`. Run it green.
7. Run every `test/*_test.rb`, then the linters `lefthook.yml` lists for each touched file type.
8. Grep the full branch diff for employer names and credentials. Nothing may match.
9. Re-read the full diff. Revert any hunk the spec does not require.

## Risks

- Contract tests prove the text exists, not that an agent obeys it. The real proof is the first end-to-end trial in `journal_administration`, after merge and stow. That trial is out of scope here.
- `auto-accept` is the only hard gate. A misbehaving agent could edit the `Status:` line by hand. The reviewer's compliance pass and Etienne's merge approval are the backstop.
- `codex` or `claude` CLI flags change between versions. The skills name the flags once each; re-verify with `--help` at implementation time.
- A Codex outage blocks critique and review. The coordinator treats that as a blocker and escalates; it never skips the critique.
- `review.md` gets a transcribed Codex round. The coordinator writes it, so the format can drift. Mitigation: the review skill shows the exact round format.
- Rejected: a separate `deliver` skill (spec says no new skill); a playbook-only loop (loads into every session); scripts for the Codex review, a scope refusal in `hand-off-plan.sh`, and a no-weakened-checks scan (Etienne chose only `auto-accept` as a gate).

Out of scope: picking and running the `journal_administration` trial; AI in GitHub Actions; deployment; any work-repo flow change; changes to `start-review.sh`.

## Proof

- Personal origin offers autonomous delivery → `test/autonomy_contract_test.rb` `test_intent_offers_autonomy_only_on_a_personal_origin`
- Other origin keeps "accepted" on the plan → `test/auto_accept_test.rb` `test_refuses_on_a_work_origin`, `test_refuses_without_an_origin`; `test/autonomy_contract_test.rb` `test_plan_keeps_the_literal_accepted_outside_auto`
- Accepted intent starts delivery with no further prompt → `test/herdr_worker_scripts_test.rb` `test_an_auto_worker_is_not_told_to_wait_for_accepted`; `test/autonomy_contract_test.rb` `test_intent_accept_starts_the_coordinator_loop`
- Auto plan accepted only after a recorded critique on an autonomous intent → `test/autonomy_contract_test.rb` `test_plan_auto_mode_runs_the_other_family_critique`; `test/auto_accept_test.rb` `test_refuses_without_a_critique_section`, `test_refuses_while_a_critique_finding_is_open`, `test_refuses_a_critique_section_without_a_round`, `test_refuses_a_step_by_step_intent`
- PR only after the reviewer and Codex leave no open finding → `test/autonomy_contract_test.rb` `test_review_auto_mode_runs_claude_and_codex_reviewers`
- Fixes in production code, no skipped test or disable comment → `test/autonomy_contract_test.rb` `test_playbook_autonomy_keeps_checks_strict`
- Behaviour change, new gem, three failed attempts → `test/autonomy_contract_test.rb` `test_playbook_lists_the_four_escalation_triggers`, `test_implement_auto_reports_a_decision_instead_of_adding_a_dependency`
- Finding disputed after two rounds goes to Etienne → `test/autonomy_contract_test.rb` `test_code_review_escalates_a_finding_disputed_for_two_rounds`
- PR comes with an account and is never merged → `test/autonomy_contract_test.rb` `test_intent_coordinator_writes_the_account_and_never_merges`, `test_core_values_say_agents_never_merge`
- Claude and Codex state the same boundaries → `test/autonomy_contract_test.rb` `test_plan_names_the_claude_critique_in_its_codex_section`; `test/skill_parity_test.rb` (existing, with `code-review` now shared)
- No employer name or credential → step 8 grep of the branch diff; a test cannot name the employer in this public repo.

Per changed file, the unit tests expected:

- `auto-accept`: `test_accepts_a_personal_artifact_with_a_closed_critique`, `test_changes_only_the_status_line`, `test_refuses_on_a_work_origin`, `test_refuses_without_an_origin`, `test_refuses_without_a_critique_section`, `test_refuses_a_critique_section_without_a_round`, `test_refuses_while_a_critique_finding_is_open`, `test_refuses_an_artifact_that_is_not_draft`
- `hand-off-plan.sh`: `test_an_auto_worker_is_told_to_invoke_the_skill_in_auto_mode`, `test_an_auto_worker_is_not_told_to_wait_for_accepted`, `test_an_auto_worker_is_not_told_to_chain_the_next_stage`, `test_an_auto_worker_reports_open_decisions`, `test_auto_is_refused_for_the_intent_stage`, `test_without_auto_the_prompt_is_unchanged`
- `agents.md` / `core-values.yml`: `test_playbook_carves_rule_17_out_for_personal_autonomy`, `test_core_values_mirror_the_carve_out`, plus the Proof lines above
- skills: the Proof lines above

Test setup: temp git repos with an `origin` remote and an isolated `HOME` holding an allowlist file, copied from `test/change_scope_test.rb`; the existing stub `herdr` in `test/herdr_worker_scripts_test.rb`; contract tests read repo files only.

## Rework (2026-10-07)

While this branch was in review, `main` removed the spec stage (`3d5aaf5c`, `da007c36`, `d2303f13`, `f8297596`). Etienne agreed to rework onto the two-stage chain. The rebase drops the spec skill's auto mode and `hand-off-plan.sh spec --auto`. The coordinator loop runs `plan`, then `implement`. The critique and `auto-accept` apply to `plan.md` only. The acceptance criterion "auto spec accepted only after a recorded critique" falls away; the plan critique carries the same guarantee.
