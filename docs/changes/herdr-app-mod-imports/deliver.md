# Delivery account: herdr-app-mod-imports

## Behaviour delivered

- `core-look` and `golden-ratio` load from the file-by-file stowed `herdr-app` package. Each mod's helper modules (`pick.js`; `planner.js`, `controller.js`) are folded into its `main.js`, which exports the pure logic by name. Behaviour does not change.
- A guard over every tracked mod in `test/herdr_app_package_test.rb`: a scan for path imports in `.js`, `.mjs` and `.cjs` files (runs on CI), a self-test that names a fixture mod with `./helper.js`, and a real `herdr-app check` of each mod through a linked mod folder (local; skips without herdr-app).
- The node tests of `themePick` and the golden-ratio planner and controller keep their assertions. They run against a copy of `main.js` with throwing module stubs for `herdr` and `gpui-kit` (`test/herdr_app_mod_copy.rb`).
- Docs: `herdr-app-look.md` and six `GLOSSARY.md` terms.

## Evidence

- The guards were red before the fold and named `core-look` and `golden-ratio`; green after.
- Live, after a restow of `herdr-app` from the worktree, `herdr-app status` shows `"errors": []`.
- Work space (OnsClient pane): layouts/.state/cores.json `.theme` = solunized-light-orange / solunized-dark-orange; orange focus border.
- Personal space (Stickers pane): `.theme` = blue pair; blue focus border.
- Hand pick: `herdr-app do app.theme --name atom-one-dark` gave {light: solunized-light-blue, dark: atom-one-dark}; it stayed through a focus to work and back. Restored with `app.theme --name solunized-dark-blue`.
- Golden ratio: two-pane row in tab "Claude Code"; after focus the weights read via `doc.get` were 0.6180 / 0.3820. A two-row focus path gave 0.7861 / 0.2139 (sqrt 0.618) in the inner row.
- `herdr-app status` ends with `"errors": []`.
- Caveat: mods run only while the window draws; one hand-pick run was void while the full-screen Space was hidden, and was repeated.
- Side effect: `.theme` in layouts/.state/cores.json is now an explicit blue pair (was null); the shown pair is the same.

## Checks

- `bin/test test/herdr_app_package_test.rb test/herdr_app_look_test.rb test/herdr_app_golden_ratio_test.rb`: 21, 27 and 32 runs, 0 failures, 0 skips.
- `rubocop -c rubocop/.rubocop.yml` on the touched Ruby files: no offenses. no-hardwrap markdownlint on the touched markdown: clean.
- Full `bin/test` is red in two files outside this diff: `test/repo_agents_file_test.rb` (`agents.md` still names `conductor`, which `packages.conf` dropped in `7ebcd89f`; main's CI is red for the same reason) and `test/secrets_loader_test.rb` (calls the real `op` on this machine; green on CI). Etienne chose to open the PR with the red CI and fix `conductor` on its own branch.
- No Brakeman or Bundler Audit target in this change.

## Review

- Round 1 (Claude): 1 Important, 4 Nits. The two findings about pre-existing failures were dismissed; three test Nits were fixed (`Take herdr-app mod names from tracked files`, `Scan mjs and cjs files for mod path imports`, `Add an inline RBS signature to NodeRunner#run_script`).
- Round 2 (Claude): no findings. No Codex review (intent: `Codex review: no`).

## After the merge

- The live links in `~/.config/herdr-app` point into this worktree. Restow `herdr-app` from main (`stow -D` from the worktree, then stow from main with `--no-folding`) before the worktree is removed, or every mod breaks.
- The implement stage moved herdr-app's default `keys.json` and `settings.json` to `~/.config/herdr-app/{keys,settings}.json.defaults-bak` and `.defaults-bak2`. They are safe to trash.
