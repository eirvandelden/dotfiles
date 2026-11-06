# Intent: sync herdr theme tables from Solunized

Author: Etienne van Delden. Status: accepted (2026-11-06). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

herdr 0.9.5 reads only `herdr/.config/herdr/config.toml`. It has no include or import, and `theme.name` takes built-in names only. The generated `solunized/dist/herdr/solunized-<variant>.toml` files cannot load.

The `[theme.custom.light]` and `[theme.custom.dark]` tables in the config are hand-copied from Solunized. Nothing catches drift from the generated files.

## Proposed outcome

One script copies the light and dark tables from `solunized/dist/herdr/` into the config, between `# BEGIN solunized` and `# END solunized` markers. A test fails when the block between the markers differs from `dist/herdr`.

## Affected users and systems

- `herdr/.config/herdr/config.toml`, stow-linked to `~/.config/herdr/`.
- A new sync script under `herdr/.config/herdr/scripts/`.
- `test/herdr_config_test.rb` or a new test file next to it.
- Solunized `dist/herdr/`, which the solunized change (PR #22, merged) now generates with mode headers.

## Constraints

- Solunized palette colours only.
- No change in colour values. The hand-copied tables must equal the generated ones. If any value differs, stop and tell Etienne.
- The `[ui.sidebar.agents]` rows and `pane_gaps = true` stay as they are. They are not part of the sync.
- The comments above the tables stay: what each token paints, and what herdr 0.9.5 cannot do.
- The script header says it becomes obsolete if herdr adds `include` or theme files.
- Never run `stow`. No permission is needed: no gem, tool, migration or deploy file.

## In scope

- The `# BEGIN solunized` and `# END solunized` markers in the config.
- The sync script. The solunized checkout defaults to `~/Developer/solunized`.
- A drift test. It skips with a message when `dist/herdr` is missing, as `test_herdr_accepts_the_config` does when herdr is absent.
- Checking that the current hand-copied values equal the generated ones.
- Verifying with `herdr config check` and the palette check.

## Out of scope

- Black and white variants: the sync skips them.
- The `[ui.sidebar.agents]` rows, `pane_gaps` and every other config section.
- A CI step that checks out solunized.
- Looking at dark mode on screen: Etienne has not seen it yet. The check reads `herdr config check` output only.

## Acceptance criteria

- Running the sync on today's config changes no colour value.
- Running the sync twice leaves the config byte-identical the second time.
- The test passes when the block between the markers equals the `dist/herdr` light and dark tables.
- The test fails when one colour value between the markers is edited.
- The test skips with a message when `dist/herdr` does not exist.
- `herdr config check` accepts the config.
- The comments above the tables, the `[ui.sidebar.agents]` rows and `pane_gaps = true` are unchanged.

## Decisions

- The drift test skips when `dist/herdr` is missing — CI has no solunized checkout, and the existing herdr test skips the same way.
- Deliver autonomously, Claude review only — Etienne's choice in the intent interview, no reason given.

## Open questions

None.
