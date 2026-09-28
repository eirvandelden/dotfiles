# Plan: `fill-pr-template`'s appended sections duplicate content and oversize the PR body

From `intent.md` and `spec.md` (2026-09-25). Status: accepted.

Reproduction status: Round 1 review found the fixture did not match a real plan's shape, so `test/fill_pr_template_test.rb` is extended to match it — see `review.md`.

## Files that change

- `claude/.claude/skills/finish/scripts/fill-pr-template` — the fix. Adds a `summary_text` helper shared by `filler` (unchanged, used for the categorized/templated path) and a new `appended_filler` (used only by `appended_sections`). Adds `acceptance_criteria`, a line filter over the plan's Proof section. Threads a second `appended_fill` hash through `fill_template`/`appended_sections` alongside the existing `fill`.
- `test/fill_pr_template_test.rb` — renames the two tests that assert today's appended behavior (`test_a_template_with_no_matching_headings_gets_four_sections_appended`, `test_no_template_produces_four_sections_from_intent_and_plan_alone`) to assert the new one; adds a `PLAN_WITH_NESTED_PROOF` fixture variant whose Proof section carries a column-0 per-file unit-test list after the plan skill's fixed lead-in ("Per changed file…"), to prove the extraction drops it.
- `claude/.claude/skills/finish/SKILL.md` §3 step 1 — the sentence describing the no-template output (currently: "the filler still produces the four `## Summary` / `## Why` / `## Implementation` / `## Proof` sections from `intent.md` and `plan.md` alone").
- `docs/changes/ai-native-workflow/phases/04-finish.md` step 1 — the same rule, described at greater length; updated in the same commit as the code so it doesn't depart from it.

## Order of work

