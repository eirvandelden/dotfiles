# Spec: herdr notifications stop freezing the session

From `intent.md` (2026-09-29). Status: accepted.

## Requirements

- herdr delivers agent notifications through the terminal (Ghostty), not by starting a notification program.

## Design decisions

- `[ui.toast] delivery = "terminal"` instead of `"system"`. `system` runs whichever `terminal-notifier` is first on PATH and waits for it; `terminal` starts no program, so nothing can block the client.

## Integration points

- `herdr/.config/herdr/config.toml`, shared by every herdr session.
- Ghostty's own desktop notifications (on by default; not set in these dotfiles).

## Acceptance criteria

- herdr's config check accepts `delivery = "terminal"` without diagnostics.
- When an agent finishes, a notification appears and the session still takes keyboard input.

---
Domain skills applied: dotfiles-maintenance.
