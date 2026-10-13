# Review: test-repos-ignore-global-git-setup

## Round 1 — 2026-10-13T13:11Z — 77e3bf1f

Compliance:

- AC1 (failing global signing) → delivered by main: `test/isolated_git_test.rb` `test_a_commit_ignores_global_signing_with_no_agent` (green) plus `test_every_test_file_requires_the_helper` (red, see the Important finding).
- AC2 (failing global hooks) → delivered by main: `test/isolated_git_test.rb` `test_a_commit_ignores_the_global_no_push_to_main_hook`, `test_review_report_check_passes_under_the_global_no_push_to_main_hook` (green) plus the same red structural test.
- AC3 (`LEFTHOOK_BIN` set) → `test/lefthook_local_hooks_test.rb` `test_pre_commit_reaches_the_logging_stub_when_lefthook_bin_is_set`, `test_pre_push_reaches_the_logging_stub_when_lefthook_bin_is_set`. Verified: at d8308e8c (no fix) exactly these two error with `Errno::ENOENT … commands.log`, `LEFTHOOK_BIN` unset in the caller; at HEAD the file gives 13 runs, 0 failures, 0 errors with `LEFTHOOK_BIN` unset, set to the real binary, and set to `/bin/false`. `ENV["LEFTHOOK_BIN"]` after the two tests is restored both when it was absent and when it held a value.
- AC4 (CI green) → missing until the Important finding is closed.
- Re-scoped Proof: both named tests exist. No existing test is weakened, skipped or deleted. RuboCop on the changed file: no offenses.

- [ ] Important: The re-scope rests on main's `test_every_test_file_requires_the_helper`, and that test is red on origin/main and on this branch: six test files added after PR #198 do not require `isolated_git` (`herdr_quieter_tones`, `lefthook_rubocop_git_gem`, `neovim_avante_dependencies`, `pull_request_flow`, `rbs_inline_tooling`, `review_push_hook`). CI runs every `test/*_test.rb`, so AC4 cannot hold for this pull request. The three that run git appear to isolate themselves (own `GIT_CONFIG_GLOBAL`/`HOME`, or a read-only `git grep`), so AC1/AC2 behaviour likely holds, but its proof is red. Playbook rule 25: fix it in its own worktree and PR, then rebase this branch on it. — `test/isolated_git_test.rb:84` →
- [ ] Nit: Without the fix, the new tests go red as an `Errno::ENOENT` error from `File.readlines(@log_file)`, not as the assertion failure "Expected pre-commit to invoke lefthook"; the helper's `refute` message never shows. Pre-existing helper, but the new regression tests depend on its red message. — `test/lefthook_local_hooks_test.rb:159` →
