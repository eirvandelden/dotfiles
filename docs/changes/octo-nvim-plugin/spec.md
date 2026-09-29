# Spec: Review GitHub pull requests inside Neovim

From `intent.md` (2026-09-29). Status: accepted.

## Requirements

- List a repository's open pull requests from Neovim.
- Opening a pull request shows its changed files and their diff hunks.
- Leave a line comment or a suggestion on a diff hunk.
- Start a review, then submit it as approve, comment, or request changes.
- Pressing `C` on a pull request in gh-dash opens that same pull request in Neovim.
- A freshly bootstrapped machine has the `gh` CLI installed, with no manual step.
- Keymaps follow the `<leader>g` + tool's first letter scheme: `<leader>gl` for lazygit, `<leader>go` for octo.nvim.
- No telescope or fzf-lua is added; octo.nvim uses the snacks picker already configured.

## Design decisions

- octo.nvim is the plugin: it is what gh-dash's own documented integration pattern already points at, and it supports the snacks picker without adding a dependency.
- Review actions (start, comment, suggest, submit) use octo.nvim's own default `<localleader>` mappings rather than custom keymaps in this repository's config — they ship active without any `opts.mappings` block, so installing the plugin is enough; no extra keymap wiring is needed for the review workflow itself.
- `<leader>go` opens the pull request list (`Octo pr list`) — the one entry point this repository adds. Everything past that point (opening a PR, browsing its file panel, commenting, submitting a review) is octo.nvim's own built-in UI.

## Integration points

- gh-dash (`~/.config/gh-dash/config.yml`, outside this repository) — its `C` keybinding shells into `nvim -c ":silent Octo pr edit {{.PrNumber}}"`.
- `packages.conf` `BREW` list — `gh`.
- Neovim `which-key-extra.lua` — the existing `<leader>g` "Git" group.

## Acceptance criteria

- Pressing `<leader>go` inside a repository lists its open pull requests.
- Selecting a pull request from that list opens its overview with a file panel listing every changed file.
- Opening a changed file from the panel shows that file's diff hunks.
- Pressing `<localleader>ca` on a diff line adds a review comment there; `<localleader>sa` adds a suggestion instead.
- Pressing `<localleader>vs` starts a review; submitting it offers approve, comment, or request changes.
- Pressing `C` on a pull request in gh-dash opens that same pull request in Octo.
- Lazygit opens on `<leader>gl`; Octo's pull request list opens on `<leader>go`.
- A machine bootstrapped from scratch has the `gh` CLI installed via `packages.conf`.
- No telescope or fzf-lua plugin appears in the Neovim config as a result of this change.

---
Domain skills applied: dotfiles-maintenance.
