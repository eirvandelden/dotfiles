# Intent: Fewer agent commits

Author: Etienne van Delden. Status: accepted. Type: feature. Delivery: autonomous.

## Problem

Agents create many small commits that carry no lasting value. Autonomous review commits and pushes `review.md` every round ("Review round 6", "Close round 5 finding"). The `intent` and `plan` stages each commit their own document. When changes are requested after `deliver` removed `docs/changes/<slug>/`, an agent writes new intent and plan files in extra commits, and the old documents stay lost in history.

## Proposed outcome

A branch holds only the commits that matter. Review rounds leave one `review.md` commit at convergence. The stage documents arrive in one commit. After `deliver`, a change request brings the old documents back by dropping the commit that deleted them.

## Affected users and systems

Etienne, on personal and work repositories. The `intent`, `plan`, `review`, `deliver` and `finish` skills, the `reviewer` agent, and the herdr hand-off scripts.

## Constraints

- Playbook rules 17 and 20 stay in force: no code without an accepted `plan.md`; push after a rebase only with `--force-with-lease`.
- The pre-push review check and the consent guard keep working with the new flow.
- Squash-merge on work repositories needs no change.
- No new dependencies, system tools or deploy files.

## In scope

- Review rounds stay uncommitted (not pushed) until the reviewer and implementor agree that no change is needed. Then one commit holds `review.md`.
- `intent.md` and `plan.md` land in one commit, made once `plan.md` is accepted.
- A documented, repeatable way to restore a removed `docs/changes/<slug>/`: pull the latest branch, rebase to drop the commit that deleted the folder, push with `--force-with-lease`.
- Updates to the skills, agent definition and scripts that today commit per round or per stage document.

## Out of scope

- A cap on review rounds. The loop keeps its current stop rule.
- Moving change documents out of the branch.
- Squash-merge settings.
- Restoring documents on a branch that already merged. A new branch starts from main's history instead.

## Acceptance criteria

- A review that needs three rounds before the reviewer and implementor agree adds one `review.md` commit to the branch, not three.
- After a pull, a change request on a branch whose documents were deleted gives back `intent.md`, `plan.md` and `review.md` in `docs/changes/<slug>/`, and the branch history no longer holds the deleting commit.
- After the restore rebase, the push uses `--force-with-lease` and the consent guard accepts it.
- `intent.md` and `plan.md` for a new change appear in a single commit on the branch.
- A reviewer round that is still open leaves no pushed commit that only touches `review.md`.

## Flagged concerns

A rebase that drops a commit rewrites pushed history. On an open work PR, reviewers see the branch change. Chosen: use the rewrite, as Etienne decided, and push with `--force-with-lease`.

## Open questions

None.
