# Plan: Autonomous-delivery account lives in the change folder

From `intent.md` (2026-11-04). Status: accepted.

## Design

### Domain terms

Account: the coordinator's record of a finished autonomous delivery (`GLOSSARY.md` has no entry; no new term).

### Diagrams

Not affected: no objects change, only skill prose, one script prompt and tests.

### Signatures

Not affected: no Ruby method changes.

### Complexity

Not affected: one extra commit per autonomous delivery.

### Invariants

The account commit lands before `deliver` runs, so `deliver` removes it with the rest of the folder and it stays in history.

### Alternatives

- Write the account uncommitted after `deliver`. Rejected: git never records it, which is the problem.
- Commit the account after `deliver`, on the PR branch. Rejected: it recreates `docs/changes/<slug>/` on an open PR, and the merge guard reads the head commit and refuses to merge while the folder exists.
- Keep `.git/herdr/deliver-<slug>.md`. Rejected: that is the current behaviour.

The architects were not run: the change moves one path in prose, so there is no object design to compare.

## Design decisions

- The account is committed with a plain `git add` of that one file and a `docs: delivery account for <slug>` commit. `commit-plan` and `commit-review` commit other files, so neither fits.
- A commit that touches only the change folder does not make `review.md` stale: `review-report-fresh` looks at changes outside the folder.
- After `deliver` the file is gone from the tree. The coordinator names the in-repo path in `Delivery done:`, and the account commit holds its content.

## Integration points

- `deliver` (clean-tree and fresh-report preconditions, removal commit): read, not changed.
- `finish` (`ship --no-merge`): read, not changed.
- `hand-off-plan.sh`: its prompt already says "the account file path"; no change needed.

## Files that change

- `agents/.agents/skills/intent/SKILL.md` — "Autonomous delivery": step 6 writes and commits the account to `docs/changes/<slug>/deliver.md` before `deliver`; step 7 runs `deliver` and `finish`; step 8 is the final message with the PR URL and the CI result; the paragraph below names the in-repo path.
- `test/autonomy_contract_test.rb` — pin the new path and the order, and refuse the old path.

## Order of work

1. Change `test_intent_coordinator_writes_the_account_and_never_merges` to expect `docs/changes/<slug>/deliver.md` and add the order and old-path tests. Run them and watch them fail.
2. Edit the `intent` skill's "Autonomous delivery" section.
3. Run the narrow test file, then the full suite and the linters.

## Risks

- A later reader may look for the account on disk after delivery. The final message names the path and the commit holds it.
- `Delivery done:` is pinned by `test/herdr_worker_scripts_test.rb`; the wording there does not change.

## Proof

- An autonomous delivery commits `docs/changes/<slug>/deliver.md` before the pull request opens → `test/autonomy_contract_test.rb` `test_the_account_is_committed_before_deliver_runs`
- After `deliver`, `git log -- docs/changes/<slug>/deliver.md` shows the account → check: the section commits the file in its own commit before it runs `deliver`, which removes the folder in a later commit.
- The `Delivery done:` line names the in-repo path → `test/autonomy_contract_test.rb` `test_the_delivery_done_line_names_the_in_repo_account_path`
- The final message carries the PR URL and the CI result → `test/autonomy_contract_test.rb` `test_the_final_message_carries_the_pull_request_url_and_the_ci_result`
- No skill, script or test mentions `<git-common-dir>/herdr/deliver-<slug>.md` → `test/autonomy_contract_test.rb` `test_nothing_names_the_old_account_path`

Per changed file, the unit tests expected:
- `test/autonomy_contract_test.rb`: the four tests above, plus the updated `test_intent_coordinator_writes_the_account_and_never_merges`.

Test setup: none; the tests read the skill text.

---
Domain skills applied: None.