1. Add a `PLAN_WITH_NESTED_PROOF` fixture (acceptance-criteria bullets followed by a column-0 per-file unit-test list after the plan skill's fixed lead-in, "Per changed file, the unit tests expected, named as behaviour:") and write the failing test for the trimmed appended output: no `## Why` heading, `## Implementation` holding only the file list (no "Write the acceptance test" Order-of-work text), `## Proof` holding only the criteria lines before the lead-in (not the per-file list after it, even when a per-file bullet itself quotes a `→` inside backticks). Run `ruby test/fill_pr_template_test.rb`, watch it fail for the right reason (today's code still emits Why and the full plan).
2. Update the two existing appended-path tests to match: rename `test_a_template_with_no_matching_headings_gets_four_sections_appended` and `test_no_template_produces_four_sections_from_intent_and_plan_alone` (three sections now, not four), replace their `assert_match(/## Why/, ...)` with `assert_no_match`. Run — still red.
3. Implement the fix: `summary_text(intent)`, `appended_filler(intent, plan)`, `acceptance_criteria(plan)` (stop at the plan skill's fixed lead-in lines, "Per changed file" / "Test setup", then keep only the remaining top-level bullets whose `→` arrow is followed by a backtick; indentation plays no part). Thread `appended_fill` through `appended_sections`/`fill_template`, update the script's bottom call site. Run `ruby test/fill_pr_template_test.rb` — green. (Updated 2026-09-28, review round 2: the column-0-only rule from an earlier draft of this step let a real plan's per-file unit-test list through, because that list is written at column 0 too — see Risks. Updated again, review round 3: an arrow alone was still not enough, because a per-file bullet can quote a `→` inside backticks — the lead-in cutoff and the arrow-plus-backtick shape are the two signals that fix it.)
4. Update `claude/.claude/skills/finish/SKILL.md` §3 step 1's wording to match (three sections; Implementation = file list only; Proof = criteria lines only).
5. Update `docs/changes/ai-native-workflow/phases/04-finish.md` step 1's wording to match, in the same commit as the code per playbook rule 5.
6. Run the full test suite (`for f in test/*_test.rb; do ruby "$f" || break; done`) to confirm no regressions elsewhere.
7. Lint the touched Ruby (rubocop, per playbook rule §7.2) and fix anything it flags — no disable comments.
8. Re-read the full diff (playbook rule 21): confirm no unrelated hunks, then commit.

## Risks

- Rejected alternative: filtering Proof by structure (parsing "top-level list item" via a Markdown list parser) instead of a plain line-based scan. Rejected — the existing script has no Markdown list parser and doesn't need one; the lead-in line and the arrow-plus-backtick shape are the actual signals for an acceptance-criteria bullet. (Updated 2026-09-28, review round 2: an earlier draft of this step matched column-0 bullets instead of the arrow, on the assumption that a real plan's per-file unit-test list is written more indented. It is not — the `plan` skill's own shape writes that list at column 0 too, so a column-0-only match let it through. Updated again, review round 3: an arrow alone was not enough either, because a per-file bullet can quote a `→` inside backticks — see `spec.md`'s design decision for the two-signal rule that replaced it.)
- Risk: a Proof section whose bullets carry no `→` arrow at all (an older or hand-written plan) keeps all its top-level bullets unchanged, rather than being emptied out — see `spec.md`'s design decision on the fallback.
- Out of scope (per accepted intent's Constraints): the templated path's matching rules; the `finish` flow itself; capturing a review-round count in the PR body (would need `finish` §3 changed to survive `review.md`'s deletion — a bigger, separate change).

## Proof

- With no template, the PR body's Summary holds the Problem and the Proposed outcome → `test/fill_pr_template_test.rb` `test_no_template_produces_three_sections_from_intent_and_plan_alone` (renamed).
- With no template, the PR body has no Why section → `test/fill_pr_template_test.rb` `test_no_template_produces_three_sections_from_intent_and_plan_alone`.
- With no template, the PR body's Implementation section holds the file list only, not Order of work → `test/fill_pr_template_test.rb` `test_no_template_produces_three_sections_from_intent_and_plan_alone`.
- With no template, the PR body's Proof section holds the acceptance-criteria bullets before the plan skill's lead-in only, not the column-0 per-file unit-test list after it → `test/fill_pr_template_test.rb` `test_an_appended_proof_section_drops_the_per_file_unit_test_list_after_its_lead_in` (new).
- With no template and a plan with no Proof section, the PR body has no Proof heading → `test/fill_pr_template_test.rb` `test_a_missing_proof_in_the_plan_is_not_appended_as_an_empty_heading` (existing, unchanged assertions — still proves the rule under the new code path).
- With a template whose headings match Why, Implementation, and Test, each still gets today's full content → `test/fill_pr_template_test.rb` `test_a_plain_template_gets_its_matching_headings_filled` (existing, unchanged assertions — regression coverage for the categorized path).

Per changed file, the unit tests expected, named as behaviour:
- `claude/.claude/skills/finish/scripts/fill-pr-template`: `summary_text` builds Problem + Proposed outcome (exercised indirectly through the tests above — no direct unit test for a private top-level helper in a single-file script); `acceptance_criteria` stops at the plan skill's fixed lead-in lines and keeps only the remaining bullets whose `→` is followed by a backtick, falling back to all remaining top-level bullets when none carry that shape (exercised by the nested-list test above and by the no-arrow test; updated 2026-09-28, review rounds 2 and 3).

Test setup: fixtures now include `PLAN_WITH_NESTED_PROOF` and `PLAN_WITH_PROOF_WITHOUT_ARROWS` heredoc constants, plus an inline asterisk-bullet plan heredoc local to `test_an_appended_proof_section_keeps_an_asterisk_bullet_with_an_arrow`, alongside the existing `INTENT`/`PLAN`/`PLAN_WITHOUT_PROOF`; no faked boundaries — the script only reads the two file paths `run_fill` already writes to a tmpdir.

## Verification

- `ruby test/fill_pr_template_test.rb` green.
- Full suite: `for f in test/*_test.rb; do ruby "$f" || break; done` green (no regression in unrelated tests).
- Rubocop on the touched Ruby file, clean.
- Manual read-through: `claude/.claude/skills/finish/SKILL.md` §3 and `docs/changes/ai-native-workflow/phases/04-finish.md` step 1 both describe the new three-section, trimmed output — no stale "four sections" wording left.

## Out of scope

The templated path's matching rules. The `finish` flow itself. Anything outside `finish/`'s `fill-pr-template` script and its two description docs. Capturing a review-round count in the PR body.
