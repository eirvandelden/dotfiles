# Plan: every stage after intent runs in a fresh agent pane

From `intent.md` and `spec.md` (2026-09-28). Status: accepted (2026-09-28).

## Files that change

- `herdr/.config/herdr/scripts/hand-off-plan.sh` — generalizes from `<plan-file> [<worktree-name>]` to `<stage> <change-slug>`, `stage` one of `spec`, `plan`, `implement`. `change-slug` is now required (it always names the worktree): the "no worktree name, worker in the main checkout" branch is dropped, since nothing calls that path today (grepped — only `implement`'s handoff call site exists, and it always passes a branch). Per stage: model (`opus`/`opus`/`sonnet`), extra `agent start` flag (`--permission-mode plan` for `plan` only), the "ready" word (`Spec ready:` / `Plan ready:` / `Handoff done:`, keeping implement's existing wording), and whether the pane pushes after finishing (spec and plan do; implement does not — pushing unreviewed code would fail the pre-push freshness check, so implement only commits and leaves the push to `/finish`). The prompt tells the pane to invoke the matching skill for the change folder rather than restating that skill's steps inline (see Design decisions). Report file, retry-twelve-times wording, and the new self-close step (`herdr pane close $HERDR_PANE_ID`, run right after the report line, whether or not that line got through) are shared across all three stages.
- `claude/.claude/skills/spec/SKILL.md` — new "Choosing a backend" section (pane by default inside herdr, `here` or no `HERDR_ENV` to run in this session), mirroring `review/SKILL.md`'s shape. Today's whole body becomes the `here` backend's content, unchanged.
- `claude/.claude/skills/plan/SKILL.md` — same split, for the **Write** role only. **Critique** and **Execute a handed-over plan** are untouched.
- `claude/.claude/skills/implement/SKILL.md` — mode argument changes from `single|split|handoff` to `here` (single/split, today's default logic, explicit now) with no argument defaulting to the pane backend (today's `handoff`). §5 becomes the "Pane backend" section; §3/§4 move under a "`here` backend" heading.
- `claude/.claude/skills/finish/SKILL.md` — one new step: before or alongside removing `docs/changes/<slug>/`, run `worktree-tools/worktree-pane close .worktrees/<slug>` if that worktree exists, so a stage pane whose work is done but never closed doesn't outlive the folder it was reading.
- `docs/changes/ai-native-workflow/habits.md` — reword habits 2–4 (Spec, Plan, Implement) to describe the pane-by-default flow, matching habit 5 (Review)'s existing wording; habit 4 drops "or `/implement handoff`" since that's the default now, not an option to name.
- `herdr/.config/herdr/README.md` — one line: "Worker scripts" paragraph currently says `hand-off-plan.sh` "hands a written plan"; reword for the generalized stage-launcher contract.
- `test/herdr_worker_scripts_test.rb` — `hand-off-plan.sh` section rewritten for the new `<stage> <change-slug>` contract; `start-review.sh` section untouched.

## Order of work

1. Write the first failing acceptance-level test: running `hand-off-plan.sh spec <slug>` outside herdr is refused, same shape as today's outside-herdr test but against the new argument list. Run it, watch it fail (script doesn't recognize the new signature yet).
2. Rewrite `hand-off-plan.sh`'s argument handling and usage message for `<stage> <change-slug>`; green the outside-herdr and missing-argument tests.
3. Port the worktree-resolution tests that don't depend on the old signature (linked worktree, submodule, submodule's linked worktree, awkward path, report directory creation failure, stale report cleared) to call the script with a stage argument; keep them passing against the existing `worktree-create`/`worktree-pane label` logic, now always exercised (no more no-name branch).
4. Add the per-stage table (model, extra flag, ready-word, push-or-not) to the script; add tests asserting `agent start` picks the right model and flag per stage, and that the prompt names the right skill, upstream artifact, and push/no-push instruction per stage.
5. Add the self-close step and its test: after the report line is sent (or after twelve failed retries), the script's prompt tells the pane to run `herdr pane close $HERDR_PANE_ID`.
6. Update `spec/SKILL.md`, `plan/SKILL.md`, `implement/SKILL.md` with the "Choosing a backend" / "Pane backend" / "`here` backend" sections described above. No test — these are prose skill files.
7. Update `finish/SKILL.md` with the leftover-stage-pane close step, `habits.md`'s habits 2–4, and `herdr/README.md`'s one line.
8. Run the full `test/herdr_worker_scripts_test.rb` suite, then lint every touched file (shellcheck-equivalent for the `.sh`, rubocop for the `.rb`, markdownlint for the `.md`).

## Risks

