# Spec: Review report test ignores the machine's global git hooks

From `intent.md` (2026-10-02). Status: accepted.

## Flagged concerns

None. `no-push-to-main` stays untouched, so the playbook's branch-protection rule (rule 7) holds for real repositories.

## Requirements

1. `test/review_report_check_test.rb` passes on a machine whose global git config sets `core.hooksPath` to the dotfiles lefthook hooks.
2. Every git command the test runs, including the script under test, ignores the global and system git config.
3. Other tests that build temporary repositories and run `git commit` without isolation get the same protection.
4. The test keeps its commit on `main` and keeps its name. No test is skipped or deleted.
5. `no-push-to-main` and the lefthook config do not change.

## Design decisions

- Isolate through the environment, not through `-c core.hooksPath=/dev/null`. Set `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_SYSTEM=/dev/null`. The lefthook tests already use this pair, so the repository has one idiom. It also covers identity, signing and any future global setting, not only hooks.
- Share the pair in one small helper, `test/git_isolation.rb`, that exposes the env hash. Tests `require_relative` it. One definition replaces copies in each file.
- Pass the env to both the `git` helper and `run_script`. The script under test runs git as well, and a global setting must not change its result.
- The existing `-c user.email` and `-c user.name` flags stay, so the isolated repository still has an identity.
- Scope of step 3: only test files that run `git commit` or `git init` in a temporary repository with no isolation today (`review_report_check`, `change_folder`, `test_guard`, `change_scope`, `consent_guard`). Files that already isolate (`lefthook_*`, `worktree_*`, `herdr_worker_scripts`) stay as they are. The plan confirms the exact list by grep and checks each file still passes, because dropping global identity can break a test that relied on it.

## Integration points

- `test/review_report_check_test.rb`: `git` and `run_script` helpers.
- The other test files named above: their git helpers.
- New `test/git_isolation.rb`.
- `.github/workflows/dotfiles-tests.yml`: read only. CI has no global hooks, so the change must stay green there.
- `git/.config/git/worktree-tools/review-report-fresh`: not modified.

## Acceptance criteria

- With `core.hooksPath` set globally to the lefthook hooks, `ruby test/review_report_check_test.rb` reports 0 errors and 0 failures.
- A commit on `main` inside the test's temporary repository succeeds even when the global `no-push-to-main` hook is installed.
- With a global `user.name` and `user.email` unset, each updated test file still passes.
- A global git config that sets a hooks path does not change the result of the review-report script run by the test.
- `no-push-to-main` still blocks a commit on `main` in a real repository: `git diff main` shows no change to the lefthook config.
- The full suite reports 0 failures and 0 errors on this machine.

---
Domain skills applied: rails-testing.
