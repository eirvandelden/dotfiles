# Intent: Switcher moves with the arrow keys, not j and k

Author: Etienne van Delden. Status: accepted (2026-11-04). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

The Rex agent switcher binds `j` and `k` to move the selection. Etienne types Dvorak, where `j` and `k` are not next to each other and are not a navigation pair. He cannot use them.

## Proposed outcome

The up and down arrow keys move the selection. `j` and `k` no longer do anything in the switcher.

## Affected users and systems

Etienne, in the Rex agent switcher: `rex/.config/rex/switcher/pick.sh` and its tests. The change is stacked on `rex-agent-switcher` (PR #252) and targets that branch.

## Constraints

- fzf already moves the selection with the up and down arrows. The change adds no bind for them.
- Left and right arrows keep fzf's default: they move the cursor in the search text. The list has one column, so they need no list action.
- No new dependency, no migration, no deploy file. Approved permissions: none needed.
- The pull request targets `rex-agent-switcher`, not `main`. `deliver` always opens against `main`, so the coordinator retargets it with `gh pr edit --base`.

## In scope

- Remove the `j` and `k` binds from `pick.sh`.
- Remove `j` and `k` from the keys that search mode unbinds and that `esc` rebinds.
- Update the tests that name those keys.

## Out of scope

- Any other key. The filter keys `w`, `b`, `d` and `a` stay.
- Left and right arrow actions.
- Merging or changing PR #252 itself.

## Acceptance criteria

- Pressing the down arrow in the panel moves the selection down; pressing the up arrow moves it up.
- Pressing `j` or `k` in list mode does not move the selection.
- Pressing `/` unbinds only `w`, `b`, `d`, `a` and `/`; pressing `esc` in search mode rebinds only those.

## Decisions

- Remove `j` and `k`, add no replacement binds — fzf already handles the arrow keys; Etienne asked for arrows instead of hjkl.
- Delivery is autonomous with the Claude reviewer only, the same as the parent change — default chosen without asking, so Etienne can correct it before accepting.

## Open questions

None.
