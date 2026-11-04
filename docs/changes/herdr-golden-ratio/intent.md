# Intent: Golden ratio in herdr and Neovim

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

The focused herdr pane keeps the same size as its neighbours. The focused Neovim split does the same. Neither window grows to give the focused one the most room.

## Proposed outcome

The focused herdr pane resizes itself to the golden ratio on every focus change, with no keypress. The focused Neovim window does the same.

## Affected users and systems

- Etienne, in herdr and Neovim.
- The `herdr` stow package: `herdr/.config/herdr/plugins/config/` and `herdr/.config/herdr/README.md`.
- The `neovim` stow package: `neovim/.config/nvim/lua/plugins/` and `lazy-lock.json`.

## Constraints

- The herdr plugin needs herdr 0.9.1 or newer for auto mode. Installed herdr is 0.9.5.
- The herdr plugin needs Go 1.24+ to build. Go is not installed. Playbook rule 8 forbids installing it. Claude does not install the plugin.
- Like `herdr-file-viewer`, the plugin is not installed by this repository. The README documents the install command.
- Approved permissions for autonomous delivery: none beyond the two dependencies below. No system tool, migration or deploy file is touched.
- Etienne approves two new dependencies by this request: the herdr plugin and the Neovim plugin (rule 11).

## In scope

- A `herdr-golden-ratio/config.toml` under `herdr/.config/herdr/plugins/config/` with `auto = true`, commented like the file-viewer config.
- A README section in the herdr package: what the plugin does, the install command, the Go requirement.
- A `golden-ratio.lua` lazy.nvim spec in the neovim package for `roman/golden-ratio`, with its lockfile entry.

## Out of scope

- Installing Go or the herdr plugin.
- A herdr keybinding for a manual re-balance. Auto mode makes it unneeded.
- Tuning Neovim golden-ratio options beyond the defaults.
- Any other change to the herdr or Neovim config.

## Acceptance criteria

- The herdr plugin config file sets `auto = true`.
- The herdr README tells how to install the plugin.
- Starting Neovim loads `roman/golden-ratio` without an error.
- Splitting two windows in Neovim resizes the focused window larger than the other.

## Decisions

- Document the herdr plugin install, do not run it — Go is missing and rule 8 forbids installing tools.
- Use `roman/golden-ratio` for Neovim — it is the Vim plugin the herdr plugin names as its basis. No reason given by Etienne; a default.

## Open questions

None.
