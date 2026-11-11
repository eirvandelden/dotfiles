# Intent: `; space` opens the go-to picker in terminals too

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-11). Type: chore.
Delivery: autonomous. Codex review: no.

## Problem

In a herdr-app terminal, `; space` types a semicolon and a space instead of opening the `picker` mod. Most of Etienne's time is in terminals, so go-to works only sometimes, depending on where the focus is. The `terminal` section of `keys.json` overrides the global `; space` binding on purpose, since phase 3 of the herdr-app migration.

## Proposed outcome

`; space` opens the `picker` mod everywhere: in a terminal, in a herdr-app text input and in the rest of the window. A shell still gets a semicolon and a space through `; ;` followed by a space.

## Affected users and systems

- Etienne, in every herdr-app window, on macOS and Linux.
- `herdr-app/.config/herdr-app/keys.json`, its test `test/herdr_app_keys_test.rb`, and the leader runbook `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md`.

## Constraints

- No new dependency, no system tool, no migration, no deploy file. The change needs no permission under playbook rules 8, 9, 11, 12 or 13.
- One bad binding drops every binding in the window. After the change, `$HERDR_APP_HOME/keys.error` must not exist and `herdr-app status` must name no keys error.
- The other `keys.json` bindings stay as they are.

## In scope

- Remove the `terminal` override of `; space` from `keys.json`.
- Change the test that pins that override, `test_space_in_a_terminal_types_semicolon_space`, to the new behaviour.
- Correct the runbook sentence that says `; space` types a semicolon and a space in a terminal, and say how to type `; ` now.

## Out of scope

- Any other leader binding, chord or the `picker` mod itself.
- The separate `herdr-app-mod-imports` bugfix in pane t6p.
- Stowing the package or reloading a running herdr-app; Etienne does that.

## Acceptance criteria

- In a herdr-app terminal, Etienne presses `;` then space, and the go-to picker opens. The shell receives nothing.
- In a herdr-app terminal, Etienne presses `;`, `;`, then space, and the shell shows `; `.
- In the sidebar or another non-terminal part of the window, `; space` still opens the go-to picker.
- After the new `keys.json` loads, herdr-app reports no keys error.
- The runbook no longer says that `; space` types a semicolon and a space in a terminal.

## Flagged concerns

Reliable go-to in terminals conflicts with typing `; ` freely. Every `; ` typed in a terminal now opens the picker: `cd a; ls` in zsh, and prose with a semicolon in a Claude or Codex prompt. Chosen side: go-to wins; `; ;` then space types `; `.

## Decisions

- Remove the terminal override so the global `; space` applies everywhere — go-to was unreliable in terminals; `; ;` already covers typing `;`.
- Accept that `; ` in a shell or prompt opens the picker; type `; ;` then space instead — reliable go-to matters more.
- Type: chore — a one-binding change to `keys.json` with its test updated.
- Codex review: no — a small change; the Claude reviewer alone is enough.

## Open questions

None.
