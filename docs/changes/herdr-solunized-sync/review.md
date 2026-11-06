# Review: herdr-solunized-sync

## Round 1 — 2026-11-06T09:43Z — d4c6a979

Nothing found. Bugs, Security, Compliance and Design passes gave no finding.

Evidence:

- `bin/test test/herdr_config_test.rb test/herdr_sync_solunized_theme_test.rb`: 19 runs, 0 failures, 0 skips.
- `shellcheck -x -S warning` on the script and `rubocop` on both test files: no offences.
- `HERDR_CONFIG_PATH=herdr/.config/herdr/config.toml herdr config check`: `config: ok`.
- The script on a copy of the real config with `~/Developer/solunized` leaves it byte-identical, so the hand-copied tables equal the dist tables.
- `SOLUNIZED_DIR=/nonexistent`: both drift tests skip with `no Solunized checkout at /nonexistent/dist/herdr`.
- Compliance: every acceptance criterion maps to a test in `## Proof` or to a check that passes above. All 12 script tests and both drift tests named in the plan exist. The diff changes only the files that the plan lists. The config diff adds only the two marker lines. No existing test changed.
- Design: no avoided glossary word in the diff. The new test helper `assert_block_matches_dist` has its `#:` signature. The diff adds no public Ruby method, call chain or query loop.

Outside this diff: the full `bin/test` run has one red file, `test/secrets_loader_test.rb`. Its tests reach the real 1Password `op` CLI (`"token" isn't an item in the "Private" vault`), so the cause is the local environment. This branch does not touch that test or `secrets/`.
