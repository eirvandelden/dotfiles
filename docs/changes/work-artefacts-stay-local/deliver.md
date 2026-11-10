# Delivery account: work-artefacts-stay-local

## Behaviour delivered

- On a work repository, `commit-plan` and `commit-review` commit nothing and warn when `docs/changes` is not ignored. `deliver` leaves the local change folder in place, checks the reviewed commit against HEAD and opens the draft PR. `restore` has nothing to restore.
- Personal repositories keep committing artefacts. The review commit subject is now `docs: review findings for <first finding>`, at most 72 characters.
- `worktree-sweep` removes a merged worktree whose only dirt is untracked `docs/changes/` files. Other dirt still blocks removal.
- The consent guard and `review-report-fresh` needed no code change. Tests pin their behaviour.
- A fixed slot with a scoped commit subject, such as `fixed (fix(deliver): …)`, now closes its finding. The old pattern read it as open.

## Evidence

- Behaviour check in a temporary repository with a work origin: `change-scope` printed `work`. `commit-plan` committed nothing and exited 0, with and without `docs/changes` in `.git/info/exclude`. The warning appeared only without it.
- Regression test for the scoped slot failed before the pattern fix and passes after it.

## Check results

- `bin/test`: 116 files, 1 failed. `test/secrets_loader_test.rb` fails on a 1Password authorization timeout, and fails the same way on `main`.
- `rubocop` clean on the changed Ruby files. `shellcheck` clean on the stage scripts.

## Review outcome

- Three rounds. Round 1: five nits, all fixed. Round 2: one Important finding and two nits, all fixed. Round 3: nothing found.
- The reviewer found employer repository names in the committed `intent.md` and `plan.md`. The branch was unmerged, so the first commit was rewritten and pushed with `--force-with-lease`.

## Notes

- Etienne adds `docs/changes` to each work repository's `.git/info/exclude` once.
- `~/.claude/skills/review/scripts/commit-review` and `deliver` resolve to the main checkout until this branch merges. This delivery ran the branch's own scripts.
- The `terra` Codex profile names an unsupported model. It is outside this change.
