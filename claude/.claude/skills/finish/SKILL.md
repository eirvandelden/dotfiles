---
name: finish
description: Ships the draft PR the delivery step opened — marks it ready, waits for green CI and merges it (personal); work asks about an ADR, runs the private work hook (ready, team review board status, work browser) and requests reviewers. Scope comes from the origin remote, not from asking. A coordinator runs its auto mode on a personal repository.
disable-model-invocation: true
arguments:
  - name: dry-run
    description: Print every step this run would take, in order, and stop before doing anything.
---

# Finish

`/finish` ships a change. The `deliver` skill already removed `docs/changes/<slug>/`, pushed the branch and opened a draft PR. This skill takes that PR the rest of the way. It runs on explicit command (`/finish`), or by the autonomous coordinator in auto mode (below). Etienne's `/finish` is the merge approval. The consent guard refuses `gh pr create` and `gh pr merge` while the branch's own `docs/changes/<slug>/` exists; `deliver` removed it, so both pass here.

`--dry-run`: print the steps below for the scope that applies, then stop before doing anything.

## 1. Precondition: the PR exists

Look the PR up: `gh pr list --head <branch> --state open --json number,url,isDraft`.

- Empty list: stop. Say "No pull request for this branch: the delivery step has not run." Never create a PR here.
- `gh` exits non-zero: stop and print its stderr. An error is not an empty list.

Then run `~/.claude/skills/finish/scripts/change-scope`. It exits 1 on a remote it does not recognise. Stop and say so. This skill never guesses scope.

## 2. Personal: ship

```bash
~/.claude/skills/finish/scripts/ship
```

The script marks a draft PR ready and waits for CI. It merges with a merge commit and deletes the remote branch. It stops unmerged when a check fails, and prints each failed check with its link. It also stops unmerged when no checks appear within `SHIP_CHECKS_GRACE` seconds. Report what it printed. Never comment on the PR.

## 3. Work: ADR, after-push, reviewers

1. Ask: "Does this change affect another application: API contract, published event, shared schema, anything another team consumes?"
   - Yes: distil the PR title and body (`gh pr view --json title,body`) into an ADR with the sections Context, Decision and Consequences. The change folder is gone, so the PR body is the source. Write it at the path pattern `~/.claude/finish/adr-location` names (one line, repo-relative), numbered one past the highest existing ADR. Commit it alone: `Add ADR NNNN: <title>`. Push it. When the file is absent, ask where the ADR belongs. Never guess a path.
   - No: continue.
2. Run `~/.claude/finish/after-push <pr-number> <pr-url>` when it exists and is executable (contract in section 5). Non-zero exit: print its stderr and stop. Do not request reviewers. When it is absent, run `gh pr view --web` and print "no after-push script; mark the PR ready and set the review status by hand."
3. Confirm the reviewer list before requesting anyone, each time. Offer the list in `~/.claude/finish/reviewers` when that file exists. Offer `~/.claude/finish/last-reviewers` instead when `reviewers` is absent, or when the user picks "last used".
4. `gh pr edit --add-reviewer <confirmed list>`.
5. Write the confirmed list to `~/.claude/finish/last-reviewers`, one handle per line, replacing what was there.

## 4. Report

Print what ran and the PR URL. This skill never comments on the PR (playbook rule 6). Its only writes are the ready mark, the merge, the ADR commit, the reviewer list and the files `after-push` writes.

## 5. Contract for the private files

`dotfiles-work` supplies these through its `claude` stow package. Paths are `~/.claude/...` on purpose: Claude and Codex read one location.

- `~/.claude/finish/after-push <pr-number> <pr-url>` — marks the PR ready, sets the status "Needs Review" on the team review board, then opens the PR in the work browser profile. Exit 0: done. Non-zero: print stderr and stop before requesting reviewers.
- `~/.claude/finish/review-board` — private. Line 1: the board's project owner. Line 2: the project number. `after-push` stops before any change when it is missing or empty.
- `~/.claude/finish/adr-location` — one line, the repo-relative ADR path pattern used in section 3.
- `~/.claude/finish/reviewers` (optional) — one GitHub handle per line, the default reviewer list.
- `~/.claude/finish/last-reviewers` — one handle per line, written by this skill after every confirmed reviewer request. Not supplied by `dotfiles-work`.

## Auto mode

Run by the autonomous-delivery coordinator on a personal repository only (`change-scope` prints `personal`), right after `deliver`. `deliver` already removed `intent.md`, so the coordinator's own delivery is the proof of `Delivery: autonomous`. A `work` scope refuses auto mode and uses the steps above unchanged. Differences:

- Run `~/.claude/skills/finish/scripts/ship --no-merge` instead of `ship`. It marks the PR ready and waits for green CI.
- Never merge, and never comment on the PR. Etienne's `/finish` is the merge approval.

## Codex

Same steps, same scripts (`change-scope`, `ship`), same contract. Invoked as `$finish`; `--dry-run` prints the same steps. The board mechanism lives in the private `after-push` script, not in this skill.
