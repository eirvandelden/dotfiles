# Plan: Install Firefox from the dotfiles

From `intent.md` (2026-10-21). Status: accepted.

## Design

### Domain terms

- Package list: one bash array in `packages.conf` that one install task reads (`BREW_MACOS`, `FLATPAK`).
- Cask token: the name `brew install --cask` accepts, here `firefox`.
- Flatpak application ID: the reverse-DNS ID `flatpak install` accepts, here `org.mozilla.firefox`.
- No glossary file exists in this repository. No intent word conflicts with an agreed term.

### Diagrams

Not affected: no class, record or state changes. The data flow stays `packages.conf` → `install/tasks/20_install_brew_packages.sh` (`BREW_MACOS`) and `install/tasks/23_install_flatpak_packages.sh` (`FLATPAK`).

### Signatures

Not affected: no Ruby or shell function changes; only two array entries and one comment change.

Not checked: the change touches no Ruby code.

### Complexity

Not affected: one more Homebrew lookup on macOS; the Flatpak list keeps two entries.

### Invariants

- `packages.conf` stays valid bash, so `install.sh` and the tests can source it. Enforced by `bash -n` and by the tests that source it (`test/glow_package_test.rb`, `test/stow_package_roots_test.rb`).
- No list names `com.microsoft.Edge`. Enforced by the review of the diff and the grep check in `## Proof`.
- A second installer run changes nothing. Enforced by the existing skip checks: `install_brew_packages` skips a package that `brew list --cask` reports (`install/utils.sh`), and task 23 skips an app that `flatpak info --user` reports.

### Alternatives

- Chosen: edit two arrays in `packages.conf`. Add `firefox` to `BREW_MACOS` in alphabetical place, between `codex-app` and `ghostty`. Replace `com.microsoft.Edge` with `org.mozilla.firefox` in `FLATPAK`, keeping it the first entry, under a comment that names Firefox.
- Rejected: put `firefox` in `BREW` (all systems). The intent routes Firefox through the macOS cask list and the Deck Flatpak list. On Linux, `brew_install_one` would try a formula named `firefox` before the Flatpak runs, which adds a second, unmanaged route.
- Rejected: change `install/utils.sh` to adopt a hand-installed `Firefox.app` (`brew install --cask --adopt`) or to uninstall Edge on the Deck. Both are outside the intent's scope (`packages.conf` only) and change installer behaviour for every package.

## Design decisions

- Placement in `BREW_MACOS`: alphabetical, between `codex-app` and `ghostty`, because the list's app entries are already alphabetical.
- New Flatpak comment: `# Browser: Firefox, one browser with Sync on macOS, Android and the Deck`. It replaces `# Browser (preferred on SteamOS for stability)`, which described why Edge came from Flatpak.
- No conflict with intent's `## Decisions`.

## Integration points

- `install/tasks/20_install_brew_packages.sh` reads `BREW_MACOS` on macOS through `install_brew_packages` and `brew_install_one` in `install/utils.sh`.
- `install/tasks/23_install_flatpak_packages.sh` reads `FLATPAK` on Linux and installs with `flatpak install --user --noninteractive --or-update flathub`.
- The CI workflow `.github/workflows/dotfiles-tests.yml` runs `test/*_test.rb`. Some tests source `packages.conf`.

## Files that change

- `packages.conf` — add `firefox` to `BREW_MACOS`; replace `com.microsoft.Edge` with `org.mozilla.firefox` in `FLATPAK`; replace the comment above that entry.

## Order of work

1. Edit `BREW_MACOS` in `packages.conf`: add `firefox` between `codex-app` and `ghostty`.
2. Edit `FLATPAK` in `packages.conf`: replace the comment and replace `com.microsoft.Edge` with `org.mozilla.firefox`.
3. Run the checks in `## Proof`.
4. Run the full test suite, stopping at the first failure with a non-zero status: `(set -e; for file in test/*_test.rb; do ruby -Itest "$file"; done)`.
5. Re-read the diff. It must touch `packages.conf` only, in three lines.
6. Commit: `Install Firefox on macOS and the Steam Deck`.

Do not run `install.sh`, `brew` or `flatpak` (playbook rule 8). Etienne installs Firefox himself.

## Risks

- A Mac that already has a hand-installed `/Applications/Firefox.app`: `brew install --cask firefox` fails with "It seems there is already an App". `brew_install_one` ignores the cask's exit status and returns 0, so the installer does not stop, but it prints the error on every run. The fix on that Mac is a manual `brew install --cask --adopt firefox`. Changing the installer is out of scope.
- A Deck that already has Edge: removing it from `FLATPAK` does not uninstall it, because the installer only installs. Etienne removes it by hand (`flatpak uninstall --user com.microsoft.Edge`) if he wants it gone.
- A Deck with a system-wide Firefox Flatpak (for example from Discover): `flatpak_is_installed` checks `--user` only, so the installer adds a second, user copy. Same behaviour as every other Flatpak today; no action.
- Orthogonal bug, separate branch: `brew_install_one` returns 0 when `brew install --cask` fails, so a broken cask never stops the installer. Not fixed here.
- A Firefox that Mozilla's own updater updates outside Homebrew: `brew upgrade` can show it as outdated. The cask sets `auto_updates`, so `brew upgrade` skips it by default. No action.
- Rejected: an automated test for the list contents. Playbook rule 3 says configuration has no tests.

## Proof

- On a Mac, the macOS Homebrew list contains Firefox, next to the other apps → check: `bash -c 'source packages.conf; printf "%s\n" "${BREW_MACOS[@]}"' | grep -A2 -x codex-app` prints exactly `codex-app`, `firefox`, `ghostty`, in that order
- On a Steam Deck, the Flatpak list installs Mozilla's Firefox for the user, and Edge is no longer in it → check: `bash -c 'source packages.conf; printf "%s\n" "${FLATPAK[@]}"'` prints `org.mozilla.firefox` and `dev.neovide.neovide`, and nothing else
- Sourcing `packages.conf` still works, and no list contains `com.microsoft.Edge` → check: `bash -n packages.conf && bash -c 'source packages.conf' && ! grep -n 'com.microsoft.Edge' packages.conf`
- Running the installer a second time changes nothing, as it does for every other package today → check: read `install_brew_packages` and `install/tasks/23_install_flatpak_packages.sh` in the diff context; both skip an installed package, and the diff does not touch them. Etienne confirms on his machines after merge.
- Invariant: `packages.conf` stays valid bash, enforced by the tests that source it → `test/stow_package_roots_test.rb`, `test/glow_package_test.rb` (full suite stays green)

Per changed file, the unit tests expected:

- `packages.conf`: none, configuration has no tests.

Test setup: none.

---
Domain skills applied: dotfiles-maintenance, dependencies (additions and removal pre-approved in `intent.md`).

## Critique

### Round 1 (codex exec -p terra)

- The rejected `BREW` alternative claims a guaranteed Linux failure, but `brew_install_one` tries a formula on every OS first → fixed (the rejection now rests on the agreed macOS-cask and Deck-Flatpak routes)
- The full-suite command `ruby ... || break` makes the loop return 0 and hides failures → fixed (Order of work step 4 runs the loop under `set -e` in a subshell)
- The macOS proof checks only that `firefox` exists, not its agreed place between `codex-app` and `ghostty` → fixed (the check prints the three consecutive entries)
