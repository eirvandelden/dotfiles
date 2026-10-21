# Intent: Speed up the dotfiles test suite

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

The `test/*_test.rb` suite takes about 25 minutes when run file by file. Agents that run it wait too long. Ten files take 62% of that time. Each test spends its time waiting on processes: every commit in a temporary repository fires three or four git hooks, and each hook starts lefthook. The test helper `LefthookBinary.locate` picks the RubyGems binstub, which boots Ruby on every call. Each test also copies the seven hook scripts into a new temporary directory.

## Proposed outcome

The full suite runs in a fraction of today's time with the same behaviour covered. One command runs the suite in parallel. Tests that repeat the same setup and commit run as one test.

## Affected users and systems

Etienne and every agent that runs the dotfiles tests. Files: `test/lefthook_binary.rb`, the tests that copy hooks, `test/branch_guard_test.rb` and similar files, and a new parallel runner script. CI stays unchanged.

## Constraints

- No new gems or packages, no system tool changes (playbook rules 8 and 11).
- CI config is untouched without approval (rule 13): `.github/workflows/dotfiles-tests.yml` stays serial, and using the runner there is a stop-and-ask.
- Tests must pass on macOS and on Linux CI. `LefthookBinary` must keep working where only a `lefthook` on `PATH` exists.
- Never skip a test or delete a failing one to make a suite pass (rule 14). A test may be deleted only when another test already covers the same behaviour; each deletion is listed in the change folder with the test that covers it.
- Hook script changes must not change what a hook does on a real commit. The hook tests prove it.
- Approved permissions: none.

## In scope

- `LefthookBinary.locate` finds the native lefthook binary in the user gem directory and prefers it over a binstub found with `which`.
- Tests stop copying the hook scripts per test; they copy once per process or use them in place.
- A runner script runs the `test/*_test.rb` files in parallel, bounded by the CPU count, and fails if any file fails.
- Tests in `branch_guard_test.rb` and similar files that repeat the same setup and commit are merged. Every assertion stays.
- Tests that duplicate the coverage of another test are deleted, for example a `master` twin of a `main` test with no extra behaviour.
- The hook scripts in `git/.config/git/hooks/` may change where that cuts the start-up cost of a hook, for example the probe chain that looks for lefthook.
- A before and after timing of the full suite, recorded in the change folder.

## Out of scope

- Editing `.github/workflows/` (CI stays serial).
- Fixing the three failing files: `test/guard_parity_test.rb`, `test/mobile_tooling_test.rb`, `git/.config/git/worktree-tools/test/conductor_scripts_test.rb`. They are a separate change (playbook rule 25).
- Changing machine settings for Microsoft Defender or the VM. The final report lists them as recommendations: exclude `$TMPDIR` and `~/Developer` from real-time scanning, and stop the idle VM.
- Lowering coverage: no behaviour loses its test.

## Acceptance criteria

- The parallel runner runs the full suite and finishes in under 5 minutes on this machine, down from about 25.
- The runner exits non-zero when any test file fails, and prints the failing file names.
- With a native lefthook in the gem directory, `LefthookBinary.locate` returns it and not the binstub.
- With no native binary and only a `lefthook` on `PATH`, `LefthookBinary.locate` returns that one.
- A merged test still fails when any of its original behaviours breaks.
- Each deleted test is listed with the test that covers the same behaviour.
- A hook still refuses a commit on `main` and runs its lefthook commands after the hook change.
- Every file that passes today still passes, and the three failing files fail the same way.

## Decisions

- Merge tests first, and delete a test only when another covers the same behaviour — Etienne is open to deleting some tests.
- Hook script changes are in scope when they help — Etienne's call.
- Defender and VM load stay recommendations, not changes — they are machine settings, not repo files.
- Deliver autonomously, without Codex review — Etienne chose it; the Claude reviewer agent reviews the diff.
- No permissions approved — CI edit and the like become a stop-and-ask.

## Open questions

None.
