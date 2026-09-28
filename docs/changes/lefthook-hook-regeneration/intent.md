# Intent: Lefthook hook rewrites stop blocking work

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix.

## Problem

The global git hooks live in the dotfiles repository (`git/.config/git/hooks/`) and are linked into `~/.config/git/hooks/`. Three times (2026-09-24 ~16:18, 2026-09-25 10:05 during a pull, 2026-09-25 11:12 at the end of a rebase in a dotfiles worktree) lefthook replaced them with its own template. The rewrite itself is not the problem. What it causes is:

- Sometimes the dotfiles working copy also shows four modified tracked files that nobody edited (10:05); the 11:12 occurrence left them clean.
- `~/.config/git/hooks/` ends up with real files instead of links. The install script, which re-runs after every config change in the repository, then fails to stow `git`: `cannot stow Developer/dotfiles/git/.config/git/hooks/pre-commit over existing target .config/git/hooks/pre-commit since neither a link nor a directory and --adopt not specified` (same for `post-merge`, `post-rewrite`, `pre-push`).
- The rewritten hooks drop the global fallback config, so repositories without their own lefthook config silently lose their checks.

Each time, work stops until the hooks are restored by hand (checkout, move files aside, restow).

A second, smaller problem surfaced during the same pull: lefthook's `post-merge` hook runs `bundle install` in the dotfiles repository, which has no Gemfile, and the hook reports a failure.

## Proposed outcome

Lefthook works the way it is designed to work with a global hooks directory: it never writes into that directory during normal work. Lefthook's own design (2.1.12) is hooks per repository; it refuses to sync hooks into a global `core.hooksPath` unless `lefthook install --force` is given, and its documented switch for turning off automatic hook sync is `no_auto_install: true` (config) or `--no-auto-install` (flag). Ignoring the hook files in the dotfiles repository is not the lefthook way and would not bring back the links or the global fallback.

Once this ships:

- No lefthook run started from the global hooks, including the nested `lefthook run migrations` in the dotfiles `lefthook.yml`, syncs hooks.
- The dotfiles working copy and the links in `~/.config/git/hooks/` stay as stowed.
- Repositories without their own lefthook config keep getting the global checks.
- Pulling in the dotfiles repository no longer reports a `bundle` failure.

Why lefthook's own refusal does not protect this setup today: `~/.gitconfig` exists, and `git config --global` then reads only that file, not `~/.config/git/config` where `core.hooksPath` is set. Lefthook asks git with `--global`, sees no global hooks path, and writes. Both explained occurrences (10:05 pull, 11:12 rebase) came from the nested `lefthook run migrations --files-from-stdin` in the dotfiles `post-merge` / `post-rewrite` hooks, which passes no `--no-auto-install`. Reproduced in a temp repo with the real 2.1.12 binary: without `~/.gitconfig` lefthook refuses; with it, lefthook replaces the linked hook with its template; with `--no-auto-install` or `no_auto_install: true` it leaves the hook alone.

## Affected users and systems

- Etienne, on every machine that stows the `git` package.
- Every repository that uses the global hooks (`core.hooksPath`), with or without its own lefthook config.
- The dotfiles repository's own `lefthook.yml` (`migrations` group).

## Constraints

- No change to `core.hooksPath`. No `stow` run by the agent; Etienne restows `git` after merge.
- Nothing under `claude/`, `codex/`, `agents/`, `herdr/`, `docs/changes/` (other than this folder).
- No CI workflow change without Etienne's approval.
- Proven with the existing real-binary lefthook tests at the repo root.

## Open questions

- Repositories with their own lefthook config that call `lefthook run` without the flag (a nested run in their config, or a direct run by an agent) can still sync hooks while `~/.gitconfig` hides the global hooks path. Lefthook has no environment variable for `no_auto_install`. Whether to cover that case, and how, is for the spec.
