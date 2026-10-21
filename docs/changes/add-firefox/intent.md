# Intent: Install Firefox from the dotfiles

Author: Etienne van Delden. Status: accepted (2026-10-21). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

Edge cannot open the homelab sites on the work Mac, and Etienne wants one browser on macOS, Android and the Steam Deck. He chose Firefox because it has Sync, a 1Password extension and a mobile app. The dotfiles do not install Firefox on any machine. On the Steam Deck they install Edge, the browser he is leaving.

## Proposed outcome

A fresh Mac and a fresh Steam Deck get Firefox from the dotfiles installer. The Deck no longer gets Edge.

## Affected users and systems

- Etienne's Macs, through the macOS Homebrew cask list.
- Etienne's Steam Deck, through the user Flatpak list.
- `packages.conf` is the only file in scope.

## Constraints

- `packages.conf` is sourced by `install.sh`, so it stays valid bash.
- Package names stay in the format each manager accepts: a Homebrew cask token, a Flatpak application ID.
- Approved now (playbook rule 11): add the Homebrew cask `firefox` and the Flatpak `org.mozilla.firefox`, and remove the Flatpak `com.microsoft.Edge`.
- Agents edit `packages.conf` only. They do not run `install.sh`, `brew` or `flatpak` (playbook rule 8). Etienne installs Firefox himself.
- Facts checked on 2026-10-20: `brew info --cask firefox` lists Mozilla Firefox 158.0, and the Flathub page for `org.mozilla.firefox` shows Mozilla as publisher with a Verified badge.

## In scope

- Add `firefox` to `BREW_MACOS`.
- Replace `com.microsoft.Edge` with `org.mozilla.firefox` in `FLATPAK`.
- Update the comment above that Flatpak entry so it describes Firefox, not Edge.

## Out of scope

- Android: Firefox is a manual Play Store install, and the dotfiles have no Android manager.
- Firefox settings, themes, Sync, bookmarks and the 1Password extension. Etienne sets these up in the app.
- Edge on the work Mac. It comes from IT and is not in the dotfiles.
- `dotfiles-work/packages.conf`, `BREW_LINUX`, and the README.
- Running the installer on any machine.
- The Edge-on-Mac investigation in the homelab repository.

## Acceptance criteria

- On a Mac, the macOS Homebrew list contains Firefox, next to the other apps.
- On a Steam Deck, the Flatpak list installs Mozilla's Firefox for the user, and Edge is no longer in it.
- Sourcing `packages.conf` still works, and no list contains `com.microsoft.Edge`.
- Running the installer a second time changes nothing, as it does for every other package today.

## Decisions

- Replace Edge with Firefox on the Deck — Etienne wants one browser everywhere and is leaving Edge.
- Autonomous delivery, no Codex review — Etienne chose both for a two-line config change.
- Package additions and the Edge removal are approved now — Etienne approved them during the intent interview, so agents need not ask at the dependency step.
- Slug `add-firefox`, no GitHub issue — Etienne said there is none.

## Open questions

None.
