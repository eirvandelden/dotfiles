# Intent: Share git fixtures across the tests of a file

Author: Etienne van Delden. Status: accepted (2026-10-29). Type: refactor. Delivery: autonomous. Codex review: no.

## Problem

The test suite builds a new temporary git repository for almost every test, 95 `Dir.mktmpdir` call sites in 57 files. Microsoft Defender scans every file those repositories write, and the Mac slows down for the whole machine during a test run. IT refuses to exclude `~/Developer` or `$TMPDIR`, so only the tests can change. A killed run also leaves its temporary directories behind, because `bin/test` sends INT and then KILL after 5 seconds, and `teardown` does not run on KILL. 2,834 such directories had piled up by 2026-10-29.

## Proposed outcome

A test file builds its git repository once and resets it to the committed state between tests. A bare origin that tests only push to is shared the same way. All temporary directories of one run sit under one root that `bin/test` removes at the end. A killed run leaves one directory, not hundreds.

## Affected users and systems

- Etienne's Mac, and every machine that runs `bin/test`.
- `test/delivery_harness.rb` and the 7 test files that include it.
- `test/isolated_git.rb` and the 57 test files that call `Dir.mktmpdir`.
- `bin/test` and `test/test_runner_test.rb`.

## Constraints

- No Defender exclusions or settings: IT owns them.
- The assertions of the tests stay as they are. Only how a test builds its fixture changes.
- Each test stays independent of the others and of their order.
- A test that changes state a reset cannot restore (hooks, `core.hooksPath`, config, stash, reflog, worktrees) keeps its own repository.
- Whether a reset or a copy of a template repository (`cp -R`) is cheaper is measured in the plan stage and decided there.
- A new shared fixture helper needs unit tests of its public methods (playbook rule 3).
- No permissions beyond the working tree: no gems, no system tools, no `sudo` (playbook rules 8, 9, 11, 12, 13).

## In scope

- A shared git fixture: build once per test file, reset between tests, shared bare origin where a test only pushes.
- One run root `dotfiles-test*` under `$TMPDIR` that `bin/test` removes at the end of the run, including after INT.
- Moving `test/delivery_harness.rb` and `test/herdr_worker_scripts_test.rb` first, then every other file that calls `Dir.mktmpdir` and can share.
- Baseline and after counts of `git init` calls.

## Out of scope

- Defender exclusions or settings.
- Changing what the tests assert.
- The Rancher Desktop VM.
- Measuring Defender path calls with `sudo fs_usage`. The `git init` count stands in for it.

## Acceptance criteria

- `bin/test` ends green: 0 failures, 0 errors, 0 skips.
- `GIT_TRACE=1 bin/test test/deliver_test.rb` shows fewer than 60 lines `trace: built-in: git init`. The baseline on 2026-10-29 is 60 for 30 tests.
- A test file that shares its repository runs two tests in either order with the same result.
- After INT then KILL on `bin/test`, `$TMPDIR` holds at most one new `dotfiles-test*` directory.
- After a normal run, `bin/test` removed its `dotfiles-test*` directory.
- A test that needs its own repository (changes hooks, config, stash, reflog or worktrees) still gets one, and passes.
- The shared fixture helper has unit tests of its public methods, including the reset between tests.

## Flagged concerns

- The handoff said to move other files only when the measure shows a gain. Etienne chose to move all 57 now. Chosen side: move all files that can share, which is a larger diff and a higher risk of hidden state leaks between tests; each moved file must pass alone and in the full run.

## Decisions

- Autonomous delivery — chosen by Etienne when offered the two modes, no reason given.
- Move all 57 files now, not only the two heaviest — Etienne's choice over the handoff's measure-first order, no reason given.
- No Codex review — Etienne declined the second reviewer, no reason given.
- Measure with the `git init` count, not `sudo fs_usage` — Etienne's choice; it needs no `sudo`, no reason given.

## Open questions

None.
