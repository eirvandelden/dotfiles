# Intent: Neovim shows an error on every launch

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix. Delivery: autonomous

## Problem

When Etienne opens Neovim in a project folder, an error notification with a long stack trace appears about one second after startup and disappears after about three seconds. It is too fast to read. The notification says that avante.nvim failed to load: `module 'mega.cmdparse' not found`.

The config updates every plugin to the newest upstream commit on each launch. On 2026-10-06 avante.nvim (commit `4f49656`) started to require two new plugins, `ColinKennedy/mega.cmdparse` and `ColinKennedy/mega.logging`. The config does not declare them. Because avante does not load, its `:Avante` command and its keymaps are unavailable.

## Proposed outcome

Neovim starts in a project folder without an error notification. Avante loads, and its commands and keymaps work again.

## Affected users and systems

- Etienne, on every Neovim launch on every machine that uses these dotfiles.
- The `neovim` stow package: the lazy.nvim plugin specs and `lazy-lock.json`.

## Constraints

- Plugins keep auto-updating on every launch (Etienne's choice).
- Approved permissions (playbook rule 11): add the Neovim plugins `ColinKennedy/mega.cmdparse` and `ColinKennedy/mega.logging`, plus any other Neovim plugin needed to clear the startup errors. No system tool, migration or deploy file change is approved.

## In scope

- Make avante.nvim load without errors at startup.
- Commit the updated `lazy-lock.json`: the new plugins and the plugin bumps that auto-update wrote.

## Out of scope

- The auto-update on launch stays as it is.
- The 762 MB `~/.local/state/nvim/lsp.log`, filled mostly by 2025 errors.
- `E1513 winfixbuf` after `:e` inside the mini.files window: normal mini.files behaviour.

## Acceptance criteria

- Opening Neovim in a project folder shows no error notification, and `<leader>un` (notification history) lists no errors after startup.
- After startup, `:Avante` runs and `<leader>aa` opens avante's ask prompt.

## Open questions

None.
