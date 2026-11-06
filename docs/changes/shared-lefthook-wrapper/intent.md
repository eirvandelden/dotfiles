# Intent: Shared lefthook wrapper for personal repositories

Author: Etienne van Delden. Status: accepted. Type: bugfix. Delivery: step-by-step.

## Problem

Git hooks in personal repositories in `~/Developer` stop running or fail with Bundler errors under `GIT_DIR`.

Lefthook rewrites the stowed global hooks (`pre-commit`, `pre-push`, `post-merge`) into plain files, because `no_auto_install: true` only protects when the shared config is the main config.

The shared config reaches repos through `remotes:`, whose cached copy goes stale, or not at all.

Git exports `GIT_DIR` to hooks. Only the shared `rubocop` job unsets it, so `bundle exec` in other jobs breaks.

## Proposed outcome

Every personal repository gets the shared lefthook config plus its own extra or changed hooks. Editing the global config in the dotfiles repo takes effect at once, through stow. Hooks stay stowed links and `GIT_DIR` never reaches the jobs.

## Affected users and systems

Etienne's personal repositories under `~/Developer` (origin owned by `eirvandelden`). The `git` stow package, `lefthook.yml` and the global `core.hooksPath` hooks. Work repositories get only the safe parts.

## Constraints

- Edit sources in `~/Developer/dotfiles/<package>/`, never the links. Never run `stow`.
- The dotfiles repository is public: no work references.
- Work repositories (rule 15) do not receive the shared config.
- No new dependency.

## In scope

- One wrapper script in the `git` package that every global hook calls.
- The wrapper unsets `GIT_DIR`.
- The wrapper builds a runtime config that extends the shared `lefthook.yml`, then the repo's own `lefthook.yml`, `.lefthook.yml` or `.config/lefthook.yml`, and exports it as `LEFTHOOK_CONFIG`.
- The wrapper passes `--no-auto-install`.
- A test in `test/` for the merge, the `GIT_DIR` unset and the no-auto-install flag.
- A repair note for Etienne: trash the three plain hook files, then restow `git`.

## Out of scope

- Removing `remotes:` blocks from other repositories (separate per-repo changes).
- Running `stow` or touching `~/.config/git/hooks` directly.
- The Linux `[[ ]]` bug in `lefthook.yml` and the `LEFTHOOK_BIN` test leak.
- Changing the shared job definitions.

## Acceptance criteria

- A personal repo with its own `lefthook.yml` runs both the shared jobs and its own jobs on commit.
- A personal repo with no lefthook file runs the shared jobs.
- A repo's own job overrides a shared job of the same name.
- A hook that runs `bundle exec` inside a linked worktree on `pre-push` does not see `GIT_DIR`.
- `lefthook run` in a repo does not rewrite the global hooks.
- A repo whose origin is not owned by `eirvandelden` runs only its own config.

## Flagged concerns

Repos that still carry `remotes:` run the shared config twice, once through `remotes:` and once through the wrapper. Same-named jobs merge, so the result is the same. The stale remote copy may win on a conflict, until a follow-up removes the `remotes:` blocks. Chosen side: leave them for now.

## Decisions

- Apply the shared config only to personal repos (origin owned by `eirvandelden`) — keeps work repos separate (playbook rule 15).
- Leave the `remotes:` blocks in other repos alone — separate per-repo changes.
- The wrapper builds the runtime config with `extends:` — tested to merge shared and repo config and to honour `no_auto_install`.

## Open questions

None.
