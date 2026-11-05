# Plan: herdr panels as cards on a darker frame

From `intent.md` (2026-11-04). Status: accepted.

## Design

### Domain terms

`GLOSSARY.md` has no entry for these words. The terms below are working terms for this plan. Etienne has not agreed them for the glossary.

- **Frame**: the colour shared by the tab bar and the sidebar. In light mode it is `bg_1` `#eeeae0`, darker than the panes. In dark mode it is `bg_1` `#0d3b4a`, lighter than the panes.
- **Card**: a pane on the terminal default background, `bg_0` in both modes.
- **Seam**: the colour herdr draws between chrome regions, from `surface_dim`.

### Diagrams

Not affected: one TOML config file changes. No object model changes.

### Signatures

Not affected: no Ruby class or method changes.

Not checked: this project has no Steep and no RBS for a config file.

### Complexity

Not affected: herdr resolves the palette once per config load and once per appearance change.

### Invariants

- Every hex value in `herdr/.config/herdr/config.toml` is a Solunized palette value. It comes from `~/Developer/solunized/themes.yml`, through the generated `dist/herdr/solunized-<variant>.toml` of the merged solunized change. A check enforces it.
- `[theme.custom.light]` and `[theme.custom.dark]` hold the same keys, so a token never exists in only one mode.

### Alternatives

- Keep `auto_switch = false` and put light values in `[theme.custom]` only. Rejected: dark mode then shows a light frame and a light sidebar, which Etienne rejected in favour of Solunized Dark values.
- Name two different built-in themes for `light_name` and `dark_name`. Rejected: `terminal` supplies the base palette in both modes, and the mode tables replace six tokens on top of it, so both names stay `terminal`.

## Design decisions

- **Dark-mode switch.** `[theme]` sets `auto_switch = true` and `light_name = "terminal"` and `dark_name = "terminal"`. `herdr config check` accepts it. herdr follows the host terminal's colour-scheme report and falls back to the inferred background appearance, so the Ghostty Solunized swap drives it. The old comment that `auto_switch` stays off is rewritten.
- **Tokens live in the mode tables.** `[theme.custom]` is left empty, so there are no shared values. `[theme.custom.light]` and `[theme.custom.dark]` each hold `accent`, `active_row_bg`, `panel_bg`, `sidebar_bg`, `surface_dim` and `overlay0`.
- **Light values** (from `dist/herdr/solunized-light.toml` of the solunized change, with `overlay0` unchanged): `accent` `#a44910`, `active_row_bg` `#fffbf1`, `panel_bg`, `sidebar_bg` and `surface_dim` `#eeeae0`, `overlay0` `#d5d2c8`.
- **Dark values** (from `dist/herdr/solunized-dark.toml`): `accent` `#fa9253`, `active_row_bg` `#012b38`, `panel_bg`, `sidebar_bg` and `surface_dim` `#0d3b4a`, `overlay0` `#2a5d6e`.
- **`[ui]`**: `pane_gaps = true` is set explicitly. `pane_borders` stays unset, which means `auto`.
- **Agent rows.** `rows` becomes `["state_icon", "terminal_title_stripped"]` then `["workspace"]`, with the title `fg = "#6a8990"` (`dim_0`) and `dim = false`. herdr draws the title with `overlay0`, nearly invisible on the frame (contrast 1.3 light, 1.7 dark), and a fixed `fg` cannot follow the light and dark switch, so Etienne chose one value readable in both (3.1). The old blue `#0068c9` overrides go.
- **Failing toast test.** `test/herdr_config_test.rb` already fails on `main` (`terminal` against `system`). This plan does not touch it, as Etienne decided.
- **Comment block.** The two comments above `[theme.custom]` and `[ui.sidebar.agents]` are rewritten to say what each token paints and what herdr 0.9.5 cannot do: rounded corners, pane padding, gap size, a paintable gap and the divider source.

## Integration points

