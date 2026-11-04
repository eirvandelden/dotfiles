# Intent: Rex prefix keybindings like herdr

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

Etienne is moving from herdr to Rex and relies on herdr's `ctrl+s` prefix keys. Rex has only a partial copy, in `~/.config/rex/init.lua`, a loose file outside the dotfiles repository. Split, close, tab, zoom and session keys do not work, and the file is not versioned.

## Proposed outcome

The herdr prefix muscle memory works in Rex. The keys go into the `rex` stow package that branch `rex-agent-switcher` already creates, and this change stacks on that branch.

## Affected users and systems

Etienne's Rex app on macOS. The dotfiles repository: the `rex` package from `rex-agent-switcher`.

## Constraints

- No new stow package: `rex` comes from `rex-agent-switcher`, which this branch is rebased on. The pull request targets that branch (playbook rule 20).
- Agents never run `stow`. Etienne moves the loose `~/.config/rex/init.lua` away and stows the package himself.
- The existing bindings stay: `cmd+k`, `shift+cmd+k`, the `ctrl+3..8` and `ctrl+-` key remaps, `ctrl+s ctrl+s`, the arrow-key pane focus, and the switcher's `ctrl+s space` (`agent_switcher`).
- Prefix is `ctrl+s`, the same as in herdr.

## In scope

- `rex/.config/rex/init.lua`, the switcher branch's file plus the new bindings.
- New prefix bindings: `|` split right, `v` split down, `w` close pane, `z` zoom, `=` balance, `t` new tab, `shift+t` close tab, `n` next tab, `p` previous tab, `1..9` go to tab, `shift+n` new session, `r` rename tab.
- A short note on how to switch from the loose file to the package.

## Out of scope

- `prefix+alt+1..9` (focus agent), `prefix+shift+1..9` (switch workspace), `prefix+f`, `prefix+shift+f`, `prefix+g`, `prefix+shift+g`: Rex has no equivalent action yet.
- Removing the herdr package or its config.
- Running `stow`, or touching `~/.config/rex` directly.

## Acceptance criteria

- `rex keymap` lists `ctrl+s |` as a right split and `ctrl+s v` as a down split.
- Pressing `ctrl+s w` closes the focused pane.
- Pressing `ctrl+s z` zooms the focused pane. Pressing it again restores the layout.
- Pressing `ctrl+s 3` goes to the third tab.
- Pressing `ctrl+s ctrl+s` still sends a literal `ctrl+s` to the shell.
- After Etienne stows the package, `~/.config/rex/init.lua` links into the dotfiles repository, and `ctrl+s space` still opens the agent switcher.

## Decisions

- `|` splits right and `v` splits down — Etienne took the recommended option, which matches the glyph shapes.
- Stack on `rex-agent-switcher` and target the PR at it — Etienne said the stow package is on that branch and took the recommended option; two branches creating `rex/.config/rex/init.lua` would conflict.
- Autonomous delivery without a Codex review — Etienne took the recommended delivery mode, and the Codex question was not asked, so no is the default.

## Open questions

None.
