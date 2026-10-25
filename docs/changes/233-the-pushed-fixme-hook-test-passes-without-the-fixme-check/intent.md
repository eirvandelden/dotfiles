# Intent: The pushed-fixme hook test passes without the fixme check

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix.
Delivery: autonomous. Codex review: no.

## Problem

`test_pre_push_uses_global_fallback_and_rejects_a_pushed_fixme` in `test/lefthook_local_hooks_test.rb` cannot detect a broken pre-push `no-fixme` check. A push in its setup is refused for another reason.

Cause, reproduced on 2026-10-21: the pre-push `review-report-fresh` job runs `~/.config/git/worktree-tools/review-report-fresh`. The test's `HOME` is a temporary directory without that script, so the job exits 127 and refuses every push. The `no-fixme` refusal is redundant, and a changed fixme pattern (the marker with an X appended, or `NOSUCHMARKER`) fails no test.

## Proposed outcome

The test proves that the pre-push `no-fixme` check refuses a pushed marker. In the same setup, a push without a marker succeeds, so no other job can hide a broken fixme check.

## Affected users and systems

- `test/lefthook_local_hooks_test.rb` and its pre-push setup.
- The global lefthook fallback (`lefthook.yml`, pre-push jobs) as exercised by the test.

## Constraints

- Bug fix: the regression proof comes first and fails before the fix (playbook rule 3).
- No new dependencies.
- Permissions: the change needs none under playbook rules 8, 9, 11, 12 or 13. Any such need is a stop-and-ask.

## In scope

- Make the test setup provide `review-report-fresh`, so a clean push succeeds.
- Make the fixme test fail when the pre-push fixme pattern in `lefthook.yml` changes.

## Out of scope

- The pre-commit `no-fixme` check and its tests.
- Other pre-push jobs' behaviour.
- The `review-report-fresh` job exits 127 on a machine without the stowed worktree-tools. Other jobs skip quietly in that case. That fix is a separate issue.

## Acceptance criteria

- Changing the pre-push fixme pattern in `lefthook.yml` to the marker with an X appended, or to `NOSUCHMARKER`, makes the test fail.
- A push of a file without the marker succeeds in the same test setup.

## Decisions

- Test only; the missing-script behaviour of the hook goes to a separate issue — it is an independent change.
- Autonomous delivery, no Codex review — no reason given.

## Open questions

None.
