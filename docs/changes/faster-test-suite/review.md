# Review

## Round 1 — 2026-10-19T13:14:05Z — 030961cc (codex)

- [ ] Important: `bin/test -j 0` (or a negative count) starts no file, prints `1 files, 0 failed` and exits 0, so an invalid concurrency setting silently skips the suite; reject counts below one — `bin/test:79` → fixed (Refuse a bin/test job count below one)
- [ ] Important: after a missed deadline, `teardown` calls `stop_hanging_stubs` and then removes `@enclosing` with the release file at once, so a stub can miss the release and keep running (and spawning `sleep`) for up to 600 s; wait until the stubs have exited before the directory goes — `test/worktree_sweep_test.rb:404` → fixed (End worktree_sweep_test's hanging stubs once their folder is gone)

## Round 2 — 2026-10-19T13:16:56Z — f3a35dbc (codex)

- [ ] Important: on Ctrl-C the runner sends KILL to each file's process group at once; the files sit in their own groups, so they never see the interrupt, their `ensure` cleanup is skipped and processes they started in other groups (e.g. `worktree_create_test.rb#test_ctrl_c_ends_it_during_a_fetch`) are orphaned; forward INT first and kill only after a grace period — `bin/test:37` → fixed (Let interrupted test files clean up before bin/test kills them)

## Round 3 — 2026-10-19T13:28:47Z — cbd8c546 (codex)

- [ ] Important: when the reader of the runner's output goes away (`bin/test | head`), the runner dies on the broken pipe without stopping its jobs, and test files in their own process groups keep running; every way out of the runner must stop and reap the running files — `bin/test:26` → fixed (Stop running test files on every way out of bin/test)

## Round 4 — 2026-10-19T13:40:19Z — 5420a0df (codex)

No findings.

## Round 5 — 2026-10-19T13:56:28Z — 5420a0df (claude)

- [ ] Nit: `locate` evaluates `platform: platform_directory` on every call, so on a CPU outside `CPUS` (e.g. `riscv64`) it raises `KeyError` even when `LEFTHOOK_BIN` is set or `PATH` has a native binary; the plan says a platform without a native binary returns the wrapper as today — compute the platform only when a wrapper needs resolving, or fall back on an unknown CPU — `test/lefthook_binary.rb:17` → fixed (Keep the lefthook wrapper on a host without a lefthook build)
- [ ] Nit: file arguments are resolved from the repository root (`chdir: root`), not the caller's directory, so `cd test && ../bin/test lefthook_binary_test.rb` fails with `LoadError` and reports the file as FAILED; expand the arguments against the caller's directory before the spawn — `bin/test:113` → fixed (Read bin/test file arguments from the caller's directory)

## Round 6 — 2026-10-19T13:59:31Z — b0460cd7 (codex)

- [ ] Important: during shutdown `ended?` reaps a file that exited, and the loop after the grace period still sends KILL to its group id; once reaped, that id can belong to an unrelated group — signal only groups whose leader is still unreaped — `bin/test:49` → fixed (Signal only unreaped test files when bin/test stops)
- [ ] Nit: `test_hanging_stubs_end_once_their_folder_is_removed` hands stubs that `exited_within` already reaped to `reap`, which sends KILL before it sees `ECHILD`, so a reused pid can be killed — reap only the stubs still running — `test/worktree_sweep_test.rb:314` → fixed (Reap only the hanging stubs still running)
- [ ] Nit: the broken-pipe test relies on the default job count; on a one-core host only the slow file starts and the test times out — pass `-j 2` — `test/test_runner_test.rb:88` → fixed (Run the broken-pipe runner test with two jobs)

## Round 7 — 2026-10-19T14:47:16Z — 0c49bad6 (codex)

- [ ] Important: when a file exits on INT but a process in its group ignores INT, `ended?` reaps the file and drops the job, so the KILL after the grace period never reaches that process; group cleanup must not depend on the leader alone — `bin/test:49` → fixed (Kill what is left of each test file's group on a bin/test stop)

## Round 8 — 2026-10-19T15:03:29Z — d27f31b8 (codex)

- [ ] Important: a second TERM during the grace period raises Interrupt inside `stop_all` and skips the KILL and reap, so a file that ignores INT keeps running; ignore TERM during the shutdown as INT already is — `bin/test:50` → fixed (Ignore a second TERM while bin/test shuts down)
- [ ] Important: when `ps` exits non-zero its empty output reads as "no live group", so the KILL comes at once and the files get no time to clean up; treat a failed `ps` like a missing one — `bin/test:61` → fixed (Keep bin/test's grace period when ps fails)

## Round 9 — 2026-10-19T15:14:04Z — 25f19894 (codex)

- [ ] Nit: when a runner test is interrupted or times out, its cleanup sends KILL to the nested `bin/test` at once, so that runner never stops its fixture files, which run on in their own groups; let the nested runner shut down first — `test/test_runner_test.rb:279` → fixed (Let a runner test's nested bin/test shut down before it is killed)

## Round 10 — 2026-10-20T07:59:33Z — 6d5bf23c (codex)

No findings.

## Round 11 — 2026-10-20T21:21:19Z — 6d5bf23c (claude)

- [ ] Important: a full `bin/test` run at 6d5bf23c failed: `test_gives_up_on_a_gh_call_that_hangs` and `test_gives_up_on_a_fetch_that_hangs` missed the fixed 20 s `DEADLINE` while 12 files ran at once (other sessions' tests also loaded the Mac, load average 28–39); the same file passed alone under the same load in 157 s, so parallel runs are not yet as reliable as one-at-a-time runs, which the intent requires — `test/worktree_sweep_test.rb:13` → fixed (Give the worktree-sweep hang guard room for a loaded Mac)
- [ ] Nit: `test_hanging_stubs_end_once_their_folder_is_removed` removes the folder after a fixed `sleep 0.5`; under load the `gh` stub has not loaded its script by then and dies with `bin/gh: No such file or directory (Errno::ENOENT)` (seen in the full run and in 1 of 3 runs alone), so the test passes without the stub's folder check ever running; wait for a sign that each stub is in its loop — `test/worktree_sweep_test.rb:195` → fixed (Remove the stubs' folder only once both stubs wait)
- [ ] Nit: an INT or TERM that arrives between `Process.wait2` and `@running.delete(job)` leaves a reaped job in `@running`, so `stop_all` signals a group id that may be reused (the case round 6 closed); one that arrives between `Process.spawn` and `@running <<` leaves a started file untracked and running after the runner exits; defer the interrupt across both spots — `bin/test:97` → fixed (Let INT and TERM only flag bin/test's stop)

Compliance:

- Under 8 minutes on Etienne's Mac → check only; this round's run took 15:16 under load from other sessions, not a clean measure. Discovery → `test_without_arguments_it_runs_every_test_file_under_its_root`. 74 headers for 74 `test/*_test.rb` files.
- Failing file exits non-zero and is named; green run exits zero → `test_a_failing_file_makes_the_runner_exit_non_zero_and_names_it`, `test_a_run_of_passing_files_exits_zero`.
- Three parallel runs pass → check only; this round's one run failed (Important above).
- Hanging-fetch cleanup spares outside processes → `test_stopping_hanging_stubs_spares_processes_outside_them`, `test_gives_up_on_a_fetch_that_hangs`.
- Native lefthook over a RubyGems wrapper → `test_a_rubygems_wrapper_on_path_resolves_to_its_native_binary` and the five other planned `lefthook_binary_test.rb` tests, all present.
- isolated_git guarantee without a whole test file → `test_a_test_file_with_the_helper_commits_under_the_global_no_push_to_main_hook`, `test_a_test_file_without_the_helper_fails_under_the_global_no_push_to_main_hook`.
- Stub call without RubyGems → `test_a_stub_call_starts_without_rubygems`.
- CI runs `bin/test` and stays green → step reads `run: bin/test`; green run missing: the workflow runs only on `pull_request` and pushes to `main`, so no run exists for the branch until `deliver` opens the PR.
- `ruby -Itest` runs one file alone → `test_each_file_runs_with_the_standalone_command`.
- Every test named in `plan.md`'s Proof exists. The removed `test_review_report_check_passes_under_the_global_no_push_to_main_hook` is the planned replacement; no other test is weakened, skipped or deleted. RuboCop and yamllint are clean on every touched file.

## Round 12 — 2026-10-21T12:34:56Z — 23e4d552 (codex)

- [ ] Important: on a machine with many CPUs the default `-j` starts one file per CPU; under `bin/test -j 4`, `test/codex_unlocked_shim_test.rb` missed its 10 second timeout while the file passed alone, so the default can make the suite fail at random; cap the concurrency or keep timeout-sensitive tests apart — `bin/test:136`. Closure note: a cap would not help, since the failure came at `-j 4`; the 10 seconds guard against a shim that runs itself forever, so 60 seconds still catches that; the 20 second guards in `test/test_runner_test.rb` got the same room (Give the runner tests' hang guards room for a loaded Mac) → fixed (Give the codex shim's hang guard room for a loaded Mac)

## Round 13 — 2026-10-21T12:39:04Z — 4e38c60f (codex)

No findings.

## Round 14 — 2026-10-21T12:49:55Z — 4e38c60f (claude)

No findings.

Fixes from rounds 11 and 12 hold:

- `bin/test`: the INT and TERM traps only set `@stopping`; `next_exit` polls `Process.wait2(-1, WNOHANG)`, so no exception can fall between `Process.spawn` and `@running <<`, or between the reap and `@running.delete`. `stop_all` still ignores INT and TERM, signals only unreaped leaders, and keeps the grace period when `ps` fails.
- `test/worktree_sweep_test.rb`: both stubs write a `.ssh-ready` or `.gh-ready` marker before their loop, and the folder-removal test waits for both markers. No `bin/gh: No such file or directory` appeared in this round's run.
- The hang guards are 60 s in `test/worktree_sweep_test.rb` (`DEADLINE`), `test/codex_unlocked_shim_test.rb` (`run_with_deadline`) and `test/test_runner_test.rb` (`HANG_GUARD`). Each is still far below the 600 s hang or the self-running shim it guards against.

Compliance:

- Under 8 minutes on Etienne's Mac → check: `time bin/test` took 5:30 and exited 0, with a load average of 15–26 from other sessions. The 84 `=== test/... ===` headers equal `ls test/*_test.rb`. Discovery → `test_without_arguments_it_runs_every_test_file_under_its_root`.
- A failing file exits non-zero and is named; a green run exits zero → `test_a_failing_file_makes_the_runner_exit_non_zero_and_names_it`, `test_a_run_of_passing_files_exits_zero`.
- Three parallel runs pass → check only: this round made one full run, and it was green. No orphan stub processes were left after it.
- The hanging-fetch cleanup spares outside processes → `test_stopping_hanging_stubs_spares_processes_outside_them`, `test_gives_up_on_a_fetch_that_hangs`.
- Native lefthook over a RubyGems wrapper → `test_a_rubygems_wrapper_on_path_resolves_to_its_native_binary`, plus the five other planned tests and two platform tests in `test/lefthook_binary_test.rb`.
- isolated_git guarantee without a whole test file → `test_a_test_file_with_the_helper_commits_under_the_global_no_push_to_main_hook`, `test_a_test_file_without_the_helper_fails_under_the_global_no_push_to_main_hook`.
- A stub call starts without RubyGems → `test_a_stub_call_starts_without_rubygems`.
- CI runs `bin/test` and stays green → the step reads `run: bin/test`. A green run is still missing: the workflow runs only for pull requests and pushes to `main`.
- `ruby -Itest` runs one file on its own → `test_each_file_runs_with_the_standalone_command`. Each changed test file also passes on its own with `ruby -Itest`.
- Every test named in `plan.md`'s Proof exists. Only the planned `test_review_report_check_passes_under_the_global_no_push_to_main_hook` was removed. No test is skipped. RuboCop is clean on `bin/test` and every touched Ruby file, and yamllint is clean on the workflow.