- **Dropping the no-worktree-name path** removes public behavior from `hand-off-plan.sh`. Grepped the repo first: `implement/SKILL.md` is the only caller, and it always passes a branch name. Safe, but flagged here since it's a real behavior removal, not just an addition.
- **Implement pane must not push.** The generic "commits the artifact, pushes the branch" wording in `spec.md` §6 fits spec/plan (one small artifact file) but not implement (code across many commits, no review yet). Resolved by intent's own constraint ("after implement, the push waits for the review pane's round") — implement's pane commits and stops, no push. Confirmed here so a future reader doesn't "fix" that as a missed step.
- **Self-close on a failed report** — rejected always waiting for the report line to succeed before closing. The report is durable (on disk, and for spec/plan also pushed), so the pane closes either way rather than sitting open indefinitely because the coordinator was busy for all twelve retries.
- **Prompt says "invoke the skill" rather than duplicating its steps** (interrogated and confirmed) — diverges from `start-review.sh`'s inline-instructions style, but a fresh Claude pane already has the Skill tool and the same skills loaded, so telling it which skill to invoke for which change folder is enough; duplicating steps in bash would give the same instructions two places to drift apart.

## Proof

- Requirement 1 (spec/plan/implement default to a fresh pane) → `test/herdr_worker_scripts_test.rb` `test_handing_off_a_spec_stage_splits_a_pane_below_here`, `test_handing_off_a_plan_stage_splits_a_pane_below_here`, `test_handing_off_an_implement_stage_splits_a_pane_below_here`
- Requirement 2 (stage name + change folder, not a literal artifact path) → `test_handing_off_takes_a_stage_and_a_change_slug`, `test_an_unrecognized_stage_name_is_refused`
- Requirement 3 (`start-review.sh` untouched) → no new test; existing `start-review.sh` tests in the same file must stay green unmodified.
- Requirement 4 (per-stage model, `plan` in plan mode) → `test_the_spec_stage_starts_claude_on_opus`, `test_the_plan_stage_starts_claude_on_opus_in_plan_mode`, `test_the_implement_stage_starts_claude_on_sonnet`
- Requirement 5 (stage's own conversation happens in the pane) → covered by requirement 2's tests asserting the prompt names the skill to invoke, not by a runtime test (nothing simulates the spawned agent's own conversation).
- Requirement 6 (commit artifact, push, report, message, retries) → `test_the_spec_worker_is_told_to_push_after_acceptance`, `test_the_plan_worker_is_told_to_push_after_acceptance`, `test_the_implement_worker_is_told_not_to_push`, `test_each_stage_worker_retries_a_busy_coordinator_but_gives_up_eventually` (ports today's `test_the_worker_retries_a_busy_initiator_but_gives_up_eventually`)
- Requirement 7 (report-to and close-self via `$HERDR_PANE_ID`) → `test_the_worker_is_told_where_to_report_and_who_to_tell` (ported), `test_the_worker_is_told_to_close_its_own_pane_after_reporting`
- Requirement 8 (coordinator never auto-chains) → no code changes needed; nothing in `hand-off-plan.sh` or the skills triggers a next stage automatically. No new test — an absence of behavior isn't provable by a unit test; covered by review reading the skill files.
- Requirement 9 (`implement`'s `here` keeps single/split; no-argument is the new pane default) → no unit test (prose skill file); covered by reading `implement/SKILL.md`'s diff in review.
- Requirement 10 (`finish` closes leftover stage panes) → no unit test in this file (that's `finish/SKILL.md`, prose); note in the plan for the reviewer to check the wording landed.
- Requirement 11 (outside-herdr fallback, unchanged) → `test_handing_off_outside_herdr_is_refused` (ported, same assertion, new argument list)
- Requirement 12 (this test file rewritten and covers all three stages plus self-close) → the whole rewritten file, self-verifying.

Per changed file, the unit tests expected, named as behaviour:

- `herdr/.config/herdr/scripts/hand-off-plan.sh`: `refuses an unrecognized stage name`, `refuses a missing change slug`, `still resolves the caller to the main checkout from a linked worktree` (ported), `still resolves the caller to the submodule checkout` (ported), `still resolves the caller to the submodule's linked worktree checkout` (ported), `survives an awkward repository path intact` (ported), `clears a stale report left by an earlier session` (ported), `stops before spawning anything when the report directory can't be created` (ported), `picks opus for spec`, `picks opus and plan mode for plan`, `picks sonnet for implement`, `names the worker <stage>-<pane>`, `tells the spec pane to invoke the spec skill and push once accepted`, `tells the plan pane to invoke the plan skill's write role and push once accepted`, `tells the implement pane to invoke implement here-mode and not push`, `tells every stage pane to close its own pane after reporting`

Test setup: same herdr/git stubs already in the file (`install_herdr_stub`, `install_git_recorder`, a temp repo per test); the `agent start` stub records the model and extra flags per call so tests can assert on them; no new fixtures needed.
