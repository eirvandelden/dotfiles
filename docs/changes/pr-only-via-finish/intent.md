# Intent: Only /finish creates pull requests

Author: Etienne van Delden de la Haije. Status: accepted.
Type: feature
Delivery: autonomous

## Problem

A pull request can exist while `docs/changes/<slug>/` is still in the branch, because nothing stops `gh pr create` or a GitHub-UI PR before `/finish` ran. Etienne has merged such PRs more than once, leaving intent and plan files on `main`. Also, `implement` and `review` do not push at their end, so the remote branch lags behind the work.

## Proposed outcome

`/finish` is the only way a pull request comes into being, and it removes the change folder first. Every phase leaves its work on the remote branch.

## Affected users and systems

Etienne and every agent working in a repository that uses the intent, plan, implement, review and finish skills. Dotfiles skills (`finish`, `implement`, `review`, `intent`, `plan`), the herdr `hand-off-plan.sh` and `start-review.sh` scripts, the consent guard, and the global git `pre-push` hook. Both are stowed into many repositories; lefthook is configured per repository.

## Constraints

- Playbook rule 12: edit sources in `~/Developer/dotfiles/<package>/`, never run `stow`.
- Playbook rule 13: no `.github/workflows/` edit. Etienne approved it, then ruled out a CI check, because dotfiles are symlinked into many repositories and lefthook is configured per repository. Guards live in stowed hooks and the consent guard instead.
- Playbook rule 6: agents never merge; `finish` never comments on the PR.
- Approved permissions for autonomous delivery: none beyond editing dotfiles files. No new dependency, no migration, no deploy file.

## In scope

- `finish` is the only skill step that runs `gh pr create`; no other skill, script or coordinator text opens a PR.
- The consent guard refuses `gh pr create` while `docs/changes/<slug>/` exists in the working tree; `finish` runs it only after removal.
- The global `pre-push` freshness check is skipped for a branch that has `docs/changes/` and no open PR, so a work-in-progress push succeeds. Once the folder is gone or a PR is open, the strict check applies.
- `implement` and `review` push the branch at their end (`git push -u origin HEAD`), as `intent` and `plan` already do. The herdr hand-off prompts and skill text say so.
- The consent guard also refuses `gh pr merge` while `docs/changes/` exists in the PR's branch tree, where it can tell.

## Out of scope

- A GitHub Actions or other CI check.
- Merges from the GitHub UI; no local hook can see them.
- Changing the review-freshness rule for the final push in `finish`.
- Per-repository lefthook files in repositories other than dotfiles.

## Acceptance criteria

- Running `gh pr create` on a branch that still has `docs/changes/pr-only-via-finish/` is refused with a message naming `/finish`.
- After `/finish` removes the folder, its `gh pr create` succeeds.
- Pushing a branch with `docs/changes/` and no PR succeeds without a fresh review.
- Pushing a branch with no `docs/changes/` and a stale review is refused, as today.
- When `implement` ends, the branch and its commits are on `origin`.
- When `review` ends, its `review.md` round is on `origin`.
- `gh pr merge` on a branch whose tree still has `docs/changes/` is refused.

## Flagged concerns

- Etienne chose to drop the CI check because it protects one repository, but without it a UI-created PR and a UI merge stay possible. Chosen side: hooks and the consent guard only; the UI gap is accepted and out of scope.

## Open questions

None. Etienne confirmed the guards live in the stowed hooks and the consent guard, with no CI check.
