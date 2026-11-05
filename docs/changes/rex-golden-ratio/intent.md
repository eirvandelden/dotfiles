# Intent: Golden ratio for the focused Rex pane

Author: Etienne van Delden. Status: accepted (2026-11-04). Type: feature. Delivery: autonomous. Codex review: no.

## Problem

In Rex, the focused pane keeps whatever size the layout gave it. The herdr `golden-ratio` plugin enlarges the focused pane to about 61.8% of the tab. Rex has no equivalent, so the pane Etienne works in stays small when many panes share a tab.

## Proposed outcome

The focused pane takes the golden-ratio share (about 61.8%) of the tab width and height, automatically on every focus change.

## Affected users and systems

- Etienne, in Rex on macOS.
- `rex/.config/rex/init.lua`, from the `rex` stow package that branch `rex-agent-switcher` creates. This change rebases onto that branch once it implements.
- A macOS LaunchAgent that keeps the automatic watcher running.

## Constraints

- Rex runs `rex.on` only in `rex do` scripts. `init.lua` never receives events, and Rex has no focus-changed event. The watcher is a separate Lua script run by `rex do ... --all`.
- Rex has no way to start a script by itself. A LaunchAgent starts the watcher at login and restarts it if it exits.
- The resize uses `rex.session.resize_pane`. It takes two block ids and a direction, and picks the innermost split between them. The watcher walks every ancestor split of the focused block.
- Each split on an axis crossed k times gives the focused side `ratio^(1/k)`, so the product over the path equals the target ratio. This is the herdr plugin's rule.
- The watcher's own resizes raise `session_view_changed`. It must not re-trigger itself: it acts only when `focused_block_id` differs from the last one it handled, and skips a resize when the split is already within `min_delta` of the target.
- The plan verifies whether a focus change alone raises `session_view_changed`. If it does not, the watcher falls back to `rex.every` polling.
- Permissions approved for this change: add a LaunchAgent plist file, and run `launchctl bootstrap` for it. No gems, packages, drops, deploy files or `stow` runs. Etienne runs `stow` himself (rule 12).
- Another agent owns the `rex` stow package. This change adds files to it only after rebasing onto `rex-agent-switcher`.

## In scope

- A watcher script run by `rex do --all` that applies the same resize when focus changes.
- A config table with `ratio` (default 0.618), `min_delta` and `debounce`, read from `init.lua`.
- A LaunchAgent plist that starts the watcher at login, plus `launchctl bootstrap` for it.
- Tests for the pure ratio computation, as the repository tests Lua and scripts.

## Out of scope

- Floating layers: only the tiled layer resizes.
- Other windows: only the window holding the focused block resizes.
- Any change to the `rex-agent-switcher` work, other key bindings, or Rex itself.
- Deployment and `stow` runs.

## Acceptance criteria

- With three side-by-side panes, moving focus to the middle pane with the watcher running gives it about 61.8% of the window width.
- In a nested layout, the focused pane ends at about 61.8% of the width and about 61.8% of the height of the window, however deep it sits.
- Moving focus to another pane with the watcher running enlarges that pane without a keypress.
- A tab with one pane stays unchanged when the watcher runs.
- A zoomed window stays unchanged when the watcher runs.
- A split already within `min_delta` of its target is not resized again.
- Resizing does not make the watcher resize again in a loop.
- After login, the watcher runs without Etienne starting it, and restarts if it exits.

## Decisions

- Cover automatic mode only — change request after delivery: Etienne no longer wants a keyboard chord, and Rex must not clash with herdr's `ctrl+s` prefix.
- Read the ratio from a config table — Etienne chose it over a constant.
- Skip resizing while a window is zoomed — Etienne chose it over resizing under zoom.
- Start the automatic watcher by default through a LaunchAgent — Etienne wants it on without a toggle; Rex has no autostart for scripts.
- Allow `launchctl bootstrap` of the plist — Etienne approved it for this change.
- Deliver autonomously, without Codex review — Etienne's choice.

## Open questions

None.
