---
name: worktree-first
description: Use before writing, generating, or editing code for any new task in a git repository — sets up an isolated worktree under .worktrees/ so all commits and pushes happen there instead of the main checkout, sweeping merged worktrees for cleanup first.
---

# Worktree First

Never write code or push commits directly from the main checkout open in the current pane.
Every new coding task gets its own git worktree.

## Skip when

- The task is read-only: answering questions, reviewing a diff, exploring code.
- `git rev-parse --show-toplevel` already resolves inside a `.worktrees/` path — you're already
  isolated.
- The user explicitly asked to work in the main checkout.

## Step 1: sweep merged worktrees

Before creating a new one, clean up finished work so `.worktrees/` doesn't accumulate:

```bash
default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
git fetch origin "$default_branch"

for dir in .worktrees/*/; do
  [ -d "$dir" ] || continue
  branch=$(basename "$dir")
  state=$(gh pr view "$branch" --json state -q '.state' 2>/dev/null)
  merged_locally=$(git branch --merged "origin/$default_branch" 2>/dev/null | grep -qx "  $branch" && echo yes)
  if [ "$state" = "MERGED" ] || [ "$merged_locally" = "yes" ]; then
    git worktree remove "$dir" --force
    git branch -D "$branch" 2>/dev/null
  fi
done
```

If the check errors for a worktree (no PR yet, branch not pushed, detached HEAD) leave it — never
guess, never remove unmerged work.

## Step 2: create the worktree

```bash
branch="<kebab-case-task-slug>"
git worktree add ".worktrees/$branch" -b "$branch" "origin/$default_branch"
cd ".worktrees/$branch"
```

Verify `.worktrees/` is gitignored before the first worktree in an unfamiliar repo
(`git check-ignore -q .worktrees`) — already true globally on this machine via
`~/.config/git/ignore.global`, but a repo on another machine or a fresh clone may not have it.
If it isn't ignored, add the line and commit that alone before continuing.

## Step 3: project setup

Auto-detect and install dependencies the same way you would after a fresh clone — `bundle
install`, `npm install`/`yarn`, `cargo build`, `pip install`/`poetry install`, `go mod download`,
whatever the project's manifest calls for.

## Step 4: work, commit, push — all from here

Edits, commits, `git push`, `gh pr create` all run with the worktree as `cwd`. Never `cd` back
to the main checkout to commit or push. The worktree stays in place until a future task's Step 1
sweeps it, once its PR merges.

## Rails + SQLite projects

Also invoke the `using-sqlite-worktrees` skill (superpowers-ruby plugin) after dependency
install, before running tests — it copies the main checkout's dev/test databases into the new
worktree.
