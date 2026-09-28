# Plan: `fill-pr-template`'s appended sections duplicate content and oversize the PR body

From `intent.md` and `spec.md` (2026-09-25). Status: accepted.

Reproduction: committed.

## Files that change

- `claude/.claude/skills/finish/scripts/fill-pr-template` — the fix. Adds a `summary_text` helper shared by `filler` (unchanged, used for the categorized/templated path) and a new `appended_filler` (used only by `appended_sections`). Adds `acceptance_criteria`, a line filter over the plan's Proof section. Threads a second `appended_fill` hash through `fill_template`/`appended_sections` alongside the existing `fill`.
- `test/fill_pr_template_test.rb` — renames the two tests that assert today's appended behavior (`test_a_template_with_no_matching_headings_gets_four_sections_appended`, `test_no_template_produces_four_sections_from_intent_and_plan_alone`) to assert the new one; adds a `PLAN` fixture variant with a nested, more-indented per-file unit-test list under a Proof bullet, to prove the extraction drops it.
- `claude/.claude/skills/finish/SKILL.md` §3 step 1 — the sentence describing the no-template output (currently: "the filler still produces the four `## Summary` / `## Why` / `## Implementation` / `## Proof` sections from `intent.md` and `plan.md` alone").
- `docs/changes/ai-native-workflow/phases/04-finish.md` step 1 — the same rule, described at greater length; updated in the same commit as the code so it doesn't depart from it.

## Order of work

1. Add a `PLAN_WITH_NESTED_PROOF` fixture (an acceptance-criteria bullet followed by a more-indented per-file unit-test bullet underneath it) and write the failing test for the trimmed appended output: no `## Why` heading, `## Implementation` holding only the file list (no "Write the acceptance test" Order-of-work text), `## Proof` holding only the top-level criteria line (not the nested unit-test line). Run `ruby test/fill_pr_template_test.rb`, watch it fail for the right reason (today's code still emits Why and the full plan).
2. Update the two existing appended-path tests to match: rename `test_a_template_with_no_matching_headings_gets_four_sections_appended` and `test_no_template_produces_four_sections_from_intent_and_plan_alone` (three sections now, not four), replace their `assert_match(/## Why/, ...)` with `assert_no_match`. Run — still red.
3. Implement the fix: `summary_text(intent)`, `appended_filler(intent, plan)`, `acceptance_criteria(plan)` (keep only lines matching `/^-\s/` — column-0 bullets — from the plan's Proof section), thread `appended_fill` through `appended_sections`/`fill_template`, update the script's bottom call site. Run `ruby test/fill_pr_template_test.rb` — green.
4. Update `claude/.claude/skills/finish/SKILL.md` §3 step 1's wording to match (three sections; Implementation = file list only; Proof = criteria lines only).
5. Update `docs/changes/ai-native-workflow/phases/04-finish.md` step 1's wording to match, in the same commit as the code per playbook rule 5.
6. Run the full test suite (`for f in test/*_test.rb; do ruby "$f" || break; done`) to confirm no regressions elsewhere.
7. Lint the touched Ruby (rubocop, per playbook rule §7.2) and fix anything it flags — no disable comments.
8. Re-read the full diff (playbook rule 21): confirm no unrelated hunks, then commit.

## Risks

- Rejected alternative: filtering Proof by structure (parsing "top-level list item" via a Markdown list parser) instead of a plain `/^-\s/` line match. Rejected — the existing script has no Markdown list parser and doesn't need one; a per-file unit-test list is written more indented specifically so a column-0-only match is sufficient and matches the spec's stated rule directly.
- Risk: a Proof section that already omits indentation for its own reasons (a flat list with no per-file breakdown) still works today — the new filter is a strict subset of "no indentation", so nothing already flat is affected.
- Out of scope (per accepted intent's Constraints): the templated path's matching rules; the `finish` flow itself; capturing a review-round count in the PR body (would need `finish` §3 changed to survive `review.md`'s deletion — a bigger, separate change).

## Proof

- With no template, the PR body's Summary holds the Problem and the Proposed outcome → `test/fill_pr_template_test.rb` `test_no_template_produces_three_sections_from_intent_and_plan_alone` (renamed).
- With no template, the PR body has no Why section → `test/fill_pr_template_test.rb` `test_no_template_produces_three_sections_from_intent_and_plan_alone`.
- With no template, the PR body's Implementation section holds the file list only, not Order of work → `test/fill_pr_template_test.rb` `test_no_template_produces_three_sections_from_intent_and_plan_alone`.
- With no template, the PR body's Proof section holds the acceptance-criteria lines only, not a nested per-file unit-test list → `test/fill_pr_template_test.rb` `test_an_appended_proof_section_drops_a_nested_per_file_unit_test_list` (new).
- With no template and a plan with no Proof section, the PR body has no Proof heading → `test/fill_pr_template_test.rb` `test_a_missing_proof_in_the_plan_is_not_appended_as_an_empty_heading` (existing, unchanged assertions — still proves the rule under the new code path).
- With a template whose headings match Why, Implementation, and Test, each still gets today's full content → `test/fill_pr_template_test.rb` `test_a_plain_template_gets_its_matching_headings_filled` (existing, unchanged assertions — regression coverage for the categorized path).

Per changed file, the unit tests expected, named as behaviour:
- `claude/.claude/skills/finish/scripts/fill-pr-template`: `summary_text` builds Problem + Proposed outcome (exercised indirectly through the tests above — no direct unit test for a private top-level helper in a single-file script); `acceptance_criteria` drops indented lines (exercised by the new nested-list test above).

Test setup: no new fixtures beyond one `PLAN_WITH_NESTED_PROOF` heredoc constant alongside the existing `INTENT`/`PLAN`/`PLAN_WITHOUT_PROOF`; no faked boundaries — the script only reads the two file paths `run_fill` already writes to a tmpdir.

## Verification

- `ruby test/fill_pr_template_test.rb` green.
- Full suite: `for f in test/*_test.rb; do ruby "$f" || break; done` green (no regression in unrelated tests).
- Rubocop on the touched Ruby file, clean.
- Manual read-through: `claude/.claude/skills/finish/SKILL.md` §3 and `docs/changes/ai-native-workflow/phases/04-finish.md` step 1 both describe the new three-section, trimmed output — no stale "four sections" wording left.

## Out of scope

The templated path's matching rules. The `finish` flow itself. Anything outside `finish/`'s `fill-pr-template` script and its two description docs. Capturing a review-round count in the PR body.
