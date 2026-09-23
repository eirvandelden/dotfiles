# Intent: Drop the Ghostty CSI-u shift+enter workaround, use alt+enter instead

Author: Etienne van Delden. Status: accepted. Type: bugfix.

## Problem

The Ghostty `keybind = shift+enter=text:\x1b[13;2u` workaround (PR #146) fires in every program
in every pane, not only Claude Code. herdr collapses shift+enter to plain `\r` before forwarding,
so the Ghostty override was the only way shift+enter survived — but it also breaks shift+enter at
a plain zsh prompt, in `less`, `fzf`, `psql`, `irb`, and over ssh, none of which understand that
escape sequence.

## Proposed outcome

The Ghostty keybind is gone. Claude Code's `~/.claude/keybindings.json` binds `alt+enter` to
`chat:newline` instead of `shift+enter`, because alt+enter already survives herdr's pty layer
unmodified — the older ESC-prefix meta convention, not gated behind kitty-protocol negotiation.
Verified by raw-byte capture through a herdr pane, and live in a Claude Code prompt.

## Affected users and systems

Etienne, personal machine. Ghostty config (dotfiles repo), `~/.claude/keybindings.json`
(untracked, outside any git repo), herdr-managed panes.

## Constraints

Must not regress shift+enter behavior for other programs (zsh, less, fzf, psql, irb, ssh).
herdr 0.9.1's shift+enter collapse is the root cause and out of scope to fix directly here —
ref github.com/herdrdev/herdr/issues/1844.

## Open questions

None.
