# Intent: Install the herdr golden-ratio plugin and Go

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

PR #254 added the `vv.golden-ratio` config with `auto = true`, but the plugin itself is not installed. Herdr ignores the config, so panes do not resize. Go 1.24+ is needed to build the plugin, and Go is not installed or declared in `packages.conf`.

## Proposed outcome

Herdr has the `vv.golden-ratio` plugin installed and enabled, and the focused pane re-balances on every focus change. A fresh machine gets Go from `packages.conf`.

## Affected users and systems

- Etienne, in herdr.
- `packages.conf`.
- `herdr/.config/herdr/README.md`.
- This machine: Homebrew, and the herdr plugin directory.

## Constraints

- Etienne approves these installs (rules 8 and 11): `brew install go` and `herdr plugin install vigneshwerv/herdr-golden-ratio`. No other permission is needed.
- Go has built-in toolchain management, so no Go version manager is added.
- Auto mode needs herdr 0.9.1 or newer. Installed herdr is 0.9.5.
- The plugin build needs Go 1.24+.

## In scope

- `go` in `packages.conf`.
- `brew install go` on this machine.
- `herdr plugin install vigneshwerv/herdr-golden-ratio`, then `herdr server reload-config`.
- The README text: the plugin is installed by the dotfiles setup steps, not by hand. Keep the install command and the Go requirement.

## Out of scope

- A Go version manager.
- A keybinding for a manual re-balance.
- The existing `config.toml` and the Neovim plugin.
- The unrelated modified `neovim/.config/nvim/lazy-lock.json` in the main checkout.

## Acceptance criteria

- `go version` prints Go 1.24 or newer.
- `herdr plugin list` shows `vv.golden-ratio` enabled.
- With two panes in a tab, focusing one makes it about 61.8% of the tab.
- `packages.conf` lists `go`.
- The README no longer says the plugin is not installed.

## Decisions

- Install plain brew `go` with `go` in `packages.conf` — Go manages its own toolchains, so a version manager adds nothing for one build.
- Install the plugin now — Etienne said installing it should be in scope.

## Open questions

None.
