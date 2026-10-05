# Plan: Merge the spec step into intent

From `intent.md` (2026-10-02). Status: accepted. Critiqued by Codex (default profile) on 2026-10-02; findings folded in. No `spec.md` exists by design: this change removes the spec stage, so this plan reads the accepted `intent.md` directly (one-off, approved by Etienne).

## Context

The workflow is intent → spec → plan → implement. The spec stage repeats the intent and adds a pane and an acceptance round. This change removes it. Intent absorbs scope boundaries (in/out), acceptance criteria and flagged concerns, and interviews until no ambiguity is left. Plan absorbs design decisions, integration points and domain skills. Two bugfixes ride along: in-session intent opens an empty herdr pane below, and a review pane stays open after it delivers its report.

Worktree: `.worktrees/merge-spec-into-intent`, branch `merge-spec-into-intent`. Tests are plain Minitest, run with `ruby -Itest test/<file>_test.rb` (CI runs every `test/*_test.rb`). Skill behaviour is tested through the SKILL.md text, as `test/herdr_worker_scripts_test.rb` already does for the stage chain.

## Files that change

Skills:
- `claude/.claude/skills/spec/` — deleted (`git rm -r`), with its Codex symlink `agents/.agents/skills/spec`.
- `claude/.claude/skills/intent/SKILL.md` — frontmatter description and header comment; step 1 invokes `worktree-first` in its no-pane mode (so no pane opens, and dependency install and the SQLite copy still run); the interview has no fixed count and covers problem, outcome, affected users/systems, constraints, in scope, out of scope, acceptance criteria as concrete domain examples, and conflicting constraints; stopping rule: the interview ends when every template section can be filled without guessing; a new red flag ("about to write the file with no in/out-scope question asked"); template gains `## In scope`, `## Out of scope`, `## Acceptance criteria`, and `## Flagged concerns` (omitted when none); step 4 refuses "accepted" while acceptance criteria are missing, while `## Open questions` is anything but "None.", or while a flagged concern names no chosen side, and names what is missing; then chains to `hand-off-plan.sh plan`; "that is `spec`'s job" becomes plan's; Codex section drops `spec`.
- `claude/.claude/skills/worktree-first/SKILL.md` — a no-pane mode: a caller that continues in the current session (the intent skill) passes `--no-pane` to `worktree-create`. A plain invocation still opens a pane, unchanged.
- `claude/.claude/skills/intent/agents/openai.yaml` — short description names scope and acceptance criteria.
- `claude/.claude/skills/plan/SKILL.md` — description "Use once intent.md is accepted"; pane and `here` backends read only `intent.md`; a new step applies domain skills (moved from spec) and flags conflicts; template header "From `intent.md`", plus `## Design decisions`, `## Integration points`, and a closing "Domain skills applied:" line; `## Proof` maps each acceptance criterion from `intent.md`.
- `claude/.claude/skills/implement/SKILL.md` — reads acceptance criteria from `intent.md`; split-mode default counts intent's criteria; "Unlike `spec` and `plan`" → "Unlike `intent` and `plan`".
- `claude/.claude/skills/review/SKILL.md`, `claude/.claude/skills/finish/SKILL.md` (ADR distils `intent.md` and `plan.md`), `claude/.claude/skills/new-repo-setup/SKILL.md` (chain `intent` → `plan` → `implement`), `claude/.claude/skills/new-repo-setup/references/REVIEW.md` — `spec.md` → `intent.md`.

Agents (Claude source, Codex generated):
- `claude/.claude/agents/reviewer.md`, `claude/.claude/agents/test-writer.md` — read acceptance criteria from `intent.md`.
- `codex/.codex/agents/reviewer.toml`, `codex/.codex/agents/test-writer.toml` — regenerated with `bin/generate-codex-agents`, never hand-edited.

Scripts:
- `herdr/.config/herdr/scripts/hand-off-plan.sh` — drop the `spec` case; plan's role instruction reads only `intent.md`; usage and header comments list `intent, plan, implement`; every stage now splits down, so the `direction`/`direction_word` variables go and the split is hard-coded `--direction down` with "below" in the closing echo.
- `herdr/.config/herdr/scripts/start-review.sh` — after the report line gets through (first try or a retry), the reviewer runs `herdr pane close \$HERDR_PANE_ID` (escaped, so the reviewer's own pane id expands in its shell, not the caller's id); if all twelve attempts fail, it leaves the pane open and says so. Same for the spec.md read: the reviewer reads `intent.md` and `plan.md`.
- `herdr/.config/herdr/README.md` — stage list and split direction.

