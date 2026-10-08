---
name: finish
description: Closes a change once review is fresh — fills the PR body, asks about an ADR (work only), removes the change folder, pushes, and creates or updates the PR in both scopes; work also requests reviewers. Scope comes from the origin remote, not from asking. A coordinator may run it in auto mode on a personal repository.
disable-model-invocation: true
arguments:
  - name: dry-run
    description: Print every step this run would take, in order, and stop before doing anything.
---

# Finish

One skill, not two: personal and work do the same core thing — confirm the review is fresh, fill the PR body, remove `docs/changes/<slug>/`, commit, push, and open the PR — and differ only in the ADR question and the reviewer request, both work only. Runs only on explicit command (`/finish`), never on its own. It is the only step that opens a pull request: the consent guard refuses `gh pr create` and `gh pr merge` while the branch's own `docs/changes/<slug>/` exists.

`--dry-run`: print every step below with what it would do, then stop before doing anything — including no `gh pr create`. Etienne runs the first real use on a work PR this way and executes the printed steps by hand once; after that it is optional.

This skill assumes the review already happened — the freshness check below is the proof, not a second review.

## 1. Preconditions (both scopes)

Stop at the first failure and say why:

1. Run `~/.claude/skills/plan/scripts/change-folder` for the folder path.
2. `~/.config/git/worktree-tools/review-report-fresh` exits 0. Non-zero: "run `/review` first."
3. `<folder>/review.md` has no open finding without a later round closing it. Any that are open: list them — "close or dismiss these first."
4. The working tree is clean (`git status --porcelain` is empty).
5. `~/.claude/skills/finish/scripts/change-scope` resolves to `personal` or `work`. It exits 1 on a remote it does not recognise — stop and say so; this skill never guesses scope.

## 2. Work only: the ADR question

Ask: "Does this change affect another application: API contract, published event, shared schema, anything another team consumes?"

- **Yes**: distil `<folder>/intent.md` and `<folder>/plan.md` into an ADR — sections Context / Decision / Consequences — at the path pattern `~/.claude/finish/adr-location` names (one line, repo-relative, e.g. `docs/adr/NNNN-<slug>.md`), numbered one past the highest existing ADR. Commit it alone: `Add ADR NNNN: <title>`. That file is absent: ask where the ADR belongs before continuing — never guess a path.
- **No**: continue. Nothing else survives once the folder is removed.

## 3. Both scopes: the PR body

1. Find the template: `.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, or `docs/pull_request_template.md`. None found: continue with an empty template path — the filler still appends `## Summary` (Problem + Proposed outcome), `## Implementation` (the plan's file list only), and `## Proof` (the plan's acceptance-criteria lines only) from `intent.md` and `plan.md` alone — no `## Why`, and no Order-of-work or per-file unit-test detail.
2. Run `~/.claude/skills/finish/scripts/fill-pr-template <template-path-or-empty> <folder>/intent.md <folder>/plan.md`. Show the result to the user.
3. On confirmation: write the filled body to a `mktemp` file outside the repository, and record the PR title — the text after `# Intent:` in `<folder>/intent.md` — for §5. `<folder>` is removed in §4, so both must be captured here, not read again later.

## 4. Both scopes: remove the change folder

Before or alongside the removal below, close this change's own leftover stage panes. Outside herdr (`HERDR_ENV` unset): skip this step entirely.

1. `herdr pane list --workspace "$HERDR_WORKSPACE_ID"`. Select the panes whose `cwd` equals `$(git rev-parse --show-toplevel)` — `/finish` runs inside this change's own worktree, so its toplevel is the path to match, not a `.worktrees/<slug>` lookup from elsewhere — and whose `agent` is non-null and whose `agent_status` is `idle` or `done`. A pane with `agent: null` (an editor, a shell) is never a candidate, and neither is one with `agent_status: working`.
2. None match: continue silently. Some match: show them (pane id, title) and ask Etienne which to close — `AskUserQuestion`, every listed pane selected by default (Codex: a numbered list, same default). Close only the confirmed panes: `herdr pane close <id>` per pane.

