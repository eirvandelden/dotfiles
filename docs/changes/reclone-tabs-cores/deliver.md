# Delivery account: reclone-tabs-cores

## Behaviour delivered

`tabs-cores` is the installed herdr-app 0.1.16 tabs mod again, with the sidebar-width term removed from its padding and the mod paths renamed to `mods/tabs-cores/`. `mod.json` records `cloned_from.version` 0.1.16. `test_the_cloned_tabs_mod_differs_from_tabs_only_in_the_padding` passes again.

## Evidence

- Before: `ruby test/herdr_app_look_test.rb` failed 1 of 27 on `main` as well, so no branch caused it.
- After: the coordinator ran `ruby test/herdr_app_look_test.rb` with rv Ruby 4.0.9: 27 runs, 129 assertions, 0 failures, 0 skips.
- The implement stage ran `herdr-app check`, which passed. The four `win-*.svg` files are byte-equal to the installed ones.

## Checks

- `bin/test`: 0 failed (implement stage: 94 runs; reviewer: 126 files).
- Lefthook pre-commit linters passed on the changed files. ESLint ignores `main.js` by design.
- No Brakeman or Bundler Audit run: the change has no Ruby application code.

## Review outcome

One Claude round, nothing found, closed. No Codex round (`Codex review: no`).

## For Etienne

- The live tab bar gets the new code only after the merge into the main checkout and a mod reload.
- The test still reads the installed app's tabs mod, so it fails again after the next herdr-app update that changes it. This stays out of scope by the intent.
- `ruby` on PATH in the stage panes resolved to the macOS system Ruby 2.6. The stages ran rv's 4.0.9 by path. No toolchain was changed.
