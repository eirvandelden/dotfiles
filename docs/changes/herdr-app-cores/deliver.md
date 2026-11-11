# Delivery account: herdr-app, phase 2 (cores)

## Behaviour delivered

- `install/tasks/27_register_work_core.sh` (macOS and SteamOS) starts the `work` herdr-core session when needed and registers it with the `default` core as the machine `work`, once. It never stops a core; it updates the work core only on hc's "too old" message and only while that core holds 0 live terminals. Without `hc` it warns and returns 0.
- The sidebar names the local group "personal" through the cloned `spaces-cores` mod and the cloned `cores` layout, tracked in the `herdr-app` package. `eslint.config.mjs` keeps Herdr's cloned mod code out of ESLint.
- `herdr-app-migrate` (in the `herdr-app` package): `stale` lists live stale spaces, `close` closes only listed ids, and `build --tui <session> --machine <name|''> [--dry-run]` rebuilds every TUI workspace, tab and split as a space on that machine. It resumes each running Claude or Codex agent with its own session id while the TUI agent still runs, prints each TUI pane next to its herdr-app pane, and ends no program. It refuses duplicate workspace labels and names any half-built space with its id.
- Runbook `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md`, including recovery after a core restart.

## Evidence

- Sandbox migration on this Mac (plan step 10): a scratch TUI session with two workspaces, a two-column tab and a 2×2 tab, built into a sandbox window: names, folders, tab and split shapes match; shells start in their folders; a second run prints only `skipped`. The sandbox window, TUI session and core were stopped by their own process and removed.
- `herdr-app check` passes on `mods/spaces-cores`.
- Not yet verified live: the real work-core registration, the "personal" and "work" headers in Etienne's window, the stale close and the real migration with resumed agents. These run in delivery step 12 after the merge, with Etienne's two stops.

## Checks

- `test/herdr_app_migration_test.rb`, `test/herdr_app_migrate_cli_test.rb`, `test/herdr_app_work_core_test.rb`, `test/herdr_app_package_test.rb`: green.
- `bin/test`: 111 of 112 files green; `test/secrets_loader_test.rb` reaches the real 1Password CLI on this Mac, unrelated, and gets its own branch next.
- `rubocop` and `shellcheck` clean on the changed files; the ESLint hook passes.

## Review

Plan: one Codex critique round (10 findings) and one Claude round on the amendment (6 findings), all fixed. Code: two Claude reviewer rounds; round 1 had two Important findings and five nits, all fixed; round 2 clean.
