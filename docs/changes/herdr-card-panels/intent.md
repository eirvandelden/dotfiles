# Intent: herdr panels as cards on a darker frame

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

herdr separates panes, tabs and the sidebar with dark lines. Etienne wants the chrome to look like a darker frame around lighter panes, as in other terminals he tried. The agent rows in the sidebar also waste a line on the agent state, which the state icon already shows.

## Proposed outcome

The tab bar and the sidebar share one slightly darker colour, the frame. Panes stay on the lighter terminal background and read as cards on that frame. The dark seam lines are gone. Selected sidebar rows use the pane colour, so they join the panes. The focus colour is orange. Each agent row takes two lines: the state icon with the title, then the workspace. The title colour follows the theme.

## Affected users and systems

Etienne's herdr UI. The file is `herdr/.config/herdr/config.toml`, installed by the `herdr` stow package. The Ghostty palette is unchanged.

## Constraints

- Every colour value comes from the Solunized palette (`~/Developer/solunized/themes.yml`, `docs/colors.md`). No other hex value appears.
- herdr 0.9.5 has no border-radius, pane-padding or gap-size setting. The gap between split panes is fixed at one cell and cannot be painted, so it shows the terminal background.
- herdr colours the split dividers from `accent` and `overlay0`, yet a dark line stayed in a test with those two changed. The unknown source of that line is not part of this change.
- Rules in agent rows match only their own token's value. A title or workspace colour cannot follow the agent state.
- `[theme.custom]` does not follow the system light/dark switch. Dark mode gets Solunized Dark values, which the plan must define.
- Configuration has no tests. `herdr config check` must accept the file.
- `test/herdr_config_test.rb` already fails on `main` (toast `terminal` against `system`). Etienne chose to leave it and report it, against playbook rule 25.

## In scope

Settled light values, from a tested session:

- `accent` `#a44910` (`br_orange`), replacing the blue.
- `active_row_bg` `#fffbf1` (`bg_0`), the pane colour.
- `panel_bg`, `sidebar_bg` and `surface_dim` `#eeeae0` (`bg_1`): the frame, and the seams blending into it.
- `overlay0` stays `#d5d2c8` (`bg_2`).
- `[ui]` gets `pane_gaps = true`. `pane_borders` stays `auto`.
- Agent rows, two lines: the state icon and `terminal_title_stripped` in herdr's default colour, then `workspace` in the default colour.
- Matching dark-mode values, taken from the regenerated `dist/herdr/solunized-dark.toml` of the solunized change, not copied by hand.
- A rewritten config comment that says what each token paints and what herdr cannot do.

## Out of scope

- The solunized repository change itself. It is a separate change with its own intent, branch and pull request in `~/Developer/solunized`: it updates `applications/herdr/template.toml.erb` to the settled tokens, regenerates `dist/herdr` and adds a content test.
- A feature request upstream for pane padding, a paintable gap, rounded corners or the divider colour.
- Rounded corners, pane padding and gap size: herdr cannot do them.
- Toast and sound settings.
- The uncommitted edits on `main` (`settings.json`, `herdr_config_test.rb`).

## Acceptance criteria

- No dark seam line is drawn around the tab bar or the sidebar. The tab bar and the sidebar share the frame colour `#eeeae0`.
- Panes show the lighter terminal background and read as cards against the frame. In dark mode the frame is the lighter `bg_1`.
- The focused pane border is orange `#a44910`, and an inactive pane border is `#d5d2c8`.
- Selected sidebar rows use `#fffbf1`, the pane colour.
- Each agent row shows two lines: the state icon with the title, then the workspace. No state text line. The title has no `fg` override, so it follows the active theme in light and dark.
- Every hex value in the new theme settings is a Solunized palette value.
- `herdr config check` reports no diagnostics.

## Flagged concerns

- The old criterion of a darker backdrop between split panes is dropped. herdr 0.9.5 cannot paint the gap. The panes sit on the Ghostty background, and the frame is the darker colour. Etienne chose this reversed contrast after testing.
- The test failure on `main` stays open and is reported in the pull request. Etienne chose this over fixing it first.

## Decisions

- Restyle panes, tab bar and sidebar, not panes only — Etienne chose the wider scope.
- Use only Solunized palette colours — to keep one palette.
- Reversed contrast: the frame is darker than the panes — after testing, Etienne found it "better" than a darker backdrop.
- Do not change the Ghostty background — it would darken the pane content as well and remove the card contrast.
- Keep `pane_borders` on `auto` — Etienne found it better than `always`.
- The focus colour is Solunized `br_orange` `#a44910` — Etienne asked for bright orange.
- Selected sidebar rows use the pane colour — Etienne found it better.
- Agent rows use two lines, no state text — the icon already shows the state, and the one-line layout was judged too crowded.
- The title has no `fg` override, so it follows the active theme in both modes — a fixed `#243f47` would be unreadable in dark mode; Etienne chose this over keeping it (replaces the earlier `fg_0` choice).
- Dark mode gets values from Solunized Dark — Etienne chose this over keeping light values.
- Dark mode frame is the lighter `bg_1` `#0d3b4a`, which flips the contrast against light mode — no colour in Solunized Dark is darker than the pane colour; Etienne took the recommended option.
- Change solunized too, so the herdr template is the single source of the dark values — Etienne's choice over copying them by hand.
- Leave the failing toast test on `main` and report it — Etienne's choice, no reason given.
- Ship without rounded corners or padding — herdr cannot do them, as already agreed.

## Open questions

None.
