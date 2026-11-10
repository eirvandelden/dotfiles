# 0001. Plain per-repo lefthook config, no global hooks

Status: accepted, 2026-11-09. Reverses the global hook wrapper of PR #269.

## Context

PR #269 ran every repository's hooks through a wrapper in `core.hooksPath`. The wrapper built a runtime config with `extends:` and decided by origin which repositories got the shared config. Lefthook already clones a shared config (`remotes:`), refetches it (`refetch_frequency`) and overrides a shared job (`lefthook-local.yml`). The global hooks sat on top of that and blocked lefthook's own install.

## Decision

Each personal repository has its own `lefthook.yml` that names the dotfiles `lefthook.yml` under `remotes:` with `refetch_frequency: 24h`, and runs `lefthook install` once. The dotfiles repository sets no `core.hooksPath` and ships no hook scripts. The shared config lists 24 of the 28 git hook types, empty where unused, so a job added to one of them runs after the next refetch with no new install. The `post-checkout` job `worktree-init-on-create` keeps the opt-in worktree setup.

## Consequences

- A repository with no `lefthook.yml`, or one that never ran `lefthook install`, runs no hooks.
- A change to the shared config reaches every repository on its first hook run after 24 hours.
- An unreachable remote never fails a hook run.
- The shared config lists no `reference-transaction`, `post-index-change`, `prepare-commit-msg` and `post-commit` section: those hooks fire on every ref update, index write or commit, so an empty section prints a banner each time, and a broken shared config would block every ref update. A job for one of them needs a new section and a new `lefthook install` in each repo.
- Work repositories lose the global hooks too and need their own `lefthook install`.
- The old hook-run tests are gone: configuration has no tests.
