# Intent: Re-clone the tabs-cores mod from the installed tabs mod

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

`test/herdr_app_look_test.rb` `test_the_cloned_tabs_mod_differs_from_tabs_only_in_the_padding` fails. It compares `herdr-app/.config/herdr-app/mods/tabs-cores/main.js` with the tabs mod that the installed herdr-app ships at `~/.config/herdr-app/mods/tabs`. The installed app is 0.1.16 and its tabs mod gained label code (`clean`, `label`) that follows an agent's live title. The clone records `cloned_from` version 0.1.15 and lacks that code. The failure also shows on `main`, so no branch caused it.

## Proposed outcome

`tabs-cores` is the installed tabs mod again, with the sidebar-width term removed from its padding and the mod paths renamed to `mods/tabs-cores/`. The failing test passes.

## Affected users and systems

- `herdr-app/.config/herdr-app/mods/tabs-cores/main.js` and `mod.json`.
- `test/herdr_app_look_test.rb`, read-only: it is the proof.
- Etienne's tab bar in the cores layout.

## Constraints

- The clone differs from the installed mod in the padding only, as the test and its helper `cloned_main` define: replace `mods/tabs/` with `mods/tabs-cores/` and drop ` - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0)`.
- Edit sources in `~/Developer/dotfiles/<package>/`, never the links under `~/.config`. No `stow`, no new stow package.
- Playbook rules apply: worktree from `worktree-create`, one logical change per commit, every touched file linted, no linter disables.
- Approved permissions: none needed beyond the default. No gems, packages, system tools, migrations or deploy files.

## In scope

- Regenerate `tabs-cores/main.js` from the installed `tabs/main.js` with the transform above.
- Set `cloned_from.version` in `tabs-cores/mod.json` to 0.1.16, the installed herdr-app version.
- Check that the four `win-*.svg` files and the rest of `mod.json` still match the installed mod. They matched when this intent was written.

## Out of scope

- Changing `test/herdr_app_look_test.rb` or making it independent of the installed app. It will fail again after the next herdr-app update that changes the tabs mod.
- Any other mod, the cores layout, or the sidebar.
- Re-running `stow` to refresh `~/.config/herdr-app`.

## Acceptance criteria

- `ruby test/herdr_app_look_test.rb` passes with 0 failures.
- `tabs-cores/main.js` carries the installed mod's label code and keeps `Math.max(10, (root.traffic_lights[0] + 64) / settings().zoom)` as its padding, with no `sidebar?.size?.px`.
- `tabs-cores/mod.json` still names `tabs` as its source and records version 0.1.16.
- `bin/test` and every linter pass, apart from failures that `main` already has.

## Decisions

- Re-clone the mod instead of loosening the test — Etienne: "lets do the reclone".
- Autonomous delivery without a Codex review — Etienne chose it from the delivery options; no reason given.
- Record 0.1.16 as the clone's source version — the installed herdr-app is 0.1.16 and the recorded 0.1.15 is stale; Etienne chose it from the options.

## Open questions

None.
