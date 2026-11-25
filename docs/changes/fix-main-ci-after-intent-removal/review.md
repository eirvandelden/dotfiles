# Review: fix-main-ci-after-intent-removal

## Round 1 — 2026-11-25T13:00:11Z — acdf2c46

No findings.

The repository has no `REVIEW.md` or `REVIEW.local.md`, so this round runs the default passes: Bugs, Security, Compliance, Design.

- Bugs: none. `agents/.agents/skills/plan/SKILL.md` exists and has no `upstream:` comment, so the edited test still writes a marker into a non-vendored skill and expects the push to fail. `brainstorming/SKILL.md` carries an upstream comment, and its new `.gitattributes` line sits in ASCII order between `android-intent-security` and `brakeman`. No other `skills/intent` path remains outside change folders except inside `test/no_intent_references_test.rb` itself.
- Security: none. The diff touches one attribute line and one test path.
- Design: none. The diff adds no public method and no name that `GLOSSARY.md` lists under `Avoid:`.
- Compliance:
  - Targeted run `rv run -- bin/test test/no_intent_references_test.rb test/vendored_skills_test.rb test/lefthook_branch_files_test.rb` → 15 runs, 0 failures.
  - `test_names_no_intent_artefact_outside_change_folders` → passes.
  - `test_every_upstream_skill_folder_is_marked_vendored` → passes.
  - `test_a_marker_in_a_non_vendored_skill_blocks_the_push` → passes; its assertions are unchanged apart from the path, so the test is not weakened.
  - `rubocop` on `test/lefthook_branch_files_test.rb` → no offenses.
  - Full `rv run -- bin/test` → 137 of 138 files pass. `test/delivery_preflight_test.rb` `test_a_hung_command_times_out_as_missing` fails its wall-clock bound (`Expected 396.03 to be < 15`), also when run alone. The machine load average was 42 during the run, and the file took 3624 s for 35 tests. The diff does not touch `delivery-preflight` or anything it reads, so this is not a finding on this branch. The `Dotfiles tests` workflow on the pull request is the proof for the full-suite criterion.
  - `Dotfiles tests` workflow green → pending; the pull request does not exist yet.
