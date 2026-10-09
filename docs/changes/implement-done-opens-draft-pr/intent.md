# Intent: Delivery ends with a draft PR; /finish ships it

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature. Delivery: autonomous.

## Problem

When implementation and review fixes are done, the change sits in a worktree until Etienne runs `/finish`. No PR exists yet, so Etienne cannot see the finished work in gh-dash or on GitHub. `/finish` then does the clean-up, the push and the PR in one go. The hand-over after that stays manual: on personal repos Etienne merges by hand; at work he sets the board status by hand.

## Proposed outcome

The agent that closes the last review round hands over a draft PR. It fills the PR body, closes its idle stage panes, removes `docs/changes/<slug>/`, pushes the branch and opens a draft PR. It then opens a herdr pane left of the intent pane, running gh-dash filtered to that PR.

`/finish` becomes the ship step:

- Personal: mark the PR ready, wait for green CI, merge it.
- Work: ask the ADR question, mark the PR ready, set its status to "Needs Review" on the team review board, request reviewers, open the PR in the Edge work profile.

## Affected users and systems

- Etienne, in both personal and work repositories.
- Skills in `dotfiles`: `finish`, `implement`, `review`, `code-review`, `intent` (autonomous delivery), and their shared scripts (`fill-pr-template`, `change-scope`).
- herdr scripts in `dotfiles` (`hand-off-plan.sh`, `start-review.sh`, or a new one) for the pane and gh-dash step.
- Playbook rules that describe the flow: §7 rule 5, §7a, and the mirror in `core-values.yml`.
- `dotfiles-work`: the private `after-push` script.
- Codex: `$finish` and the Codex coordinator, same behaviour.

## Constraints

- The public `dotfiles` repo never names work things (org, board, project). The board name and status write live in `dotfiles-work`'s `after-push`. This reverses the 2026-09-22 decision that board automation is out of scope.
- Claude and Codex keep parity: same steps, adapters only where tool formats differ.
- Playbook rule 6 holds: no PR comments as Etienne. Opening, editing, readying and merging the PR are not comments.
- Autonomous delivery: the coordinator never merges. Etienne typing `/finish` is the merge approval.
- The review freshness check that `/finish` runs today moves to the delivery step. The change folder is removed only after a round of each reviewer leaves no open finding.
- Delivery mode approved permissions: none needed. No dependencies, system tools, migrations or deploy files. Edits span two repositories, `dotfiles` and `dotfiles-work`, each with its own branch and PR.

## In scope

- Delivery ending, in both the step-by-step and the autonomous flow, run by the agent that closes the last review round:
  1. Check review freshness and that no finding is open.
  2. Fill the PR body from `intent.md` and `plan.md`.
  3. Close this change's idle or done stage panes.
  4. Remove `docs/changes/<slug>/` and commit that alone.
  5. Push the branch.
  6. Open a draft PR (or update the body of an existing one).
  7. Open a herdr pane left of the pane that wrote the intent, running gh-dash filtered to the new PR.
- Pane fallback: when the intent pane no longer exists, split left of the agent's own pane. Outside herdr, skip the pane and print the PR URL.
- `/finish`, personal: refuse without a PR; mark the PR ready; wait for CI; on green, merge with a merge commit and delete the remote branch; on red, stop and report the failing check and its link.
- `/finish`, work: refuse without a PR; ask the ADR question (the ADR is written from the PR body, since the folder is gone); run `after-push`, which marks ready, sets "Needs Review" on the board and opens the PR in Edge's work profile; then request reviewers as today.
- `/finish` auto mode (coordinator, personal only): mark ready and wait for green CI; never merge. Red CI: stop and report.
- `dotfiles-work`: `after-push` sets the board status to "Needs Review".
- Codex parity for all of the above.
- Docs that describe the flow: playbook, `core-values.yml`, skill files.

## Out of scope

- Deployment after merge.
- Fixing a red CI run automatically inside `/finish`.
- Cleaning up the local worktree after merge; the next `worktree-create` sweep does that.
- Branches with change work done before this ships: `/finish` refuses them instead of taking the old path.
- Any change to how intent, plan or implement run before the last review round.

## Acceptance criteria

- The reviewer's last round leaves no open finding. Without a further command, `docs/changes/<slug>/` is gone in its own commit, the branch is on `origin`, and a draft PR with the filled template body exists.
- Etienne wrote the intent in pane A. After delivery, a new pane sits directly left of pane A, running gh-dash that shows only the new PR.
- Pane A was closed before delivery ended. The gh-dash pane opens directly left of the delivering agent's pane instead.
- Delivery runs outside herdr. The draft PR still opens and its URL is printed; no pane opens.
- Delivery in autonomous mode: the coordinator opens the draft PR, marks it ready, waits for green CI, writes its account, and the PR stays unmerged.
- Etienne runs `/finish` on a personal repo with a draft PR. The PR turns ready, CI goes green, the PR is merged with a merge commit, and the remote branch is deleted.
- Etienne runs `/finish` on a personal repo and a CI check fails. The PR stays unmerged, and `/finish` names the failed check and its link.
- Etienne runs `/finish` on a work repo with a draft PR. The PR turns ready, its board status reads "Needs Review", the confirmed reviewers are requested, and the PR opens in Edge's work profile.
- Etienne runs `/finish` on a branch with no PR. It stops and says the delivery step has not run.
- The public `dotfiles` diff contains no work org, board or project name.
- Codex's `$finish` and Codex coordinator produce the same results as above.

## Open questions

None.
