# Intent: Remove the Rex SessionStart hook

Author: Etienne van Delden. Status: accepted. Type: bugfix. Delivery: autonomous. Codex review: no.

## Problem

Etienne works only from herdr-app and herdr-core, but every Claude session still registers itself with Rex. The SessionStart hook in `claude/.claude/settings.json` runs `rex __internal session-start --agent claude` unless `HERDR_ENV` is 1. herdr-app does not set `HERDR_ENV`, so the hook fires in every herdr-app session. Agents then see Rex as the active terminal tool when Etienne asks for a new tab or pane.

## Proposed outcome

A Claude session started in herdr-app no longer runs any Rex command at start. No Claude session registers with Rex at all.

## Affected users and systems

- Etienne, and every Claude session started from his dotfiles.
- `claude/.claude/settings.json` (the hook).
- `test/rex_config_test.rb` and `test/agent_coexistence_config_test.rb` (assertions that expect the hook).

## Constraints

- Edit the source file in the dotfiles package, never the symlink under `~/.claude`.
- No new permission is needed: no dependency, system tool, destructive migration or deploy file changes.
- Do not run `stow`.

## In scope

- Remove the Rex SessionStart hook entry from `claude/.claude/settings.json`.
- Remove the test assertions that expect that hook.

## Out of scope

- The `rex/` package, its scripts, and the `play-tone.sh` hooks.
- Mentions of Rex in the stage skills (`intent`, `plan`, `implement`, `review`, `deliver`).
- The Codex configuration.
- The global `rex` skills already trashed by hand.

## Acceptance criteria

- A new Claude session in herdr-app runs no `rex` command at session start.
- `claude/.claude/settings.json` holds no `rex __internal session-start` command.
- The hook and coexistence tests pass without any assertion that expects the Rex hook.

## Decisions

- Remove the hook entirely instead of guarding it on `HC_TERMINAL_ID` — Etienne works only from herdr-app and herdr-core; Rex is unused.
- Deliver autonomously, without a Codex review — the change is a config line plus test removal.

## Open questions

None.
