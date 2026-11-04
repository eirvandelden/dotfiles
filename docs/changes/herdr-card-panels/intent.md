# Intent: herdr panels as cards on a darker background

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

herdr separates panes, tabs and the sidebar with dark lines. Etienne wants each panel to look like a card lying on a darker background, as in other terminals he tried.

## Proposed outcome

Panes and the sidebar read as separate panels. A slightly darker backdrop shows between them instead of a dark line. The tab bar uses that same backdrop colour, so it sits on the backdrop rather than on a card. Panel corners are rounded where herdr allows it.

## Affected users and systems

Etienne's herdr UI. The file is `herdr/.config/herdr/config.toml`, installed by the `herdr` stow package. The Ghostty palette is unchanged.

## Constraints

- herdr 0.9.5 has no border-radius setting. Available keys: `ui.pane_gaps`, `ui.pane_borders`, `ui.pane_outer_borders`, and the theme tokens `panel_bg`, `sidebar_bg`, `surface_dim`, `overlay0`.
- The current `[theme.custom]` block holds light-palette values only and does not follow the system light/dark switch. The new values follow the same rule.
- Every colour value in the change comes from the Solunized palette (`~/Developer/solunized/themes.yml`, `docs/colors.md`). The light values in use are `bg_0` `#fffbf1`, `bg_1` `#eeeae0`, `bg_2` `#d5d2c8` and `blue` `#0068c9`. No other hex value appears.
- Configuration has no tests. `test/herdr_config_test.rb` must stay green, and `herdr config check` must accept the file.

## In scope

- Gaps between split panes, so the backdrop shows through.
- Background tokens so panes and the sidebar are cards on a darker backdrop.
- The tab bar background equals the backdrop colour, if herdr has a token for it. If herdr ties the tab bar to a token that also colours a card, report it and keep the tab bar on its current colour.
- Replacing the dark border lines with the backdrop contrast.
- Rounded corners, only if herdr draws them once `pane_gaps` is on.

## Out of scope

- A dark-mode palette.
- Changes to the herdr binary or a feature request upstream.
- The sidebar agent rows, the toast and sound settings.
- The uncommitted edits on `main` (`settings.json`, `herdr_config_test.rb`).

## Acceptance criteria

- With two split panes open, a darker backdrop shows between them and no dark line is drawn.
- The sidebar stands out as a panel against that backdrop.
- The tab bar has the same background colour as the backdrop, with no visible edge between them.
- The focused pane is still told apart from an inactive one.
- Every hex value in the new theme settings is a Solunized palette value.
- `herdr config check` reports no diagnostics, and `test/herdr_config_test.rb` passes.

## Decisions

- Restyle panes, tab bar and sidebar, not panes only — Etienne chose the wider scope.
- The tab bar takes the backdrop colour instead of being a card, "if possible" — no reason given.
- Use only Solunized palette colours, nothing else — Etienne's instruction, to keep one palette.
- If herdr cannot round corners, ship the flat card look and report it — Etienne chose this over dropping the change.

## Open questions

None.
