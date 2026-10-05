# Review: merge-spec-into-intent

## Round 1 — 2026-10-05T13:23Z — 40b7d835

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the passes use the reviewer's defaults (`claude/.claude/skills/new-repo-setup/references/REVIEW.md`). Branch is rebased on current `origin/main`. Shellcheck on both herdr scripts and rubocop on touched Ruby are clean. Full suite: every file green except `test/review_report_check_test.rb` (see Notes).

### Bugs

Nothing found. `worktree-create` strips `--no-pane` from anywhere in argv, so the flag-first form in `worktree-first/SKILL.md` works. `start-review.sh` escapes `\$HERDR_PANE_ID` for the close and leaves the caller's id unescaped for the report line, as intended. Removing the `spec)` case in `hand-off-plan.sh` leaves intent's `report_instruction` string intact.

### Security

Nothing found.

### Compliance

Acceptance criteria from `intent.md` against tests:

- Intent asks about in and out of scope → `test_the_intent_interview_asks_what_is_in_and_out_of_scope`
- Intent refuses "accepted" without acceptance criteria, names what is missing → `test_intent_refuses_acceptance_without_acceptance_criteria`, `test_intent_refuses_acceptance_with_open_questions_or_an_undecided_concern`
- Invoking `spec` finds no skill → `test_there_is_no_spec_skill_for_claude_or_codex`
- In-session intent opens no pane → `test_intent_creates_its_worktree_without_opening_a_pane` (text only; the pane behaviour itself is not exercised, as the plan's Risks note)
- Intent `handoff` opens exactly one pane with the agent → `test_handing_off_an_intent_stage_opens_exactly_one_pane_with_the_agent_in_it`
- Review pane closes after delivery → `test_the_reviewer_closes_its_own_pane_once_the_report_gets_through` (prompt text only; "on the first try or a retry" wording is not asserted)
- Review pane stays open on failure → `test_the_reviewer_leaves_its_pane_open_when_the_report_never_gets_through`
- Accepted intent hands off to plan → `test_each_accepting_skill_chains_once_to_its_next_stage_with_the_coordinator_id`, `test_the_spec_stage_is_no_longer_recognised`
- Plan needs an accepted intent, never a spec → `test_plan_reads_only_an_accepted_intent`, `test_the_plan_worker_reads_only_intent_md`
- Reviewer and test-writer read intent → `test_the_reviewer_and_test_writer_read_acceptance_criteria_from_intent`
- No live file names the spec stage → `test_nothing_live_names_the_spec_stage`

Every test named in `plan.md`'s `## Proof` exists.

- [ ] Important: Deleting `test_the_spec_and_plan_workers_report_what_was_decided_and_deferred` also dropped its plan half. Nothing now asserts that the plan worker's report covers "anything Etienne deferred"; the surviving check only locates "write what plan.md decided". Keep the plan assertion as its own test. — `test/herdr_worker_scripts_test.rb:313` →
- [ ] Nit: "`§4` of the spec" still reads as a stage reference. The plan made the other old-design citations explicit (`docs/changes/ai-native-workflow/spec.md §N`); this one was missed, and the stage-shaped regexes do not catch it. — `claude/.claude/skills/implement/SKILL.md:55` →
- [ ] Nit: `test/approval_word_test.rb` changed but `plan.md`'s "Files that change" does not list it. The change is needed (it tested the deleted skill); the plan is just incomplete. — `test/approval_word_test.rb` →
- [ ] Nit: The review-pane close test does not assert the "on the first try or a retry" wording, which the acceptance criterion names explicitly. — `test/herdr_worker_scripts_test.rb` →

### Notes

- `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` errors: `git commit --quiet -m advance main failed`. The test commits on `main` in a temp repo, and the global hooks refuse it. This branch does not touch that test or the script under it, so it is pre-existing and unrelated. Per playbook rule 25, fix it on a separate branch.
