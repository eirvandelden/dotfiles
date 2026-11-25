# Plan: Make main's CI green again after the intent removal

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-25). Type: bugfix. Delivery: step-by-step.

Repository `~/Developer/dotfiles`, branch `fix-main-ci-after-intent-removal`, in its own worktree off `origin/main`. Playbook rule 25: a red CI that the current task did not cause is fixed first, in its own pull request, and the pin PR #300 rebases on top.

## Problem

`main` is red on the `Dotfiles tests` workflow since the merge of PR #218 (`a6f0a6c1`). PR #218 branched before PR #298 (the merge of intent into plan), so two things it added now clash with #298. Pin PR #300 shows both failures in its CI run, although its own diff is one file.

1. `NoIntentReferencesTest#test_names_no_intent_artefact_outside_change_folders`: `test/lefthook_branch_files_test.rb:151` uses the path `agents/.agents/skills/intent/SKILL.md` as an example of a non-vendored skill file. The `intent` skill no longer exists.
2. `VendoredSkillsTest#test_every_upstream_skill_folder_is_marked_vendored`: `agents/.agents/skills/brainstorming/` carries an `<!-- upstream: ... -->` comment, so it is a vendored skill. `.gitattributes` has no `linguist-vendored` line for it. The `marker-check` hooks therefore do not skip its prose.

Both pass on the pin branch locally only because it does not contain #218.

## Proposed outcome

`bin/test` is green on `main`, and the `Dotfiles tests` workflow is green.

## In scope

- `test/lefthook_branch_files_test.rb`, the test `test_a_marker_in_a_non_vendored_skill_blocks_the_push` (lines 149 to 156): replace the `intent` skill path in the commit and in the `assert_match` regex with the path of an own, non-vendored skill that exists, `agents/.agents/skills/plan/SKILL.md`.
- `.gitattributes`: add `agents/.agents/skills/brainstorming/** linguist-vendored`, in alphabetical order between `android-intent-security` and `brakeman`.

## Out of scope

- The pin PR #300. It rebases on the fix after this one merges.
- The earlier `Install lefthook` step failure on the `#299` run. It is a transient infrastructure failure, and the later runs got past it.
- The CI Ruby version.

## Acceptance criteria

- `rv run -- bin/test test/no_intent_references_test.rb test/vendored_skills_test.rb test/lefthook_branch_files_test.rb` passes.
- `rv run -- bin/test` passes in full.
- The workflow `Dotfiles tests` is green on the fix's pull request.
- The test that checked the intent path still proves its point: a marker in a non-vendored skill blocks the push.

## Order of work

1. Run the three test files on `origin/main` and watch the two failures, the regression proof that comes first for a bug fix.
2. Change the test path. Commit: `Use an existing skill in the non-vendored marker test`.
3. Add the `.gitattributes` line. Commit: `Mark the brainstorming skill as vendored`.
4. Run the three files, then the full `bin/test` and `rubocop`.
5. Review, deliver, and have Etienne run `/finish`. Then rebase the pin branch.

## Risks

- `plan/SKILL.md` could later become vendored. The test names the path and would then fail loudly, which is the intended signal.
- Another pull request may still carry an old `intent` path. The same `NoIntentReferencesTest` catches it.

## Proof

- Failure 1 → `test/no_intent_references_test.rb` `test_names_no_intent_artefact_outside_change_folders`.
- Failure 2 → `test/vendored_skills_test.rb` `test_every_upstream_skill_folder_is_marked_vendored`.
- The test keeps its meaning → `test/lefthook_branch_files_test.rb` `test_a_marker_in_a_non_vendored_skill_blocks_the_push`.
- Whole suite → check: `rv run -- bin/test`, 0 failures.

Test setup: existing tests only. This fix adds no new test: the two failing tests already prove the bug, and the third is edited in place.
