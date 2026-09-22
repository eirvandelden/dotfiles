---
name: finish
description: Closes a change once review is fresh — personal deletes the change folder and stops for merge, work also fills the PR template, asks about an ADR, pushes, and requests reviewers. Scope comes from the origin remote, not from asking.
disable-model-invocation: true
arguments:
  - name: dry-run
    description: Print every step this run would take, in order, and stop before doing anything.
---

# Finish

One skill, not two: personal and work do the same core thing — confirm the review is fresh,
delete `docs/changes/<slug>/`, commit — and differ only in what happens around that. Runs only
on explicit command (`/finish`), never on its own.

`--dry-run`: print every step below with what it would do, then stop before doing anything.
Etienne runs the first real use on a work PR this way and executes the printed steps by hand
once; after that it is optional.

This skill assumes the review already happened — the freshness check below is the proof, not a
second review.

## 1. Preconditions (both scopes)

Stop at the first failure and say why:

1. Run `claude/.claude/skills/plan/scripts/change-folder` for the folder path.
2. `git/.config/git/worktree-tools/review-report-fresh` exits 0. Non-zero: "run `/review` first."
3. `<folder>/review.md` has no open finding without a later round closing it. Any that are open:
   list them — "close or dismiss these first."
4. The working tree is clean (`git status --porcelain` is empty).
5. `claude/.claude/skills/finish/scripts/change-scope` resolves to `personal` or `work`. It exits
   1 on a remote it does not recognise — stop and say so; this skill never guesses scope.

## 2. Work only: fill the PR template

1. Confirm a PR exists for this branch: `gh pr view --json number,url,isDraft`. None: stop and
   say so — `finish` prepares and pushes an existing branch, it does not open PRs.
2. Find the template: `.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`,
   `PULL_REQUEST_TEMPLATE.md`, or one under `docs/`. None found: continue with an empty template
   path — the filler still produces a `## Context` block from `intent.md` and `plan.md` alone.
3. Run `claude/.claude/skills/finish/scripts/fill-pr-template <template-path-or-empty>
   <folder>/intent.md <folder>/plan.md`. Show the result to the user before writing it anywhere.
4. On confirmation: `gh pr edit --body-file <the result>`.

## 3. Work only: the ADR question

Ask: "Does this change affect another application: API contract, published event, shared schema,
anything another team consumes?"

- **Yes**: distil `<folder>/intent.md` and `<folder>/spec.md` into an ADR — sections Context /
  Decision / Consequences — at the path pattern `~/.claude/finish/adr-location` names (one line,
  repo-relative, e.g. `docs/adr/NNNN-<slug>.md`), numbered one past the highest existing ADR.
  Commit it alone: `Add ADR NNNN: <title>`. That file is absent: ask where the ADR belongs
  before continuing — never guess a path.
- **No**: continue. Nothing else survives once the folder is removed.

## 4. Both scopes: remove the change folder

`git rm -r docs/changes/<slug>`. When that leaves `docs/changes/` empty, remove the directory
too — git does not track empty directories, so this is a plain `rmdir` on the working tree, not a
git operation. Commit alone: `Remove change artifacts for <slug>`.

## 5. Personal: stop here

Print the merge command (`gh pr merge <number>` when a PR exists, otherwise the plain merge
instructions for this branch) and stop. No push unless asked.

## 6. Work only: push and hand off to the team

1. `git push`. The consent guard governs which remote this may run against unattended;
   `--force-with-lease` only if this run rebased the branch, never plain `--force`.
2. `~/.claude/finish/after-push` exists and is executable: run it with the PR number and URL
   (contract in §7). It is absent: print "no after-push script; open the PR and set the review
   status by hand."
3. Confirm the reviewer list before requesting anyone: ask each time, offering
   `~/.claude/finish/reviewers`'s list (or the list confirmed last time, if this session already
   asked once) as the starting point rather than silently reusing it.
4. `gh pr edit --add-reviewer <confirmed list>`. Print what ran and the PR URL.
5. Never comment on the PR (playbook rule 6) — this skill's only writes are the template edit,
   the ADR commit, the artifact-removal commit, and the reviewer list.

## 7. Contract for the private files

Supplied by `dotfiles-work` through its `claude` stow package (`STOW_SHARED`, file by file).
This skill only reads them; nothing here depends on what they contain. Paths are `~/.claude/...`
on purpose — one location, both Claude and Codex read it.

- `~/.claude/finish/after-push <pr-number> <pr-url>` — marks the PR ready and opens it in the
  work browser profile for the manual review-status step (board automation is out of scope,
  decided 2026-09-22). Exit 0: done. Non-zero: print stderr and stop before requesting reviewers.
- `~/.claude/finish/adr-location` — one line, the repo-relative ADR path pattern used in §3.
- `~/.claude/finish/reviewers` (optional) — one GitHub handle per line, the default reviewer
  list offered in §6.

## Codex

Same steps, same scripts (`change-scope`, `fill-pr-template`), same contract. Invoked as
`$finish`; `--dry-run` prints the same steps. The board mechanism still lives in the private
`after-push` script, not in this skill.
