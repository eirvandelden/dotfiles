---
name: sync
description: Use when asked to sync, rebase, or update a branch with main (or a named base branch) — fetch, rebase, resolve conflicts, verify green, push --force-with-lease.
---

# Branch Sync (rebase on main)

Invoked by `/sync`, "sync this branch", "rebase on main", "fetch main and rebase", or any
request to bring a branch up to date before pushing or updating a PR.

A sync request is permission to rebase the current branch and push it with
`--force-with-lease`. It is not permission for anything else: no unrelated commits, no other
branches, no PR creation unless asked.

## Workflow

1. Verify the current branch is a feature branch. On `main`/`master`: stop and ask.
2. Uncommitted changes: if the request says to commit them, commit in small logical commits
   first; otherwise ask before committing (playbook rule: commit only with explicit approval).
3. `git fetch origin main`.
4. Rebase onto `origin/main` — or onto the explicitly named base branch for stacked PRs
   (`/sync <base-branch>`); then also verify the PR targets that base.
5. Conflicts: resolve each file on its own merits — re-read both sides and keep the intent of
   both changes. Never blindly discard one side. Stage resolved files, `git rebase --continue`,
   repeat until the rebase completes.
6. Run linters and the full test suite; both must be green. Fix only failures caused by the
   rebase or by your own changes; report pre-existing failures without fixing them.
7. `git push --force-with-lease`. Never plain `--force`.

## Rules

- Rebase, never merge main into the branch.
- Never rebase `main`/`master` itself.
- After any rebase, pushing requires `--force-with-lease`.
- A sync must not change the diff against the base beyond conflict resolution. If the diff
  grew, something went wrong in step 5 — stop and report.