Playbook and index:
- `agents.md` (is `claude/.claude/PLAYBOOK.md`) — §5 chain line, rule 17 (plan from an accepted `intent.md`; `intent`, `plan`, `implement`), rule 24 (Sonnet for `implement` only). `core-values.yml` mirrors nothing spec-related, so it stays.
- `SKILLS-INDEX.md` — drop the spec entry; intent's entry names scope and acceptance criteria.

Comments that cite the old design doc as bare `spec.md §N` — make the path explicit (`docs/changes/ai-native-workflow/spec.md §N`) so they do not read as a stage reference: `bin/generate-codex-agents`, `claude/.claude/hooks/test-guard.rb`, `git/.config/git/worktree-tools/review-report-fresh`, `test/codex_agent_generation_test.rb`, `test/test_guard_test.rb`.

Comments that list the chain as `intent/spec/plan/implement` — drop `spec`: `claude/.claude/skills/plan/scripts/change-folder`, `test/change_folder_test.rb`, and the header of `test/herdr_worker_scripts_test.rb`.

Tests:
- New `test/artifact_chain_skills_test.rb` — the acceptance tests below.
- `test/herdr_worker_scripts_test.rb` — spec-stage tests removed; tests that used `spec` as the generic stage switch to `plan` (worker `plan-w1-pv`); `RIGHT_SPLIT_STAGES` and the right-split branch of `worker_name` go; the chain test becomes `{ "intent" => "plan", "plan" => "implement" }`; new review-pane close tests.
- `test/approval_word_test.rb` — `test_the_spec_skill_flips_status_to_accepted_when_agreed` removed, because the spec skill is gone; the intent equivalent stays (added during implement, missed by this plan).

## Order of work

0. Rebase onto `origin/main` first: PR #174 (`agreed` as an alias for `accepted`) landed after this branch was cut and touches the acceptance wording in the skills this plan rewrites. Keep its wording in every rewritten Accept step.
1. Write `test/artifact_chain_skills_test.rb` with the first acceptance test (intent asks about in and out of scope), run it, watch it fail.
2. Add the remaining acceptance tests in that file and the new tests in `test/herdr_worker_scripts_test.rb`; run both, confirm each fails for the reason its criterion implies.
3. Add the no-pane mode to `worktree-first/SKILL.md`. Rewrite `intent/SKILL.md` and its `openai.yaml`. Intent tests go green, including the `--no-pane` one.
4. Rewrite `plan/SKILL.md`; plan tests go green.
5. Change `hand-off-plan.sh` and update the existing herdr tests (switch `spec` → `plan`, drop spec-only tests, new chain map). `ruby -Itest test/herdr_worker_scripts_test.rb` green.
6. Change `start-review.sh` for the close-after-delivery bugfix; review-pane tests green.
7. Delete the spec skill and its symlink; `test/skill_parity_test.rb` and the "no spec skill" test green.
8. Update implement, review, finish, new-repo-setup, REVIEW.md, reviewer.md, test-writer.md; run `bin/generate-codex-agents`; `test/codex_agent_generation_test.rb` green.
9. Update `agents.md`, `SKILLS-INDEX.md`, herdr README, the five comment citations and the three chain-list comments; the "no live spec references" test goes green.
10. Full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. Lint: `rubocop` on touched Ruby, `shellcheck` on both scripts, lefthook pre-commit hooks (cspell, no-hardwrap) on the markdown.
11. Re-read the full diff; commit in small logical commits (tests, intent, plan, hand-off script, review-pane fix, spec removal, references).

## Risks

- The review-pane tests check the reviewer's prompt instructions (close on delivery, stay open after twelve failures). The harness records prompts and never runs a reviewer, so real pane behaviour is checked by hand once, in herdr.
- `start-review.sh` interpolates its prompt at script time: an unescaped `$HERDR_PANE_ID` would make the reviewer close the caller's pane. The test asserts the literal `$HERDR_PANE_ID` and the "not the caller's id" wording.
- The "no live spec references" test can false-positive on RSpec, `spec/` paths, "specific", and the past folder `docs/changes/ai-native-workflow/`. It matches only stage-shaped patterns (`` `spec` ``, `spec.md` not preceded by `ai-native-workflow/`, `hand-off-plan.sh spec`, `$spec`, `spec skill`, `intent/spec`, `spec/plan`, `intent, spec`) and scans only live directories (`claude/`, `agents/`, `codex/`, `herdr/`, `git/`, `bin/`, `agents.md`, `SKILLS-INDEX.md`). The `docs/changes/` folders stay out.
- Any in-flight change folder with a `spec.md` loses its spec stage. Intent rules this out of scope; none exists besides `ai-native-workflow`, which is past its spec stage.
- Rejected: intent calling `worktree-create --no-pane` directly. It would skip `worktree-first`'s dependency install and SQLite copy (Codex critique, 2026-10-02).
- Rejected: keeping a `direction` variable that is "down" for every stage. That is dead code once spec goes.

