# Review: split-playbook-from-repo-agents-md

## Round 1 — 2026-11-06T11:02Z — fb520905

- [ ] Nit: `IMPORT_LINKS` is defined but never read; the two link tests pass the paths as literals. Use the constant or drop it — `test/playbook_test.rb:7` → fixed (Drop the unused IMPORT_LINKS constant from the playbook test)
- [ ] Nit: `test_names_every_stow_package` checks one way only: a package removed from `packages.conf` but left in the root `agents.md` package line still passes, so the line can go stale — `test/repo_agents_file_test.rb:20` → fixed (Fail when the repo agents file names a stale stow package)

Bugs: none. Security: none. Compliance: every acceptance criterion maps to a test in the diff, every `## Proof` test exists, no existing test was weakened, skipped or deleted; the Keyboard section arrives in the last commit (`agents/.agents/PLAYBOOK.md`, `test/playbook_test.rb` only). Design: `Playbook.text` is signed inline as `### Signatures` says; no glossary `Avoid:` word in the diff.

Checks: rubocop clean on the 17 touched Ruby files; shellcheck clean on `install.sh` and `install/utils.sh`. Both import links resolve to `agents/.agents/PLAYBOOK.md` (relative), and `CLAUDE.md` opens on `# Dotfiles repository`. `bin/test`: 113 of 114 files green; `test/secrets_loader_test.rb` fails locally (5 failures) because the real 1Password `op` CLI answers instead of the stub. The diff does not touch that test or `secrets/`, so the failure is not from this branch.

## Round 2 — 2026-11-06T12:01Z — 250a706f

Nothing found.

Both round 1 nits are fixed as recorded: `IMPORT_LINKS` is gone (`f3aed411`), and `test_names_no_package_that_packages_conf_dropped` fails when root `agents.md` names a package that `packages.conf` dropped (`250a706f`). Bugs: none. Security: none. Compliance: unchanged from round 1; every acceptance criterion maps to a test, every `## Proof` test exists, no existing test was weakened, skipped or deleted. Design: no new public method; no glossary `Avoid:` word in the diff. A `git grep` for lowercase `agents.md` outside `docs/changes/` finds only the repo agents file itself, the glossary entry, the two hand-off scripts and `ai.lua` (each means a repository's own file) and the tests.

Checks: rubocop clean on the 17 touched Ruby files; shellcheck clean on `install.sh` and `install/utils.sh`. `bin/test`: 113 of 114 files green; `test/secrets_loader_test.rb` still fails locally because the real 1Password `op` CLI answers instead of the stub. The branch does not touch that test or `secrets/`.
