# Intent: Sweep merged worktrees on pull

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature.

## Problem

A merged worktree stays until the next `worktree-first` run in its repository. In a repository with days between new tasks, merged worktrees pile up: dotfiles lists 16 worktrees today, and other repositories have more. They clutter `git worktree list`, herdr and file pickers. Their disk space, local branches, puma-dev and Caddy routes and herdr panes linger too. When `worktree-first` finally runs, it checks all of them at once, so creating a worktree is slow.

## Proposed outcome

Soon after a pull brings merged work into a repository, that repository's merged worktrees are gone. The pull is not slower than today, and no new task has to start for the cleanup to happen.

## Affected users and systems

- Etienne, and the Claude and Codex agents that pull in his repositories, on macOS and on Linux machines that use these dotfiles.
- The global git hook shims in `~/.config/git/hooks/` and the global `lefthook.yml` in the dotfiles repository, which is the fallback config for every repository without a lefthook config of its own.
- Repositories whose `lefthook-local.yml` references the global config, through `remotes` or `extends`.
- The sweep in `~/.config/git/worktree-tools/worktree-create`, and what it touches on removal: herdr panes, puma-dev and Caddy routes (`worktree-remove`), local branches, GitHub through `gh`.

## Constraints

- Git has no post-pull hook. With `pull.rebase = true`, a pull fires `post-merge` when it fast-forwards and `post-rewrite` when it rebases local commits. A pull that reports "Already up to date" fires neither.
- Lefthook delivers the behaviour, through the global `lefthook.yml`.
- The pull must not wait for the sweep: it returns as fast as today, and the sweep finishes after.
- A failed sweep (offline, `gh` missing or logged out) never fails the pull and prints nothing.
- Hook commands run under POSIX `sh` on macOS and Linux, like the existing lefthook commands.
- Repositories that reference the global config through `remotes` receive the change only after it merges to `main` on GitHub and lefthook refreshes the remote.
- A sweep may also start after a manual `git rebase` or a `git commit --amend`; extra sweeps are acceptable.
- Two sweeps may overlap (two pulls in quick succession, or a pull during `worktree-create`); an overlap must not break a worktree or the pull.
- No new dependencies.

## In scope

- A pull that moves the checked-out branch sweeps the merged worktrees of the repository it ran in, from the main checkout or from inside a linked worktree.
- This applies in repositories that use the global `lefthook.yml` as fallback, and in repositories whose `lefthook-local.yml` references it.
- The sweep removes exactly what `worktree-create`'s sweep removes, with the same side effects (herdr pane, `worktree-remove`, local branch). It never removes the worktree the pull ran in.
- Documentation that says only `worktree-first` sweeps (the `worktree-first` skill, the worktree-tools README) mentions the pull sweep.

## Out of scope

- Repositories with their own lefthook config that does not reference the global one (cityofbrass, appkit, …).
- Worktrees outside `.worktrees/`, such as `~/.config/superpowers/worktrees/`.
- Changes to which worktrees count as removable.
- Sweeping on a pull that reports "Already up to date", or on a plain `git fetch`.
- Reporting what a sweep removed: no log file, no notification.
- Removing the sweep from `worktree-create`.
- Sweeping any repository other than the one the pull ran in.

## Acceptance criteria

- After the PR for `.worktrees/foo` merges, `git pull` on `main` in the main checkout removes `.worktrees/foo`, its local branch and its herdr pane.
- A `git pull` that moves a feature branch inside `.worktrees/bar` removes the merged `.worktrees/foo` too.
- `git pull` gives the prompt back as fast as before; `.worktrees/foo` disappears shortly after.
- After that pull, a worktree with uncommitted changes, one with an open PR, one with no commits beyond `origin/main` and one on a detached HEAD all remain.
- A `git pull` inside the merged `.worktrees/foo` leaves `.worktrees/foo` in place.
- A pull in repository A never removes a worktree of repository B.
- A pull in cityofbrass, which has its own `lefthook.yml` and no reference to the global config, removes nothing.
- A pull in a repository whose `lefthook-local.yml` references the global config through `remotes` removes its merged worktrees.
- With `gh` logged out, `git pull` succeeds as it does today, and the sweep adds no error output.
- `worktree-first` still sweeps merged worktrees when it creates a new one.

## Flagged concerns

- Slow `worktree-first` versus keeping its sweep: `worktree-create` keeps sweeping. Chosen side: keep both. Pull sweeps shrink the backlog, so `worktree-create` has fewer worktrees left to check.
- No added wait versus visibility: the sweep runs after the pull returns and reports nothing, so a failing sweep goes unnoticed. Chosen side: silence; `git worktree list` shows the result.

## Open questions

None.
