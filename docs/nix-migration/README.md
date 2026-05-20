# Nix + home-manager migration

Migrating the dotfiles stack from shell scripts + GNU Stow + Homebrew to Nix + home-manager
(with nix-darwin on macOS eventually). Configuration becomes declarative, reproducible, and
cross-platform from a single source of truth.

## Why

SteamOS provisioning with the current approach is fragile and time-consuming. Nix makes both
macOS and SteamOS converge to a desired state from a single repo.

## Platforms

- **macOS** — daily work machine. Every step is additive and reversible. `rv` stays installed
  throughout.
- **SteamOS** — portable dev environment. Nix is installed into the `/nix` overlay partition.

## Phases

| # | Name | Scope | Status |
|---|------|-------|--------|
| 0 | Foundation | macOS + SteamOS | ✅ macOS done / ⬜ SteamOS pending |
| 1 | One project gets a flake | macOS | ⬜ Pending |
| 2 | More project flakes | macOS | ⬜ Pending |
| 3 | home-manager standalone; low-risk CLI tools | macOS + SteamOS | ⬜ Pending |
| 4 | Migrate zsh to home-manager | macOS + SteamOS | ⬜ Pending |
| 5 | Migrate remaining stow packages | macOS + SteamOS | ⬜ Pending |
| 6 | Introduce nix-darwin | macOS | ⬜ Pending |
| 7 | End state for personal stack | macOS + SteamOS | ⬜ Pending |
| 8 | Migrate dotfiles-work to Nix | macOS | ⬜ Pending (post-Phase 7) |

## Critical invariants

- macOS is never broken. Each phase is revertible to the prior phase without reinstalling.
- `rv shell <version>` always works on macOS. `rv` is never uninstalled.
- Work dotfiles are untouched through Phases 0–7.
- Worktrees are first-class: per-project config lives in files under the repo.

## Phase docs

- [Phase 0 — Foundation](phase-0-foundation.md)
- [Phase 1 — First project flake](phase-1-first-flake.md)
- [Phase 2 — More project flakes](phase-2-more-flakes.md)
- [Phase 3 — home-manager standalone](phase-3-home-manager.md)
- [Phase 4 — Migrate zsh](phase-4-zsh.md)
- [Phase 5 — Migrate stow packages](phase-5-stow-packages.md)
- [Phase 6 — nix-darwin](phase-6-nix-darwin.md)
- [Phase 7 — End state](phase-7-end-state.md)
- [Phase 8 — Work dotfiles](phase-8-work-dotfiles.md)
- [Glossary](glossary.md)
- [Troubleshooting](troubleshooting.md)
