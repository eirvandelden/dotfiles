---
name: worktree-first
description: Use before writing, generating, or editing code for any new task in a git repository — sets up an isolated worktree under .worktrees/ so all commits and pushes happen there instead of the main checkout, sweeping merged worktrees for cleanup first.
---

# Worktree First

Never write code or push commits directly from the main checkout open in the current pane.
Every new coding task gets its own git worktree under `.worktrees/`.

That means never `git checkout -b`/`git switch -c` a feature branch in the main checkout either
— that's just working directly on main's disk with extra steps. The main checkout stays on
whatever branch it's already on; every other branch lives in a worktree.

This skill only handles the git worktree itself. On this machine, a global `git worktree-init`
alias (symlinks `.env`/`master.key`, wires puma-dev/Caddy) is also available — see Step 2.

## Skip when

- The task is read-only: answering questions, reviewing a diff, exploring code.
- Already inside a linked worktree — `[ "$(git rev-parse --git-dir)" != "$(git rev-parse
  --git-common-dir)" ]` is true. Checking for a literal `.worktrees/` path in the cwd misses
  worktrees kept elsewhere (e.g. `~/.config/superpowers/worktrees/`).
- The user explicitly asked to work in the main checkout.

## Step 1: sweep merged worktrees, then create the new one

Run this as a single script — the shell variable it sets (`default_branch`) doesn't survive
between separate commands.

```bash
git worktree prune

default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[ -n "$default_branch" ] || default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
[ -n "$default_branch" ] && [ "$default_branch" != "(unknown)" ] || { echo "cannot determine default branch"; exit 1; }
git fetch origin "$default_branch"

find .worktrees -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r dir; do
  # Never touch a worktree with anything uncommitted, no matter what its PR/merge state says.
  [ -z "$(git -C "$dir" status --porcelain)" ] || continue

  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
  state=$(gh pr view "$branch" --json state -q '.state' 2>/dev/null)

  # A worktree just created off origin/$default_branch, with nothing committed and no PR opened
  # yet, is trivially its own ancestor — skip it, or a concurrent task's brand-new worktree gets
  # swept from under it. Once it has a PR (any state, including MERGED), it's no longer "fresh"
  # even if a fast-forward merge left its tip identical to origin/$default_branch again.
  if [ -z "$state" ] && [ "$(git rev-parse "$branch")" = "$(git rev-parse "origin/$default_branch")" ]; then
    continue
  fi

  ancestor=yes
  git merge-base --is-ancestor "$branch" "origin/$default_branch" 2>/dev/null || ancestor=no

  if [ "$state" = "MERGED" ] || [ "$ancestor" = "yes" ]; then
    worktree_remove="${XDG_CONFIG_HOME:-$HOME/.config}/git/worktree-tools/worktree-remove"
    [ -x "$worktree_remove" ] && "$worktree_remove" "$dir"
    git worktree remove "$dir"

    # -D once GitHub itself confirms MERGED: a squash-merged branch is never an ancestor of
    # main, so the safe -d refuses it and leaks the branch forever. Ancestor-confirmed branches
    # (no PR, or a fast-forward merge) still go through -d.
    if [ "$state" = "MERGED" ]; then
      git branch -D "$branch" 2>/dev/null
    else
      git branch -d "$branch" 2>/dev/null
    fi
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

## Rails + SQLite projects (Claude Code only)

Also invoke the `using-sqlite-worktrees` skill (superpowers-ruby plugin) after dependency
install, before running tests — it copies the main checkout's dev/test databases into the new
worktree. Its script resolves paths via `${CLAUDE_PLUGIN_ROOT}`, so it only works under Claude
Code even though the plugin files also exist in Codex's cache.
