# Intent: Homebrew tools first on PATH

Author: Etienne van Delden. Status: accepted (2026-11-03). Type: bugfix. Delivery: autonomous. Codex review: no.

## Problem

In every zsh shell, `/usr/bin` comes before `/opt/homebrew/bin`. `git --version` reports Apple Git-157. `python3 --version` reports 3.9.6. `which -a curl` lists `/usr/bin/curl` first, although `paths.zsh` prepends brew's curl. Editors and agents run these shells and get the Apple tools.

Causes found:

- `paths.zsh:10` prepends `/usr/local/bin /usr/bin /bin /usr/sbin /sbin` ahead of everything.
- `paths.zsh:13` skips `brew shellenv` when a parent shell already set `HOMEBREW_PREFIX`, so `/opt/homebrew/bin` and `/opt/homebrew/sbin` are never prepended.
- In login shells, macOS `/etc/zprofile` runs `path_helper`, which moves system paths to the front. `.zprofile` restores rv, node and the codex shim, but not Homebrew.

## Proposed outcome

In a non-login, a login and an interactive zsh, `/opt/homebrew/bin` and `/opt/homebrew/sbin` come before `/usr/bin`. `git`, `python3`, `curl` and `openssl` resolve to Homebrew.

## Affected users and systems

- Etienne's zsh shells, including non-interactive shells that editors, IDEs, Conductor and AI agents start.
- Claude Code's Bash tool, which inherits this PATH.
- Files: `zsh/.config/zsh/paths.zsh`, and `zsh/.config/zsh/.zprofile` if the login shell needs it.

## Constraints

- Edit the source files in `~/Developer/dotfiles/zsh/`, never the symlinks. Do not run `stow` (rule 12); Etienne gets the command with `-t "$HOME"`.
- System directories are appended only when missing, not prepended. A stripped non-login shell still gets them.
- `rv` stays after every other tool, as the `paths.zsh` header says. The unlocked codex shim stays last in the build order. `typeset -U path` stays.
- The chnode node stays ahead of Homebrew's node (`.zprofile` comment).
- No system-tool install or removal (rule 8). No dependencies added. No migrations, no deploy files.
- Public repository: no work references.
- One logical change per commit.
- Brew's curl stays keg-only, reached through `/opt/homebrew/opt/curl/bin`, ahead of `/usr/bin`.

## In scope

- Diagnose the reorder in the three shell types (done: see Problem).
- Change PATH construction so Homebrew precedes `/usr/bin` in all three shell types.
- Report any dotfiles script or hook that assumes Apple `git`, `python3` or `curl`, or Python 3.9 (done: none found, see below).
- Extend the existing PATH-order test (`test/node_path_order_test.rb` pattern) to cover Homebrew order.
- Verify in a fresh shell of each type, and in Claude Code's Bash tool.

## Out of scope

- Apple certificate issue: brew git and curl use brew's bundle, not `/etc/ssl/cert.pem`.
- `SSL_CERT_FILE` (`paths.zsh:26`).
- Installing, removing or upgrading any tool.
- Running `stow`.

## Acceptance criteria

- A non-login shell (`zsh -c`) resolves `git` to `/opt/homebrew/bin/git`, and `git --version` has no "Apple Git".
- A login shell (`zsh -lc`) resolves `git`, `python3`, `curl` and `openssl` to `/opt/homebrew` paths, even after macOS `path_helper` ran.
- An interactive shell (`zsh -ic`) resolves the same four tools to `/opt/homebrew` paths.
- `python3 --version` shows 3.15.x in all three shells.
- `ruby --version` still resolves to the rv Ruby in all three shells.
- A shell that starts with a stripped PATH (`env -i`) still has `/usr/bin` and `/bin` after Homebrew.
- A shell that inherits `HOMEBREW_PREFIX` from its parent still has `/opt/homebrew/bin` before `/usr/bin`.
- Claude Code's Bash tool shows the same order after the change.

## Findings: scripts that call git, python3 or curl

Searched `*.sh`, `*.rb`, `*.zsh`, `*.py`, `*.yml`, `*.json` and `*.toml` on `main`.

- No script or hook calls `python3` or assumes Python 3.9.
- Hits for `/usr/bin/git` exist only in tests: `test/herdr_worker_scripts_test.rb:1044`, `test/worktree_create_test.rb:554`, `test/worktree_sweep_test.rb:480`, `test/consent_guard_test.rb:241`. They stub or exercise a deliberate absolute path; the PATH change does not affect them.

## Decisions

- Autonomous delivery, no Codex review — Etienne chose the recommended options.

## Open questions

None.
