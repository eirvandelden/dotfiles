# Review: 231-speed-up-the-slowest-tests-git-maintenance-init-template-gh-and-herdr-stubs

## Round 1 — 2026-10-26T13:35Z — 778f49dd

- [ ] Important: `test_the_quiet_settings_win_over_a_childs_own_global_config` does not test a child's own global config. The child sets `GIT_CONFIG_GLOBAL=own-config` and then requires `isolated_git`, whose `ENV.update` resets `GIT_CONFIG_GLOBAL` to `/dev/null`. The `git config` calls in `SETTINGS_SCRIPT` never read `own-config`, so the test repeats `test_the_helper_turns_off_automatic_maintenance_and_gc`. Probe: the same child with `user.name` in its own config prints `GIT_CONFIG_GLOBAL=/dev/null` and an empty `user.name`. The plan's invariant "including a child given its own `GIT_CONFIG_GLOBAL`" has no proof. To prove it, the `git` process (not the Ruby child that requires the helper) must get `GIT_CONFIG_GLOBAL=own-config`, for example `IO.popen({ "GIT_CONFIG_GLOBAL" => path }, ...)` inside the script, plus a check that `own-config` is read at all — `test/isolated_git_test.rb:120` → fixed (Give git itself its own global config in the quiet settings test)
- [ ] Nit: `run_child` mutates its rest parameter with `command.shift` (playbook §2: never mutate a method's parameters). A leading environment hash can be split without mutation, for example a separate keyword or `env, *rest` destructuring into new locals — `test/isolated_git_test.rb:250` → fixed (Split run_child's environment without shifting its arguments)
- [ ] Nit: No test covers the `Minitest.after_run` branch of `IsolatedGit.template`: that the template outlives the tests and is removed afterwards. `test_the_helper_loads_on_its_own` covers only the `at_exit` branch. The suite proves the "outlives" half indirectly (seven files write `.git/info/exclude`); nothing proves removal. A manual check after this review's runs found no `git-template*` directory left in `Dir.tmpdir` — `test/isolated_git.rb:38` → fixed (Test that a test file keeps its git template until its tests end)
- [ ] Nit: `plan.md` still describes the dropped shell stub as planned work: `### Signatures` (the `delivery_harness.rb` block and the shell-stub steps), `## Files that change` and `## Proof`. Proof names 13 `delivery_harness_test.rb` tests that do not exist in the branch (`test_a_call_is_logged_as_one_line_of_its_arguments`, `test_the_body_file_and_title_are_captured_at_call_time`, ...), and says `test_a_stub_call_starts_without_rubygems` asserts an absent probe file, which it does not. `## Departures` explains the drop in one paragraph; mark the stale lines as dropped there or inline, so a reader of Proof does not count them as missing — `docs/changes/231-speed-up-the-slowest-tests-git-maintenance-init-template-gh-and-herdr-stubs/plan.md:234` → fixed (docs: mark the dropped shell stub in the plan for 231)

Compliance (acceptance criteria from `intent.md`):

- Full `bin/test` median after is lower than on `main`, both tables → `timings.md` "Final" (161 s against 178 s, interleaved pairs); the pull request copy is `deliver`'s step.
- Every file that passes on `main` still passes, same tests and assertions → `timings.md` "Final" (86 files equal, `isolated_git_test.rb` 8→15 runs); coordinator reports `87 files, 0 failed` after the rebase.
- A speed-up stays only when its median drops by more than the spread → `timings.md` speed-ups 1 (kept, 11 s > 9 s), 2 and 3 (dropped, not committed).
- A test that reads a stub's recorded calls sees the same calls after the stub becomes shell → not applicable: the shell stub was dropped and `test/delivery_harness.rb` is unchanged.
- The change folder names where each slow file spends its time → `profile.md`, one section per file.

Proof tests for `test/isolated_git.rb`: all seven named tests exist and pass (15 runs, 31 assertions). `test_the_quiet_settings_win_over_a_childs_own_global_config` exists but proves less than its name (Important above). No existing test was weakened, skipped or deleted. `run_child` gained `GIT_CONFIG_COUNT => nil` and `GIT_TEMPLATE_DIR => nil`, which keeps the existing tests' children clean.

Design: both new public methods are signed in `### Signatures` and carry inline RBS. No Law of Demeter chain, no query loop. No glossary `Avoid:` word (`shim`, `binary`) in the diff.

Checks run: `rubocop test/isolated_git.rb test/isolated_git_test.rb` clean; `ruby -Itest test/isolated_git_test.rb` green; `ruby -Itest test/worktree_sweep_on_pull_test.rb -v` green alone at load average 35–99 (10 runs, 360 s, single tests 16–61 s).

`worktree_sweep_on_pull_test.rb` failure under load: load only, not this change. Nothing in `git/.config/git/worktree-tools/` or `lefthook.yml` reads `GIT_CONFIG_*`, `GIT_TEMPLATE_DIR`, `maintenance` or `gc`. The test sets `core.hooksPath`, so an empty `.git/hooks/` changes nothing; the template keeps `info/`, which `origin_and_clone` writes `info/exclude` into. `maintenance.auto=false` and `gc.auto=0` only remove detached background children after the pull, which lowers load and lock contention. The 20 s `DEADLINE` waits cover a detached sweep that boots Ruby `gh`/`herdr` stubs and the native lefthook; at load 49 on 12 cores that is the likely timeout.

## Round 2 — 2026-10-26T14:09Z — c62f4977

Nothing found.

Round 1 closures, checked against the code:

- Important (own global config): `OWN_CONFIG_SCRIPT` now gives `GIT_CONFIG_GLOBAL` to the `git` process itself, after the helper loaded. `user.name` reads back as `global\tOwn`, so git reads the file; the quiet settings read back at `command` scope over `maintenance.auto=true` and `gc.auto=6700` in it. Holds — `test/isolated_git_test.rb:34`, `:142`.
- Nit (`run_child` mutation): `overrides, *arguments = ...` destructures into new locals; no `shift`. Holds — `test/isolated_git_test.rb:287`.
- Nit (after_run branch untested): `test_a_test_file_keeps_the_template_until_its_tests_end` runs a Minitest file that asserts the template exists during its test, then checks the directory is gone. The coordinator's mutations (at_exit instead of after_run; no cleanup) both turn it red. Holds — `test/isolated_git_test.rb:198`.
- Nit (stale plan): Signatures, Files that change, Order of work step 6, and every stub line in Proof now say "Dropped (see Departures)". Holds. The Design diagrams, Complexity and Invariants still describe the stub, but `## Departures` and the Signatures note cover them; not raised again.

Compliance (acceptance criteria from `intent.md`): unchanged from round 1 — `timings.md` Final and gate rows, `profile.md` per file, the stub criterion not applicable. Proof tests for `test/isolated_git.rb`: all nine named tests exist and pass. No existing test was weakened, skipped or deleted; `write_fixture_test` only moved its directory setup into `directory_with_helper`.

Design: `IsolatedGit.environment` and `IsolatedGit.template` are signed in `### Signatures` and carry inline RBS; the new test helpers are private. No Law of Demeter chain, no query loop, no glossary `Avoid:` word (`shim`, `binary`) in the diff. Every test file requires `minitest/autorun` before `isolated_git`, so the `defined?(Minitest)` branch picks `after_run` everywhere.

Checks run: `ruby -Itest test/isolated_git_test.rb` 16 runs, 34 assertions, 0 failures; `rubocop test/isolated_git.rb test/isolated_git_test.rb` clean; full `bin/test` 87 files, 0 failed (load average 38–47); no `git-template*` directory left in `Dir.tmpdir` afterwards.