`worktree-pane` stays as it is; this step talks to `herdr pane` directly instead, because `worktree-pane close` leaves any pane with an agent alone whatever its status, and would also reach panes this change never opened — an editor or a shell sharing the worktree's `cwd`.

`git rm -r docs/changes/<slug>`. When that leaves `docs/changes/` empty, remove the directory too — git does not track empty directories, so this is a plain `rmdir` on the working tree, not a git operation. Commit alone: `Remove change artifacts for <slug>`.

## 5. Both scopes: push and open the PR

1. `git push -u origin <branch>`. The consent guard governs which remote this may run against unattended; `--force-with-lease` only if this run rebased the branch, never plain `--force`.
2. `gh pr view --json number,url,isDraft` on this branch. §4 removed the change folder first, so the consent guard refuses `gh pr create` until it is gone:
   - **Exists**: `gh pr edit --body-file <the mktemp body file from §3>`.
   - **Missing**: `gh pr create --title "<the title recorded in §3>" --body-file <the mktemp body file from §3>`. Never `--draft`, in either scope — a personal repo has no board to hide the PR behind, and at work the team's board status is what governs visibility, not draft state.
3. Delete the mktemp body file.
4. **Work**: `~/.claude/finish/after-push` exists and is executable: run it with the PR number and URL (contract in §7) — it marks the PR ready and opens it in the work browser profile for the manual review-status step. It is absent: `gh pr view --web`, then print "no after-push script; open the PR and set the review status by hand." Non-zero exit: print its stderr and stop; do not request reviewers.
5. **Personal**: `gh pr view --web`.
6. Print what it did and the PR URL. Never comment on the PR (playbook rule 6) — this skill's only writes are the template edit, the ADR commit, the artifact-removal commit, the PR itself, and the reviewer list.

## 6. Work only: request reviewers

1. Confirm the reviewer list before requesting anyone; ask each time. Offer `~/.claude/finish/reviewers`'s list, when that file exists, as the starting point. Offer `~/.claude/finish/last-reviewers`'s list instead — the list last confirmed, one handle per line, kept across sessions rather than only this one — when `reviewers` is absent, or when the user picks "last used".
2. `gh pr edit --add-reviewer <confirmed list>`.
3. Write the confirmed list to `~/.claude/finish/last-reviewers`, one handle per line, replacing whatever was there before.

## 7. Contract for the private files

Supplied by `dotfiles-work` through its `claude` stow package (`STOW_SHARED`, file by file). This skill only reads `after-push`, `adr-location` and `reviewers`, and writes only `last-reviewers`; nothing here depends on what the others contain. Paths are `~/.claude/...` on purpose — one location, both Claude and Codex read it.

- `~/.claude/finish/after-push <pr-number> <pr-url>` — marks the PR ready and opens it in the work browser profile for the manual review-status step (board automation is out of scope, decided 2026-09-22). Exit 0: done. Non-zero: print stderr and stop before requesting reviewers.
- `~/.claude/finish/adr-location` — one line, the repo-relative ADR path pattern used in §2.
- `~/.claude/finish/reviewers` (optional) — one GitHub handle per line, the default reviewer list offered first in §6.
- `~/.claude/finish/last-reviewers` — one GitHub handle per line, written by this skill after every confirmed reviewer request; not supplied by `dotfiles-work`.

## Auto mode

Run by the autonomous-delivery coordinator on a personal repository only (`change-scope` prints `personal`). A `work` scope refuses auto mode and uses the steps above unchanged. Differences:

- §3 step 2: do not wait for confirmation of the PR body.
- §4: close every matching idle or done stage pane without asking.
- Never merge, and never comment on the PR.

## Codex

Same steps, same scripts (`change-scope`, `fill-pr-template`), same contract. Invoked as `$finish`; `--dry-run` prints the same steps. The board mechanism still lives in the private `after-push` script, not in this skill.
