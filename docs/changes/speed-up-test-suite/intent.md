# Intent: Speed up the dotfiles test suite

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Amendment 2026-10-21

PR #229 (`faster-test-suite`) merged to `main` while this change was in review. It ships a parallel runner `bin/test` (`-j N`, process groups, INT and TERM handling, `test/test_runner_test.rb`), a native-lefthook `LefthookBinary.locate`, and CI that runs `bin/test`. Etienne chose to keep main's versions and keep this change's test work. The runner, `LefthookBinary` and CI items below are dropped. What remains is the hooks copy, the chained and deleted hook tests, and their evidence.

## Problem

The `test/*_test.rb` suite takes about 25 minutes when run file by file. Agents that run it wait too long. Ten files take 62% of that time. Each test spends its time waiting on processes: every commit in a temporary repository fires three or four git hooks, and each hook starts lefthook. The test helper `LefthookBinary.locate` picks the RubyGems binstub, which boots Ruby on every call. Each test also copies the seven hook scripts into a new temporary directory.

## Proposed outcome

The full suite runs in a fraction of today's time with the same behaviour covered. One command runs the suite in parallel. Tests that repeat the same setup and commit run as one test.

## Affected users and systems

Etienne and every agent that runs the dotfiles tests. Files: `test/hook_scripts.rb`, the six hook test files that copy the hook scripts, and `test/branch_guard_test.rb` and similar files. Runner, `LefthookBinary` and CI stay as on `main`.

## Constraints

- No new gems or packages, no system tool changes (playbook rules 8 and 11).
- CI config stays as on `main` (rule 13).
- Tests must pass on macOS and on Linux CI. `LefthookBinary` must keep working where only a `lefthook` on `PATH` exists.
- Never skip a test or delete a failing one to make a suite pass (rule 14). A test may be deleted only when another test already covers the same behaviour; each deletion is listed in the change folder with the test that covers it.
- Hook script changes must not change what a hook does on a real commit. The hook tests prove it.
- Approved permissions: none.

## In scope

- Tests stop copying the hook scripts per test; they copy once per process (`HookScripts.directory`).
- Tests in `branch_guard_test.rb` and similar files that repeat the same setup and commit are merged. Every assertion stays, and a step stays a separate test when no mutation can fail it.
- Tests that duplicate the coverage of another test are deleted, for example a `master` twin of a `main` test with no extra behaviour.
- A before and after timing of the full suite on the new base, recorded in the change folder.

## Out of scope

- The runner, `LefthookBinary` and CI: PR #229 covers them (see the amendment).
- Fixing the three failing files: `test/guard_parity_test.rb`, `test/mobile_tooling_test.rb`, `git/.config/git/worktree-tools/test/conductor_scripts_test.rb`. They are a separate change (playbook rule 25).
- Changing machine settings for Microsoft Defender or the VM. The final report lists them as recommendations: exclude `$TMPDIR` and `~/Developer` from real-time scanning, and stop the idle VM.
- Lowering coverage: no behaviour loses its test.

## Acceptance criteria

- On the same base, `bin/test` finishes the full suite in less time than `origin/main` does, with every file that passes on `main` still passing.
- A merged test still fails when any of its original behaviours breaks.
- Each deleted test is listed with the test that covers the same behaviour.
- A step with no mutation that can fail it stays a separate test.
- Hook scripts and `.github/workflows/` are unchanged.

## Decisions

- Merge tests first, and delete a test only when another covers the same behaviour — Etienne is open to deleting some tests.
- Hook script changes are in scope when they help — Etienne's call.
- Defender and VM load stay recommendations, not changes — they are machine settings, not repo files.
- Deliver autonomously, without Codex review — Etienne chose it; the Claude reviewer agent reviews the diff.
- Keep main's runner, `LefthookBinary` and CI, and keep this change's hook-test work — Etienne's choice after PR #229 merged (2026-10-21).
- No permissions approved — CI edit and the like become a stop-and-ask.

## Open questions

None.
