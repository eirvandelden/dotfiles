# Intent: Remove bundler from the stow list

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-10). Type: bugfix. Delivery: autonomous. Codex review: no.

## Problem

On a fresh clone, the installer's stow step stops with an error at `bundler`: `STOW` in `packages.conf` lists it, but the repository has no `bundler/` folder. Every package after it, such as `herdr-app`, never gets linked.

## Proposed outcome

On a fresh clone, the stow step links every listed package without an error.

## Affected users and systems

- Etienne, on any fresh Mac or Steam Deck the installer sets up.
- `packages.conf` (`STOW`), the package lists in `agents.md` and in the `dotfiles-maintenance` skill's repository layout.

## Constraints

- The `bundler` gem in `RUBY_GEMS` stays.
- This Mac's untracked local `bundler/.bundle` stays untouched and unread: it may hold credentials.

## In scope

- Remove `bundler` from `STOW`.
- Remove `bundler` from the package lists in `agents.md` and `agents/.agents/skills/dotfiles-maintenance/references/repository-layout.md`.
- A regression test, red first: every `STOW` entry has a tracked package folder.

## Out of scope

- Making the stow step skip missing folders.
- Tracking a `bundler` package.
- The `herdr-app` branch, which rebases onto this fix afterwards.

## Acceptance criteria

- On a fresh clone, `50_stow_all.sh` runs past the point where `bundler` was and links `herdr-app`.
- The regression test fails on `main` today and passes after the fix.

## Decisions

- Remove `bundler` from the stow list — Etienne's choice over skipping missing folders or tracking the package.
- Fix it on its own branch before `herdr-app` — playbook rule 25.

## Open questions

None.