- `~/Developer/solunized` (merged as #21): the dark and light values come from its generated herdr files.
- Ghostty (`ghostty/.config/ghostty/themes/solunized-{light,dark}`) swaps the terminal palette with the system appearance. herdr reads the host report and switches its mode tables.
- The `herdr` stow package links `config.toml` into `~/.config/herdr/`. Etienne runs `stow`; this change does not.

## Files that change

- `herdr/.config/herdr/config.toml` — `[theme]` auto-switch settings, the two mode tables, `pane_gaps`, the agent rows and their comments.

## Order of work

1. Edit `herdr/.config/herdr/config.toml` as in the design decisions. Configuration has no tests, so no test comes first.
2. Run `HERDR_CONFIG_PATH="$PWD/herdr/.config/herdr/config.toml" herdr config check`. Expect `config: ok`.
3. Run the palette check from the Proof section.
4. Run `ruby test/herdr_config_test.rb`. Expect only the known toast failure.
5. Start a test session and check the light look: `HERDR_CONFIG_PATH="$PWD/herdr/.config/herdr/config.toml" herdr --session card-panels`, split one pane, and look. Then `herdr session stop card-panels` and `herdr session delete card-panels`.
6. Re-read the diff. Every hunk must be required by the task.

## Risks

- `light_name = "terminal"` and `dark_name = "terminal"` may not switch the mode tables if herdr reads only the theme name. The test session in step 5 shows it. Etienne checks dark mode by switching the system appearance, which this plan cannot do.
- The title is a fixed `dim_0` `#6a8990`, greyer than the `#243f47` Etienne first picked. Etienne chose it for readability in both modes.
- Dark mode flips the contrast: the frame is lighter than the panes. Etienne decided this.
- One dark seam line stayed in a herdr test with outer borders off. The settled look keeps outer borders on, and no test showed a dark line there.

## Proof

- No dark seam line is drawn around the tab bar or the sidebar; they share the frame colour → check: `HERDR_CONFIG_PATH="$PWD/herdr/.config/herdr/config.toml" herdr config check` prints `config: ok`, then the light look in the `card-panels` test session shows no dark seam. The look is pending Etienne's eyes.
- Panes read as cards against the frame, and in dark mode the frame is the lighter `bg_1` → check: the test session for light; pending Etienne for dark, by switching the system appearance.
- The focused pane border is `#a44910` and an inactive border is `#d5d2c8` → check: `grep -nE '^(accent|overlay0)' herdr/.config/herdr/config.toml` shows both values in `[theme.custom.light]`.
- Selected sidebar rows use `#fffbf1` → check: `grep -n 'active_row_bg' herdr/.config/herdr/config.toml` shows `#fffbf1` in light and `#012b38` in dark.
- Each agent row shows two lines and the title is `#6a8990` → check: `sed -n '/^rows = \[/,/^\]/p' herdr/.config/herdr/config.toml` prints the two rows, with `fg = "#6a8990"` on the title only.
- Every hex value is a Solunized palette value → check: `ruby -ryaml -e 'pal=YAML.load_file(File.expand_path("~/Developer/solunized/themes.yml"))["themes"].values.flat_map { |t| t["colors"].values }.map(&:downcase); cfg=File.read("herdr/.config/herdr/config.toml").scan(/#\h{6}\b/).map(&:downcase).uniq; abort("not in palette: #{cfg - pal}") unless (cfg - pal).empty?; puts "ok"'` prints `ok`.
- `herdr config check` reports no diagnostics → check: `HERDR_CONFIG_PATH="$PWD/herdr/.config/herdr/config.toml" herdr config check` prints `config: ok`.
- Invariant: the light and dark tables hold the same keys, enforced by the edit → check: `diff <(sed -n '/^\[theme.custom.light\]/,/^$/p' herdr/.config/herdr/config.toml | grep -oE '^[a-z_0-9]+') <(sed -n '/^\[theme.custom.dark\]/,/^$/p' herdr/.config/herdr/config.toml | grep -oE '^[a-z_0-9]+')` prints nothing.

Per changed file, the unit tests expected: none. Configuration has no tests, and `test/herdr_config_test.rb` `test_herdr_accepts_the_config` already runs `herdr config check` on this file.

Test setup: not needed.

---
Domain skills applied: None.

## Critique

### Round 1 (Codex)

- `terminal_title_stripped` is transient pane metadata, and a pane without an OSC title shows only its icon on line 1 → dismissed: Etienne chose this layout after testing it, and a title-less pane still names its workspace on line 2; an `agent` fallback would add a token to the settled layout
- The alternatives text says both theme names stay `terminal` because every colour comes from the terminal palette, which conflicts with the explicit overrides → fixed (reworded: `terminal` supplies the base palette and the mode tables replace six tokens on top)