## Out of scope

- Rewriting `spec.md` or any other file under `docs/changes/ai-native-workflow/`.
- Pane behaviour of plan, implement, or a plain `worktree-first` call.
- The in-session reviewer subagent, which has no pane.
- Adding an out-of-scope check to the reviewer's compliance pass.

## Proof

- An intent interview asks about what is in and out of scope before it writes the file → `test/artifact_chain_skills_test.rb` `test_the_intent_interview_asks_what_is_in_and_out_of_scope`
- Intent refuses "accepted" while it has no acceptance criteria, and names what is missing → `test/artifact_chain_skills_test.rb` `test_intent_refuses_acceptance_without_acceptance_criteria` and `test_intent_refuses_acceptance_with_open_questions_or_an_undecided_concern`
- Invoking `spec` finds no skill → `test/artifact_chain_skills_test.rb` `test_there_is_no_spec_skill_for_claude_or_codex` (asserts neither `claude/.claude/skills/spec` nor `agents/.agents/skills/spec` exists, checking `File.symlink?` too, since `skill_parity_test.rb` skips dangling symlinks)
- Running intent in the current session inside herdr creates the worktree and opens no new pane → `test/artifact_chain_skills_test.rb` `test_intent_creates_its_worktree_without_opening_a_pane` (intent invokes `worktree-first` in no-pane mode, and `worktree-first` passes `--no-pane` in that mode) and the existing `test/worktree_create_test.rb` `test_no_pane_flag_skips_opening_a_pane`
- Intent's `handoff` backend still opens exactly one pane, with the agent in it → `test/herdr_worker_scripts_test.rb` `test_handing_off_an_intent_stage_opens_exactly_one_pane_with_the_agent_in_it`
- A review pane closes itself after its report reaches the caller, on the first try or a retry → `test/herdr_worker_scripts_test.rb` `test_the_reviewer_closes_its_own_pane_once_the_report_gets_through`
- A review pane whose report never gets through stays open → `test/herdr_worker_scripts_test.rb` `test_the_reviewer_leaves_its_pane_open_when_the_report_never_gets_through`
- An accepted intent hands off straight to plan; no spec pane starts → `test/herdr_worker_scripts_test.rb` `test_each_accepting_skill_chains_once_to_its_next_stage_with_the_coordinator_id` (map `intent → plan`) and `test_the_spec_stage_is_no_longer_recognised`
- Plan refuses to start without an accepted intent, and never asks for a spec → `test/artifact_chain_skills_test.rb` `test_plan_reads_only_an_accepted_intent` and `test/herdr_worker_scripts_test.rb` `test_the_plan_worker_reads_only_intent_md`
- The reviewer and test-writer read acceptance criteria from intent, not spec → `test/artifact_chain_skills_test.rb` `test_the_reviewer_and_test_writer_read_acceptance_criteria_from_intent`
- No live skill, agent, hook, script or playbook rule names the spec stage → `test/artifact_chain_skills_test.rb` `test_nothing_live_names_the_spec_stage`

Per changed file, the unit tests expected:
- `worktree-first/SKILL.md`: `a plain invocation still opens a pane`.
- `intent/SKILL.md`: `the interview stops when every section can be filled without guessing`, `the template holds in scope, out of scope, acceptance criteria and flagged concerns sections`, `the interview has no fixed question count`, `accepting chains to plan`.
- `plan/SKILL.md`: `the template holds design decisions and integration points`, `plan applies domain skills`.
- `hand-off-plan.sh`: `every stage splits its pane below`, `the usage message lists intent, plan and implement`.
- `start-review.sh`: `the reviewer closes its own pane id, not the caller's`.
- `reviewer.toml`, `test-writer.toml`: covered by the existing `test_every_committed_codex_agent_matches_what_the_generator_produces_now`.

Test setup: text assertions read files from the repo (`File.read`), as the existing chain test does; script tests reuse the herdr stub and `worktree_creatable!` helper in `test/herdr_worker_scripts_test.rb`. No new fixtures.
