# Intent: Speed up the slowest tests: git maintenance, init template, gh and herdr stubs

Author: Etienne van Delden. Status: accepted (2026-10-25). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

A full `bin/test` run takes about 280 s on a loaded 12-core Mac. Four files set the wall time: `herdr_worker_scripts_test.rb` (241 s), `deliver_test.rb` (233 s), `consent_guard_test.rb` (216 s) and `worktree_create_test.rb` (186 s). Agents and Etienne wait on them. Three suspected causes: git runs `git maintenance run --auto --detach` after commits in test repositories, `git init` copies the sample hook files on every init, and the shared `gh`/`herdr` stub in `test/delivery_harness.rb` boots Ruby on every call. The cause in `consent_guard_test.rb` and `worktree_create_test.rb` is unknown.

## Proposed outcome

`bin/test` finishes in less wall time, with every test and assertion kept. Each speed-up stays only when its timing proves it.

## Affected users and systems

Etienne and every agent that runs the dotfiles tests. Files: `test/isolated_git.rb` and the test files that run `git init`, `test/delivery_harness.rb` and its users (`deliver`, `ship`, `restore`, `commit_plan`, `commit_review`, `open_pr_dash` and the harness tests), and the four slow files above. The scripts under test do not change.

## Constraints

- No new gems or packages, no system tool changes (playbook rules 8 and 11).
- CI config stays unchanged (rule 13).
- Tests pass on macOS and on Linux CI.
- No test is skipped or deleted, and no assertion is lost (rule 14).
- Approved permissions: none.

## In scope

- Turn off git maintenance and automatic gc for git in tests (`maintenance.auto=false`, `gc.auto=0`).
- Use an empty template for `git init` in tests, so git copies no sample hooks.
- Replace the Ruby `gh`/`herdr` stub in `test/delivery_harness.rb` with a shell stub that records the same calls and gives the same answers.
- Profile `herdr_worker_scripts_test.rb`, `deliver_test.rb`, `consent_guard_test.rb` and `worktree_create_test.rb` before changing them.
- A small fix for another cause that profiling finds, when it stays in test code and saves measurable time.
- Before and after timings, per speed-up and for the full suite, recorded in the change folder and the pull request.

## Out of scope

- Building a repository once per file and copying it.
- Splitting large test files across workers.
- A changed-files mode for `bin/test`.
- Changes to the scripts under test, the hook scripts or `.github/workflows/`.
- A fix for another cause that needs changes outside test code: the pull request records it as a follow-up.

## Acceptance criteria

- On the same machine and base, the median of three full `bin/test` runs after the change is lower than the median of three runs on `main`. Both tables are in the pull request.
- Every file that passes on `main` still passes, with the same tests and assertions.
- A speed-up stays only when the median of three runs of its affected files drops by more than the run-to-run spread. A speed-up that does not is dropped, and the pull request says so.
- A test that reads a stub's recorded calls, for example the captured pull request body and title, sees the same calls after the stub becomes shell.
- The change folder names where each of the four slow files spends its time.

## Decisions

- Keep the three speed-ups as one change — they share one measurement setup and one before/after table; each is still kept or dropped on its own timing.
- Keep a speed-up when the median of 3 runs drops by more than the run-to-run spread — the machine is loaded, so one run is noise.
- Fix another cause that profiling finds when the fix is small, stays in test code and saves measurable time — Etienne's choice over report-only.
- Deliver autonomously, without Codex review — Etienne's choice; the Claude reviewer agent reviews the diff.
- No permissions approved — anything that needs one becomes a stop-and-ask.

## Open questions

None.
