# Review: herdr-app-mod-imports

## Round 1 — 2026-11-12T12:55Z — 1dd63651

No `REVIEW.md` or `REVIEW.local.md` exists at the repository root, so the default passes ran: Bugs, Security, Compliance, Design.

Checks run: `bin/test` on the three herdr-app test files is green (32 + 27 + 21 runs). `rubocop -c rubocop/.rubocop.yml test/herdr_app_*.rb` is clean. The no-hardwrap markdownlint on `GLOSSARY.md` and `herdr-app-look.md` is clean. The full `bin/test` is red in two files that the diff does not touch: `test/repo_agents_file_test.rb` and `test/secrets_loader_test.rb` (see findings).

Live state: `~/.config/herdr-app/mods/core-look/` and `golden-ratio/` hold only `main.js` and `mod.json` links into this worktree, with no `pick.js`, `planner.js` or `controller.js`.

Compliance:

- No "resolves outside the application directory" error after a restow → `test_herdr_app_loads_every_mod_through_links` (passes locally); live links verified as above.
- Work pair, personal pair, hand pick stays → `test_a_work_space_asks_for_the_work_pair`, `test_a_personal_space_asks_for_the_personal_pair`, `test_a_hand_picked_theme_is_left_alone`, through the mod copy.
- Golden ratio after the focus settles → the 32 golden-ratio tests, through the mod copy; their bodies and assertions are unchanged.
- A mod that imports `./helper.js` fails `bin/test` and names the mod → `test_the_import_guard_names_a_mod_with_a_path_import`, `test_no_mod_holds_a_path_import`.
- `bin/test` and the linters are green → linters green; `bin/test` red, for reasons outside this diff (first finding).
- Every test named in `plan.md`'s Proof exists. No test was weakened: the old `refute_match(%r{from\s+["']\.\.?/})` on `agents-done` became the wider guard over every mod, and `test_core_look_never_edits_the_layout` reads only `main.js` because `pick.js` is gone.

Bugs and Security: nothing found. The folds are word for word. `HOST_EXPORTS` covers every name both mods import. The stubs throw when called. No secret or home path enters the repository.

- [ ] Important: `bin/test` is red on main, so the acceptance criterion "`bin/test` and the linters are green" cannot hold. `7ebcd89f remove conductor` dropped `conductor` from `packages.conf`, but the repository's `agents.md` line 7 still names it. `RepoAgentsFileTest#test_names_no_package_that_packages_conf_dropped` fails locally and in main's last CI run (PR #279 merge, `b0745263`). Playbook rule 25 asks for a fix on its own branch from main, then a rebase of this branch onto it. Do not fix it on this branch. — `agents.md:7` → dismissed: Etienne decided (2026-11-12) to open the PR with the red main CI and fix `conductor` on its own branch (rule 25), out of this change's scope
- [ ] Nit: `SecretsLoaderTest` fails 4 tests on this machine but passes on CI. The test calls the real `op` (`could not read secret 'op://Private/token/credential'`), so the test environment does not fully isolate the 1Password CLI from the shell. The diff does not touch this test. Look into it on its own branch. — `test/secrets_loader_test.rb:37` → dismissed: fails only on this machine, outside this diff; belongs on its own branch
- [ ] Nit: `mod_names` lists every entry under `mods/`, ignored or untracked ones too. A stray `.DS_Store` or a leftover untracked mod folder gives an empty linked mod folder, and `herdr-app check` then fails it as a false hit. Take the mod names from `tracked_package_files`, as `linked_mod_failure` already does for the files. — `test/herdr_app_package_test.rb:185` → fixed (Take herdr-app mod names from tracked files)
- [ ] Nit: `path_imports` scans only `**/*.js`. A path import in a `.mjs` or `.cjs` file escapes the CI guard; only the local loader check would catch it. Scan `**/*.{js,mjs,cjs}`. — `test/herdr_app_package_test.rb:211` → fixed (Scan mjs and cjs files for mod path imports)
- [ ] Nit: `NodeRunner#run_script` is a new public method with no inline `#:` signature, and `plan.md`'s `### Signatures` does not name it. Add the signature, or make it private. — `test/herdr_app_golden_ratio_test.rb:89` → fixed (Add an inline RBS signature to NodeRunner#run_script)

## Round 2 — 2026-11-12T13:06Z — de34d341

No `REVIEW.md` or `REVIEW.local.md` exists at the repository root, so the default passes ran again: Bugs, Security, Compliance, Design. This round reads the three fix commits since `1dd63651` and re-runs the checks on the full diff.

Checks run: `bin/test` on the three herdr-app test files is green (21 + 27 + 32 runs, 0 skips, so the linked-mod loader check ran). `rubocop -c rubocop/.rubocop.yml test/herdr_app_*.rb` is clean. The full `bin/test` is red only in the two files round 1 dismissed: `test/repo_agents_file_test.rb` (the `conductor` line in `agents.md`) and `test/secrets_loader_test.rb` (machine-local `op` calls, now 5 tests instead of 4; same cause).

Round 1 fixes, verified:

- `mod_names` now takes each mod name from `tracked_package_files`, so a stray `.DS_Store` or an untracked mod folder no longer reaches `herdr-app check`. `path_imports` still lists every folder under `mods_root`; that is correct, because its self-test runs on a scratch folder with no tracked files, and an untracked mod with a path import fails safe.
- `mod_path_imports` globs `**/*.{js,mjs,cjs}`. Ruby expands the braces: a scratch folder with `a.mjs`, `b.cjs` and `c.js` gives all three.
- `NodeRunner#run_script` has the inline signature `#: () { (String) -> String } -> untyped`, which matches its block use.

Bugs, Security, Compliance and Design: nothing new found.
