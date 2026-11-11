# Intent: Golden ratio in herdr-app

Author: Etienne van Delden. Status: accepted. Type: feature. Delivery: autonomous. Codex review: no.

## Problem

In the herdr TUI, the `vv.golden-ratio` plugin gave the focused pane 61.8% of the tab on each axis on every focus change. herdr-app has no such behaviour, so after the move from the TUI to herdr-app the focused pane keeps whatever size the layout gave it.

## Proposed outcome

In herdr-app, focusing a pane resizes it to the golden ratio of its tab, with no keypress, as the TUI plugin did.

## Affected users and systems

- Etienne, in herdr-app (`/Applications/Herdr.app`).
- The `herdr-app` stow package (`herdr-app/.config/herdr-app/`). herdr-app mods can call `layout.resize {id, weight}` and `layout.set`.
- The herdr TUI plugin config (`herdr/.config/herdr/plugins/config/vv.golden-ratio/`) and the Rex Lua planner (`rex/.config/rex/golden_ratio.lua`) are separate and stay as they are.

## Constraints

- No new dependency, no new stow package, no deploy file. The change lives in the existing `herdr-app` package.
- The behaviour matches the TUI plugin defaults: ratio 0.618, a debounce so rapid focus changes settle (TUI: 120 ms), and no resize when the pane is already within a small delta of the target (TUI: 0.02).
- Edit sources in the dotfiles package, never the link under `~/`. No `stow` run without an explicit request.

## In scope

- Rebalance the focused pane on every focus change, on both axes.
- Settings for ratio, debounce and minimum delta, with the TUI defaults.
- Tests for the pure planning logic, and an integration test that proves the behaviour.
- A short README note on the herdr-app behaviour.

## Out of scope

- A key binding or a toggle for auto mode.
- Changes to the TUI plugin, to Rex, or to the `spaces-cores` mod's own behaviour.
- Removing the TUI plugin.

## Acceptance criteria

- Focusing a pane in a tab with two side-by-side panes gives the focused pane 61.8% of the tab width.
- Focusing a pane in a stack of two panes gives the focused pane 61.8% of the tab height.
- In a nested layout, the focused pane gets 61.8% on each axis it shares with a sibling.
- A tab with one pane is left unchanged.
- Moving focus back and forth quickly ends with one settled layout for the last focused pane.
- A pane already within the minimum delta of the target is not resized again.
- A zoomed pane is left unchanged.

## Decisions

- Rebalance on every focus change, no keypress — it is what the TUI plugin did with `auto = true`.
- Deliver autonomously, no Codex review — personal repository, small change.
- Write one small local mod in the `herdr-app` package — no existing herdr-app mod does it. The TUI plugin `vigneshwerv/herdr-golden-ratio` never fires under herdr-app (empty plugin log): it hooks the TUI's `herdr server`, not `herdr-core`.

## Open questions

None.
