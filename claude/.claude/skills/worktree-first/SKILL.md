---
name: worktree-first
description: Use before writing, generating, or editing code for any new task in a git repository — sets up an isolated worktree under .worktrees/ so all commits and pushes happen there instead of the main checkout, sweeping merged worktrees for cleanup first.
---

# Worktree First

Never write code or push commits directly from the main checkout open in the current pane. Every new coding task gets its own git worktree under `.worktrees/`.

That means never `git checkout -b`/`git switch -c` a feature branch in the main checkout either — that's just working directly on main's disk with extra steps. The main checkout stays on whatever branch it's already on; every other branch lives in a worktree.

This skill only handles the git worktree itself. On this machine, a global `git worktree-init` alias (symlinks `.env`/`master.key`, wires puma-dev/Caddy) is also available — see Step 2.

## Skip when

- The task is read-only: answering questions, reviewing a diff, exploring code.
- The session is already in `<main checkout>/.worktrees/<branch>` for this task's branch. The Step 1 snippet checks this and reuses that worktree. Any other worktree, including another one under `.worktrees/`, is not a reason to skip.
- The user explicitly asked to work in the main checkout.

## Step 1: sweep merged worktrees, then create the new one

Branch naming: with a known GitHub issue, `<issue-number>-<issue-title-in-kebab-case>` — the same name GitHub's own "Create a branch" button generates. Without one, a kebab-case task slug. No prefix either way.

```bash
if [ -n "$issue_number" ]; then
  title=$(gh issue view "$issue_number" --json title -q '.title')
  slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
  branch="${issue_number}-${slug}"
else
  branch="<kebab-case-task-slug>"
fi
```

Then run:

```bash
top=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
parent=$(cd "$top/../.." 2>/dev/null && pwd -P)
if [ "$(git rev-parse --abbrev-ref HEAD)" = "$branch" ] \
  && [ -n "$parent" ] && [ "$top" = "$parent/.worktrees/$branch" ] \
  && [ "$(git -C "$parent" rev-parse --git-dir)" = "$(git -C "$parent" rev-parse --git-common-dir)" ]; then
  : # already in this task's worktree under the main checkout
else
  worktree_path=$(~/.config/git/worktree-tools/worktree-create "$branch") || exit 1
  cd "$worktree_path"
fi
```

Never type `git worktree add` yourself; use `worktree-create`. A hook refuses a `git worktree add` whose target is not `<main checkout>/.worktrees/<name>`.

`worktree-create` prunes stale admin files, fetches `origin`'s default branch, sweeps worktrees that are merged, gone, or fast-forwarded into it — leaving anything dirty, with an open PR, or freshly branched with nothing committed yet — then branches the new worktree off `origin/<default>`, not the main checkout's current HEAD. That's deliberately different from the `spin()` shell function (`zsh/.config/zsh/functions/worktree.zsh`), which branches from whatever the main checkout happens to have checked out: a fresh-from-remote base means the task never inherits a stale or dirty main checkout. It refuses if `.worktrees` isn't gitignored (`git check-ignore -q .worktrees` — already true on this machine via `~/.config/git/ignore.global`; on an unfamiliar machine or a fresh clone, add it to `.git/info/exclude` first, local-only) or if the name is empty. If a worktree's PR/merge check errors (no PR yet, branch not pushed, detached HEAD) it leaves it — never guessing, never removing unmerged work.

Inside herdr, a pane rooted in the new worktree opens below; focus it for the file viewer. A plain invocation still opens that pane.

No-pane mode: a caller that carries on in the current session (the `intent` skill) passes `--no-pane`, so no pane opens. Everything else still runs, including Step 2 and the SQLite copy.

```bash
worktree_path=$(~/.config/git/worktree-tools/worktree-create --no-pane "$branch") || exit 1
```

## Step 2: install dependencies

`worktree-create` already ran `git worktree-init` (symlinks, local-service wiring) when the `worktree-init` alias exists. Install dependencies the same way you would after a fresh clone — `bi` for Ruby gems, `npm install`/`yarn`, `cargo build`, `pip install`/`poetry install`, `go mod download`, whatever the project's manifest calls for.

## Step 3: work, commit, push — all from here

Edits, commits, `git push` and `/finish` (the only step that opens a PR) all run with the worktree as `cwd`. Never `cd` back to the main checkout to commit or push. The worktree stays in place until a future task's Step 1 sweeps it, once its PR merges.

## Rails + SQLite projects

Also invoke the `using-sqlite-worktrees` skill after dependency install, before running tests — it copies the main checkout's dev/test databases into the new worktree.
