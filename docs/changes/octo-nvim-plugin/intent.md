# Intent: Review GitHub pull requests inside Neovim

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature.

## Problem

Reviewing a GitHub pull request means leaving the terminal for the browser. From Neovim there is no way to list a repository's pull requests, read a diff line by line, leave comments, or submit a review. The gh-dash `C` key, meant to hand a pull request over to the editor, has nowhere to go.

## Proposed outcome

A pull request review happens entirely in the terminal:

- A leader key in the Git group lists the current repository's pull requests.
- A pull request opens with its diff; line comments and a final approve or request-changes review are submitted from Neovim.
- Pressing `C` in gh-dash opens that pull request in the same review view.
- A freshly bootstrapped machine has everything needed for this to work.

## Affected users and systems

- Etienne, as the reviewer (personal and work repositories).
- Neovim configuration (`neovim` stow package): new plugin, keymaps.
- gh-dash, as the entry point that hands a pull request over.
- `packages.conf` and the bootstrap, which must provide the `gh` CLI.

## Constraints

- Reuse the snacks picker already configured; add no telescope or fzf-lua.
- A fresh machine works after bootstrap: `gh` is declared as a system dependency.
- Keymaps follow the Git group scheme: `<leader>g` plus the tool's first letter (lazygit on `<leader>gl`, this on `<leader>go`).
- The dotfiles repository is public: no work references and no tokens committed.
- Adding a plugin is a dependency change and needs recorded approval (playbook rule 11).

## Open questions

None.
