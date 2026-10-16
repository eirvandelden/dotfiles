# Intent: Agent shells use chnode's node

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-16). Type: bugfix. Delivery: autonomous.

## Problem

In an AI agent's shell, `node` and `npm` resolve to Homebrew's node (26.11.1, a dependency of the mermaid-cli formula) instead of chnode's default (25.9.0 from `~/.node-version`). An interactive terminal gets chnode's node first. So in agent shells `npm root -g` is `/opt/homebrew/lib/node_modules`, and globally installed npm packages, such as beautiful-mermaid for the diagrams skill's `mermaid-show`, are not found.

Observed on 2026-10-13: a clean non-login `zsh -c` puts chnode's node first. A login `zsh -lc` puts `/opt/homebrew/bin/node` first: macOS path_helper in `/etc/zprofile` reorders PATH, and `.zprofile` restores only rv's paths. The Claude Code Bash tool shows the same wrong order. A shell that inherits `CHNODE_ROOT` from its parent also skips the default-version step in `paths.zsh`, so it never puts chnode's node back in front.

## Proposed outcome

Every zsh started from these dotfiles resolves `node`, `npm` and `npx` to chnode's selected version before Homebrew's node. Globally installed npm packages under chnode's node are found in agent shells as in a terminal.

## Affected users and systems

- Etienne, in terminals (Ghostty, herdr panes).
- AI agents: the Claude Code Bash tool, Codex `zsh -lc` commands, editors and IDEs that start zsh.
- Skills that call global npm packages, such as the diagrams skill's `mermaid-show` (beautiful-mermaid).
- Files: the `zsh` stow package (`paths.zsh`, `.zprofile`, and related startup files).

## Constraints

- Applies to every zsh: interactive and non-interactive, login and non-login.
- A project's own `.node-version` still wins over `~/.node-version` and over an inherited `CHNODE_ROOT`.
- An inherited `CHNODE_ROOT` beats `~/.node-version`: the shell keeps its parent's node unless a project-local `.node-version` (any `.node-version` other than `~/.node-version`) applies. Etienne chose this on 2026-10-16, over chnode's own rule that the nearest `.node-version`, including `~/.node-version`, wins. So this change alters chnode_auto's default-selection behaviour in these dotfiles.
- rv's Ruby paths stay ahead of Homebrew, as today.
- After `unlock`, `UNLOCKED_BIN` stays first on PATH.
- Homebrew's node stays installed and on PATH, behind chnode's node; mermaid-cli keeps working.
- Approved permission: run `stow -R -t "$HOME" zsh` to verify the change in live shells (rule 12). No other permission under rules 8, 9, 11, 12 or 13 is approved.

## In scope

- PATH order for node in login and non-login, interactive and non-interactive zsh.
- A shell that inherits `CHNODE_ROOT` from its parent still puts that node ahead of Homebrew's.
- Automated tests in `test/` that prove the order.

## Out of scope

- Removing, unlinking or upgrading Homebrew's node or mermaid-cli.
- Installing or changing node versions or `~/.node-version`.
- Shells other than zsh (bash, fish).
- Machines without chnode (Linux, SteamOS): no new requirement or test; the existing guard stays.

## Acceptance criteria

- In a login, non-interactive zsh (`zsh -lc 'which node'`), the first `node` is chnode's default from `~/.node-version`, not `/opt/homebrew/bin/node`.
- In a non-login, non-interactive zsh (`zsh -c 'which node'`), the first `node` is chnode's default.
- In an interactive terminal shell, the first `node` is chnode's default, as today.
- A shell inherits `CHNODE_ROOT` for node 22 from its parent; `~/.node-version` says 24. In a directory under HOME with no project `.node-version`, the first `node` is 22, not 24 and not Homebrew's. This holds in login and non-login shells.
- The same shell changes into a project whose `.node-version` says 20: the first `node` is 20. It changes back to a directory without a project `.node-version`: the first `node` is 22 again.
- A shell without an inherited `CHNODE_ROOT`, in a directory under HOME with no project `.node-version`, gets 24 from `~/.node-version`.
- `npm root -g` in an agent shell points under `~/.nodes/node-<version>/`, so `mermaid-show` finds beautiful-mermaid.
- In a directory with its own `.node-version`, the first `node` is that project's version.
- After the change, `ruby` still resolves to rv's Ruby before any Homebrew Ruby.
- After `unlock`, `codex` still resolves to the unlocked shim first.

## Open questions

None.
