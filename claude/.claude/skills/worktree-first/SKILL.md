---
name: worktree-first
description: Use before writing, generating, or editing code for any new task in a git repository — sets up an isolated worktree under .worktrees/ so all commits and pushes happen there instead of the main checkout, sweeping merged worktrees for cleanup first.
---

# Worktree First

Never write code or push commits directly from the main checkout open in the current pane.
Every new coding task gets its own git worktree.

This skill only handles the git worktree itself. On this machine, most projects also have their
own `git worktree-init` (symlinks `.env`/`master.key`, wires puma-dev/Caddy) — see Step 2.

## Skip when

- The task is read-only: answering questions, reviewing a diff, exploring code.
- Already inside a linked worktree — `[ "$(git rev-parse --git-dir)" != "$(git rev-parse
  --git-common-dir)" ]` is true. Checking for a literal `.worktrees/` path in the cwd misses
  worktrees kept elsewhere (e.g. `~/.config/superpowers/worktrees/`).
- The user explicitly asked to work in the main checkout.

## Step 1: sweep merged worktrees, then create the new one

Run this as a single script — the shell variables it sets (`default_branch`) don't survive
between separate commands, and re-deriving `default_branch` per step is wasted network calls.

```bash
git worktree prune

default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')
git fetch origin "$default_branch"

for dir in .worktrees/*/; do
  [ -d "$dir" ] || continue

  # Never touch a worktree with anything uncommitted, no matter what its PR/merge state says.
  [ -z "$(git -C "$dir" status --porcelain)" ] || continue

  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
  state=$(gh pr view "$branch" --json state -q '.state' 2>/dev/null)
  ancestor=yes
  git merge-base --is-ancestor "$branch" "origin/$default_branch" 2>/dev/null || ancestor=no

  if [ "$state" = "MERGED" ] || [ "$ancestor" = "yes" ]; then
    worktree_remove="${XDG_CONFIG_HOME:-$HOME/.config}/git/worktree-tools/worktree-remove"
    [ -x "$worktree_remove" ] && "$worktree_remove" "$dir"
    git worktree remove "$dir"
    git branch -d "$branch" 2>/dev/null
  fi
done

branch="<kebab-case-task-slug>"
git worktree add ".worktrees/$branch" -b "$branch" "origin/$default_branch"
cd ".worktrees/$branch" || exit
```

If a worktree's PR/merge check errors (no PR yet, branch not pushed, detached HEAD) leave it —
never guess, never remove unmerged work.

The new worktree branches from `origin/$default_branch`, not the main checkout's current HEAD —
deliberately different from the `spin()` shell function
(`zsh/.config/zsh/functions/worktree.zsh`), which branches from whatever the main checkout
happens to have checked out. A fresh-from-remote base means the task never inherits a stale or
dirty main checkout.

`.worktrees/` is already gitignored globally on this machine (`~/.config/git/ignore.global`). On
an unfamiliar machine or a fresh clone, check first (`git check-ignore -q .worktrees`); if it
isn't ignored, add it to `.git/info/exclude` (local-only — never commit a `.gitignore` change
into a repo you don't own without asking, per commit-scope-hygiene rules).

## Step 2: set up the worktree

```bash
git config --get alias.worktree-init >/dev/null 2>&1 && git worktree-init
```

Then install dependencies the same way you would after a fresh clone — `bundle install`, `npm
install`/`yarn`, `cargo build`, `pip install`/`poetry install`, `go mod download`, whatever the
project's manifest calls for. `git worktree-init` only handles symlinks and local-service
wiring; it does not install dependencies.

## Step 3: work, commit, push — all from here

Edits, commits, `git push`, `gh pr create` all run with the worktree as `cwd`. Never `cd` back
to the main checkout to commit or push. The worktree stays in place until a future task's Step 1
sweeps it, once its PR merges.

## Rails + SQLite projects

Also invoke the `using-sqlite-worktrees` skill (superpowers-ruby plugin) after dependency
install, before running tests — it copies the main checkout's dev/test databases into the new
worktree.
