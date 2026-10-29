# Review: add-firefox

## Round 1 — 2026-10-26T15:15:06Z — a49473b1

No findings.

- Bugs: `firefox` reaches `brew_install_one` like every other `BREW_MACOS` cask; `org.mozilla.firefox` goes through task 23 with the same `--user` skip check. No list still names `com.microsoft.Edge`.
- Security: both identifiers are Mozilla's own (Homebrew cask `firefox`, Flathub-verified `org.mozilla.firefox`), as `intent.md` records.
- Compliance: the diff touches `packages.conf` only, in the three lines `plan.md` names. Every `## Proof` check passes: `codex-app`, `firefox`, `ghostty` in order; `FLATPAK` prints `org.mozilla.firefox` and `dev.neovide.neovide` only; `bash -n` passes and no Edge entry remains. The full suite is green. No test changed. The acceptance criteria are configuration, which has no tests under playbook rule 3, as the plan records.
- Design: no Ruby or shell function changed, so no signature, Law of Demeter or N+1 finding applies. No glossary `Avoid:` word appears.
