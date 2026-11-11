# Intent: herdr-app mods with relative imports fail to load when stowed

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-11). Type: bugfix.
Delivery: autonomous. Codex review: no.

## Problem

After a restow of the `herdr-app` package, herdr-app does not load two mods. `herdr-app status` reports `mod core-look: module ./pick.js resolves outside the application directory ~/.config/herdr-app/mods/core-look`, and the same for `mod golden-ratio: ./controller.js`. The window no longer shows the focused space's core (orange pair on a work space, blue pair on a personal space). The focused pane no longer gets the golden ratio.

Cause: `herdr-app` is in `STOW_SHARED`, so stow links it file by file (`--no-folding`). Every mod file is a link into the repository. herdr-app's loader refuses a relative import whose real path leaves the mod folder. A linked `main.js` alone loads fine, which is why `agents-done` and the other import-free mods work. The phase 4 sandbox used real files, so it missed the fault.

## Proposed outcome

After a restow, every mod in the package loads in the live app, and a test catches a mod that herdr-app would refuse before anyone restows it.

## Affected users and systems

- Etienne's live herdr-app install (`~/.config/herdr-app/mods/`).
- The mods `core-look` and `golden-ratio`.
- The node tests that run `pick.js`, `planner.js` and `controller.js` without the app (`test/herdr_app_look_test.rb`, `test/herdr_app_golden_ratio_test.rb`).
- `test/herdr_app_package_test.rb`, whose import guard covers only `agents-done` today.

## Constraints

- `herdr-app` stays in `STOW_SHARED`: herdr-app writes `view.json`, `window.json` and caches next to the tracked files.
- No new dependency.
- Approved permission (rule 12): agents may restow only the `herdr-app` package from this worktree into `$HOME` to verify, then run `herdr-app status`. The live links then point into the worktree. Etienne restows from main after the merge.
- No other permission under rules 8, 9, 11 or 13 is approved; a need for one is a stop-and-ask.

## In scope

- core-look and golden-ratio load from a file-by-file stowed package.
- A guard test over every mod in the package: it fails when a mod holds an import that herdr-app refuses from a stowed mod.
- The node tests of the core-look and golden-ratio logic may be dropped or reshaped, if the fix makes that simpler.

## Out of scope

- Changes to herdr-app's loader.
- Changing how stow links `herdr-app` (it stays file by file).
- Behaviour changes to core-look or golden-ratio.

## Acceptance criteria

- After a restow from the branch, `herdr-app status` lists no "resolves outside the application directory" error for any mod.
- On a work space, the window shows the orange (work) pair; on a personal space, the blue (personal) pair. A hand-picked theme stays.
- After the focus settles on a pane that shares an axis with siblings, that pane gets the golden ratio of the axis.
- A mod in the package that imports `./helper.js` makes `bin/test` fail and names the mod.
- `bin/test` and the linters are green.

## Decisions

- Allow testing the core-look and golden-ratio logic through the app only; the node tests need not survive — no reason given.
- Guard every mod, not only agents-done — no reason given.
- Agents may restow the herdr-app package freely to verify — no reason given.
- Deliver autonomously, without a Codex review — no reason given.

## Open questions

None.
