# 0001. Plain per-repo lefthook config, no global hooks

Status: accepted, 2026-11-09. Reverses the global hook wrapper of PR #269.

## Context

PR #269 ran every repository's hooks through a wrapper in `core.hooksPath`. The wrapper built a runtime config with `extends:` and decided by origin which repositories got the shared config. Lefthook already clones a shared config (`remotes:`), refetches it (`refetch_frequency`) and overrides a shared job (`lefthook-local.yml`). The global hooks sat on top of that and blocked lefthook's own install.

## Decision

Each personal repository has its own `lefthook.yml` that names the dotfiles `lefthook.yml` under `remotes:` with `refetch_frequency: 24h`, and runs `lefthook install` once. The dotfiles repository sets no `core.hooksPath` and ships no hook scripts. The shared config lists every git hook type, empty where unused, so a job added later runs after the next refetch with no new install. The `post-checkout` job `worktree-init-on-create` keeps the opt-in worktree setup.

## Consequences

- A repository with no `lefthook.yml`, or one that never ran `lefthook install`, runs no hooks.
- A change to the shared config reaches every repository on its first hook run after 24 hours.
- An unreachable remote never fails a hook run.
- The shared config lists no `reference-transaction` or `post-index-change` section: those hooks fire on every ref update and index write, so an empty section prints a banner each time and a broken shared config would block every ref update.
- Work repositories lose the global hooks too and need their own `lefthook install`.
- The old hook-run tests are gone: configuration has no tests.
