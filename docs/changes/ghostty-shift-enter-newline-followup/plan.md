# Plan: Drop the Ghostty CSI-u shift+enter workaround, use alt+enter instead

From `docs/changes/ghostty-shift-enter-newline-followup/intent.md` and `spec.md` (2026-09-23).
Status: accepted.

## Context

PR #146 added a Ghostty keybind (`shift+enter=text:\x1b[13;2u`) so that shift+enter would survive
herdr's pty layer and reach Claude Code as a distinct key from plain enter. A follow-up review
(Opus, via the `review` skill) found the keybind is terminal-wide — it breaks shift+enter at a
plain zsh prompt, in `less`, `fzf`, `psql`, `irb`, and over ssh, because Ghostty has no way to
scope a keybind to one program, and herdr (0.9.1) is what actually collapses shift+enter to plain
`\r` in the first place. The review also found the change was never verified loaded (the running
Ghostty reads the main checkout, not the worktree that had the edit) and that "herdr forwards it
unmodified" was asserted, never demonstrated.

The user's decision: drop the Ghostty keybind entirely, and rebind newline in Claude Code itself
to `alt+enter`, which — per a comment on a herdr GitHub issue — already survives herdr's pty layer
today without any terminal-side trick, because it's the older ESC-prefix "meta" convention rather
than something gated behind kitty-protocol/CSI-u negotiation.

## Files that change

- `ghostty/.config/ghostty/config` (dotfiles repo, worktree
  `.worktrees/ghostty-shift-enter-newline-followup`, branch
  `ghostty-shift-enter-newline-followup`) — remove the two lines PR #146 added (the `## send CSI
  u sequence...` comment and `keybind = shift+enter=text:\x1b[13;2u`), restoring the file to
  exactly its pre-#146 state. This also un-splits the `cmd+s` / commented `cmd+c` comment group,
  which is the entire content of review finding 5 — nothing further to do there.
- `~/.claude/keybindings.json` — a plain file, untracked, outside any git repository (confirmed:
  `git -C ~/.claude rev-parse --is-inside-work-tree` fails). No worktree/commit rule applies.
  Change the one entry from `"shift+enter": "chat:newline"` to `"alt+enter": "chat:newline"`.

## Order of work

1. Edit `ghostty/.config/ghostty/config` in the worktree: delete the two added lines. Diff the
   file to confirm it now matches `git show origin/main~<n>:ghostty/.config/ghostty/config` from
   before PR #146 (or just confirm no `13;2u` remains and the cmd+s/cmd+c block is contiguous
   again).
2. Edit `~/.claude/keybindings.json` directly (no worktree, no commit): rename the key.
3. Verify herdr forwards alt+enter distinct from plain enter (review findings 2+3, re-targeted):
   split a herdr pane (`herdr pane split --current --direction right --cwd "$PWD" --no-focus`),
   run the raw-termios python script already used earlier this session (`/tmp/keytest.py` —
   reads stdin in raw mode, prints `repr()` of each read), then `herdr pane send-keys <pane>
   enter` and `herdr pane send-keys <pane> alt+enter`, reading the pane after each. Plain enter
   is already known to produce `b'\r'`; alt+enter must produce something different (expected
   `b'\x1b\r'`).
4. Verify live: with `keybindings.json` updated, confirm in this session's own Claude Code prompt
   that alt+enter inserts a newline rather than submitting.
5. Commit the Ghostty revert in the worktree, with a message that names herdr 0.9.1 and links
   `github.com/herdrdev/herdr/issues/1844` as the reason shift+enter was dropped in favor of
   alt+enter (stands in for review finding 4 — neither JSON nor a revert diff can carry an inline
   comment the way the old Ghostty block did).
6. Push the branch, open a PR against `origin` (no PR template file in this repo).
7. Report back with the raw-byte evidence from step 3 and confirmation from step 4.

## Risks

- If herdr's own alt-key handling changes in a future version, this could silently regress the
  same way shift+enter did — worth a one-line note in the PR body, not a code guard (nothing to
  guard against at this layer). Accepted: no monitoring for this exists elsewhere either.
- Rejected: keeping the Ghostty keybind and just documenting the terminal-wide side effect. The
  side effect (breaking shift+enter in zsh/less/fzf/psql/irb/ssh) is worse than losing a
  shift+enter binding that never worked reliably through herdr to begin with.
- Out of scope, explicitly not touched (review finding 6): `keybind = cmd+s=text:\x13` colliding
  with herdr's own `ctrl+s` prefix — pre-existing, unrelated, a separate task.

## Proof

No unit or acceptance tests — this is a config/keybinding change (Ghostty terminal config,
Claude Code's keybindings.json), not application code with a test suite. Per playbook rule 23 /
the `implement` skill's own allowance for config changes, verification is manual command output
instead:

- Acceptance criterion "ghostty config has no `13;2u`, cmd+s/cmd+c group is contiguous" →
  `grep -c 13;2u ghostty/.config/ghostty/config` prints `0`; manual read of the file confirms the
  group is unsplit.
- Acceptance criterion "keybindings.json binds alt+enter, not shift+enter" → manual read of
  `~/.claude/keybindings.json`.
- Acceptance criterion "herdr forwards alt+enter distinct from enter" → the `herdr pane
  send-keys` + raw-termios-script transcript from Order of work step 3, pasted into the report.
- Acceptance criterion "alt+enter inserts a newline live" → observed directly in this session's
  own Claude Code prompt.
- Acceptance criterion "reasoning recorded" → the Ghostty-revert commit message and/or PR body
  names herdr 0.9.1 and links the issue.

Test setup: none — no fixtures, no faked boundaries. Two file edits and a herdr pane used purely
as a manual verification harness.
