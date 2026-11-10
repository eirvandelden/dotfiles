# Review: Remove bundler from the stow list

## Round 1 — 2026-11-10T19:42Z — 11947c4c

Nothing found. `REVIEW.md` is absent at the repository root; the passes used the reviewer defaults.

Compliance:

- On a fresh clone, `50_stow_all.sh` runs past the former `bundler` position → manual check from `plan.md`'s Proof: a fresh clone at `11947c4c` with a temp `HOME` exits 0 and logs "stow: all configured packages applied."; the `caddy` `Caddyfile` and `claude` `settings.json` links resolve into the clone. The `herdr-app` link is out of scope here, as `plan.md` records.
- The regression test fails on `main` and passes after the fix → `test/stow_package_roots_test.rb` `test_every_stowed_package_has_a_tracked_folder`. On an `origin/main` clone with this test file it fails with "packages.conf declares packages with no tracked folder: bundler."; on this branch it passes.
- Every Proof test exists: `test_a_declared_package_with_a_tracked_file_is_accepted`, `test_a_declared_package_without_a_folder_is_rejected`, `test_a_declared_package_with_only_untracked_files_is_rejected`, `test_a_declared_package_that_is_a_tracked_file_is_rejected`, `test_every_stowed_package_has_a_tracked_folder`; `test/repo_agents_file_test.rb` unchanged and green.
- No existing test is weakened, skipped or deleted. `RUBY_GEMS` keeps `bundler`. Nothing reads under `bundler/`.

Checks: `bin/test` 104 of 105 files green. `test/secrets_loader_test.rb` fails 5 tests on this branch and the same 5 on an `origin/main` clone: it reads real 1Password items on this machine (`op://Private/token/credential` not found). Not caused by this branch; per playbook rule 25 it needs its own branch. `rubocop` on `test/stow_package_roots_test.rb`: no offenses. `no-hardwrap` markdownlint on `agents.md` and `repository-layout.md`: clean.

Design: `untracked_in` and the changed `fixture_repository` carry the inline RBS signatures from `### Signatures`. No Law of Demeter chain, no query loop, no glossary `Avoid:` word in the diff.
