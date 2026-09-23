# Spec: Drop the Ghostty CSI-u shift+enter workaround, use alt+enter instead

From `intent.md` (2026-09-23). Status: accepted.

## Requirements

- `ghostty/.config/ghostty/config` returns to its pre-PR#146 state: no `shift+enter` keybind,
  `cmd+s`/commented `cmd+c` group back in its original unsplit shape.
- `~/.claude/keybindings.json` binds `alt+enter` to `chat:newline` in the `Chat` context, not
  `shift+enter`.
- It is demonstrated, not assumed, that herdr forwards alt+enter as bytes distinct from plain
  enter.
- It is demonstrated, not assumed, that a live Claude Code prompt inserts a newline on alt+enter
  rather than submitting.
- The reasoning for choosing alt+enter over shift+enter (herdr 0.9.1 collapses shift+enter;
  github.com/herdrdev/herdr/issues/1844) is recorded in the commit(s), since neither JSON nor a
  revert diff can carry an inline comment the way the old Ghostty block did.

## Design decisions

- Two independent changes, each committed on its own terms:
  - The Ghostty revert lives in the dotfiles repo (this worktree/branch) and goes through a PR
    against `origin`, same as PR #146.
  - `~/.claude/keybindings.json` is a plain file outside any git repository — edited directly,
    no commit, no push.
- Verification method: raw-byte capture through a herdr pane (python script in raw termios mode,
  `herdr pane send-keys` to inject `enter` and `alt+enter`, compare `repr()` output) plus a live
  check in an actual Claude Code prompt.

## Integration points

- herdr (pty forwarding layer between Ghostty and Claude Code).
- Claude Code's keybinding loader (`~/.claude/keybindings.json`).

## Acceptance criteria

- Reading `ghostty/.config/ghostty/config` after the revert shows no `13;2u` and no
  `shift+enter` keybind; the file matches what it was before PR #146.
- Reading `~/.claude/keybindings.json` shows `"alt+enter": "chat:newline"` under the `Chat`
  context and no `shift+enter` entry.
- Sending plain `enter` through a herdr pane's raw-byte reader prints `b'\r'`; sending
  `alt+enter` prints a different byte sequence.
- Pressing alt+enter in a live Claude Code chat prompt inserts a newline instead of sending the
  message.
- The commit message for the Ghostty revert and/or the summary given to the user names herdr
  0.9.1 and links github.com/herdrdev/herdr/issues/1844 as the reason shift+enter was dropped in
  favor of alt+enter.

---
Domain skills applied: None.
