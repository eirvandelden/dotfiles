# Plan: Branch guard messages name deliver

From `intent.md` (2026-10-16). Status: accepted.

## Design decisions

- The four refusal texts are the exact strings in `intent.md`. In the remote-ref message the branch name stays the shell expansion `${remote_ref#refs/heads/}`, so the line reads `echo "Pushing to ${remote_ref#refs/heads/} is not allowed. Push a feature branch; deliver opens the PR."`.
- `lefthook.yml` already holds the new text for pre-commit (line 77) and pre-push current branch (line 281). It needs only the commit-msg line (146) and the pre-push remote-ref line (287). `lefthook-branch-guard.yml` needs all four (lines 16, 33, 45, 51).
- `test_lefthook_messages_send_pull_requests_through_deliver` loops over both files. For each file it greps the lines that match `/is not allowed\./`, asserts four of them, and asserts each one names "deliver opens the PR" and none matches `/open a PR/`. The assertion message names the file, so a failure says which copy drifted. The test name stays the same, as `intent.md` names it.
- The behavioural acceptance criteria 1–4 need proof of the full text, not only the "is not allowed" prefix. `test/branch_guard_test.rb` already runs real commits and pushes through lefthook against both the extending guard file and the fallback `lefthook.yml`. Its `REFUSAL` constant and the regex in `assert_push_refused` widen to the full new sentences. That turns every existing refusal test into proof of the new text, with no new test cases. The guard behaviour does not change, so no test that expects a refusal or an allow flips.
- `test_the_fallback_config_duplicates_the_guard_commands_exactly` stays unchanged (constraint in `intent.md`). It goes green because the two files hold equal commands again.
- The `fail_text` lines stay unchanged (out of scope).

## Integration points

- lefthook reads `lefthook.yml` in this repository and in every repository that falls back to it through the global hooks in `git/.config/git/hooks`.
- Repositories that extend `lefthook-branch-guard.yml` from their own `lefthook-local.yml` pick up the new text on their next hook run. No stow or install step is needed: the file is read by absolute path.
- CI (`.github/workflows/dotfiles-tests.yml`) runs both test files on Ubuntu with a released lefthook binary.

## Files that change

- `test/pull_request_flow_test.rb` — `test_lefthook_messages_send_pull_requests_through_deliver` checks both files, four messages each.
- `test/branch_guard_test.rb` — `REFUSAL` and the regex in `assert_push_refused` match the full refusal sentences that name deliver.
- `lefthook-branch-guard.yml` — the four `echo` lines say "deliver opens the PR" instead of "open a PR".
- `lefthook.yml` — the commit-msg `echo` (line 146) and the pre-push remote-ref `echo` (line 287) say "deliver opens the PR".

Nothing else changes. The header comments, `fail_text` lines and guard logic stay as they are.

## Order of work

1. Change `test_lefthook_messages_send_pull_requests_through_deliver` to check both files, four messages each. Run `ruby test/pull_request_flow_test.rb -n test_lefthook_messages_send_pull_requests_through_deliver`. Watch it fail: `lefthook.yml` has two messages with "open a PR", and the guard file has four.
2. Widen `REFUSAL` in `test/branch_guard_test.rb` to `/Direct commit to (main|master) is not allowed\. Create a feature branch; deliver opens the PR\./`. Widen the regex in `assert_push_refused` to `/Pushing to (main|master) is not allowed\. Push a feature branch; deliver opens the PR\.|Direct push to (main|master) is not allowed\. Create a feature branch; deliver opens the PR\./`. Run `ruby test/branch_guard_test.rb -n /refuses/`. Expect 25 of the 26 selected tests to fail on the old text. Only `test_the_fallback_config_refuses_an_amend_that_stages_a_change_on_main` passes, because the fallback pre-commit line already holds the new text. No fallback test pushes from `main`, so the fallback pre-push current-branch line is proven only by the static test from step 1.
3. Edit the four `echo` lines in `lefthook-branch-guard.yml`.
4. Edit the commit-msg and pre-push remote-ref `echo` lines in `lefthook.yml`.
5. Run the narrow tests again: the test from step 1, `ruby test/branch_guard_test.rb -n /refuses/`, and `ruby test/branch_guard_test.rb -n test_the_fallback_config_duplicates_the_guard_commands_exactly`. All green.
6. Run both files in full: `ruby test/branch_guard_test.rb` (52 runs, over two minutes locally; give it a long timeout) and `ruby test/pull_request_flow_test.rb`. Then the rest of `test/` with `for f in test/*_test.rb; do ruby "$f" || exit 1; done`. `test/isolated_git.rb` require failures are known and out of scope (PR #210); report them, do not fix them here.
7. Lint: `yamllint lefthook.yml lefthook-branch-guard.yml` and `env -u GIT_DIR rubocop --force-exclusion test/branch_guard_test.rb test/pull_request_flow_test.rb`. This is the manual equivalent of the pre-push rubocop job, which unsets `GIT_DIR` and lints `{push_files}`.
8. Verify by hand as a human would. Use one fresh scratch repository per case, so a refused case leaves no staged state for the next one. Each repository: `git init --initial-branch=main`, a bare `origin`, `git config core.hooksPath <this worktree>/git/.config/git/hooks`, a committed stand-in `lefthook.yml` with `no_auto_install: true`, and a `lefthook-local.yml` with `extends:` pointing at this worktree's `lefthook-branch-guard.yml`. Make the setup commit with `LEFTHOOK=0`. The cases: a staged commit on `main`; `git commit --allow-empty` on `main`; `git push origin main` from `main`; `git push origin feature:main` from a `feature` branch. Record each refusal line in the report.
9. Re-read the full diff. Commit in small commits: tests first, then the YAML change. Commits go through the normal hooks on the feature branch.

## Risks

- The `REFUSAL` constant is shared by many tests. A typo in it fails tests that refuse correctly. The step 2 red run shows which tests read the new text; the step 5 green run shows they all pass.
- A future text change now needs edits in the tests too. That is the point of pinning the text; the cost is low.
- `test_a_change_to_the_guard_file_reaches_a_repo_that_extends_it` rewrites "is not allowed" in a copy and matches its own regex. It does not use `REFUSAL`, so it keeps working.
- Rejected: a new test per acceptance criterion. The existing refusal tests already exercise each path against both configs; widening the shared regex proves the text with less code.
- Rejected: leaving `test/branch_guard_test.rb` alone and relying only on the static grep. A grep proves the words are in the file, not that lefthook prints them on a refused commit or push.
- The branch guard tests skip when no lefthook binary is found. Locally it comes from `LEFTHOOK_BIN`, `PATH` or an rv gem; CI installs it. A skip is not a pass: if the tests skip locally, report that and rely on CI.

## Out of scope

- The `test/isolated_git.rb` require failures (PR #210).
- The `fail_text` lines.
- Any change to what the guard refuses or allows.
- The header comment in `lefthook-branch-guard.yml`.

## Proof

- A commit on main in a repository that extends the guard file is refused with "Create a feature branch; deliver opens the PR." → `test/branch_guard_test.rb` `test_a_lefthook_local_extending_the_guard_refuses_a_commit_on_main`
- An empty commit on main is refused with the same text → `test/branch_guard_test.rb` `test_a_lefthook_local_extending_the_guard_refuses_an_empty_commit_on_main`, `test_the_fallback_config_refuses_an_empty_commit_on_main`
- A push from main is refused with "Direct push to main is not allowed. Create a feature branch; deliver opens the PR." → `test/branch_guard_test.rb` `test_a_lefthook_local_extending_the_guard_refuses_a_push_on_main`
- A push of a feature branch to the remote `main` ref is refused with "Pushing to main is not allowed. Push a feature branch; deliver opens the PR." → `test/branch_guard_test.rb` `test_a_lefthook_local_extending_the_guard_refuses_a_push_of_a_feature_branch_to_main`, `test_the_fallback_config_refuses_a_push_of_a_feature_branch_to_main`
- No refusal message in `lefthook.yml` or `lefthook-branch-guard.yml` says "open a PR" → `test/pull_request_flow_test.rb` `test_lefthook_messages_send_pull_requests_through_deliver`
- `test_the_fallback_config_duplicates_the_guard_commands_exactly` passes → `test/branch_guard_test.rb` `test_the_fallback_config_duplicates_the_guard_commands_exactly`
- `test_lefthook_messages_send_pull_requests_through_deliver` passes and finds four messages in each file → `test/pull_request_flow_test.rb` `test_lefthook_messages_send_pull_requests_through_deliver`

Per changed file, the unit tests expected:
- `lefthook-branch-guard.yml`: every refusal test in `test/branch_guard_test.rb` that sets up an extending repository prints the deliver text; `test_the_fallback_config_duplicates_the_guard_commands_exactly` holds.
- `lefthook.yml`: every `test_the_fallback_config_refuses_*` test prints the deliver text; `test_lefthook_messages_send_pull_requests_through_deliver` finds four messages.
- `test/pull_request_flow_test.rb`, `test/branch_guard_test.rb`: test files only; their runs are the proof.

Test setup: no new setup. `test/branch_guard_test.rb` already builds scratch repositories with the real global hooks and a lefthook binary; `test/pull_request_flow_test.rb` reads the files as text.

---
Domain skills applied: dotfiles-maintenance (lefthook fallback and extends model), rails-testing (Minitest conventions for the test edits).

## Critique

### Round 1 (codex exec -p terra)

- Step 2 overstates fallback coverage: no selected test pushes from fallback `main`, and 25 of 26 selected tests fail red, not a smaller set → fixed (step 2 now states the exact red result and that the fallback pre-push current-branch line is proven by the static test only)
- Step 8 is not reproducible: a scratch repository needs `core.hooksPath`, and a refused staged commit leaves state that stops the empty commit from reaching `commit-msg` → fixed (step 8 now names one fresh repository per case and the full setup)
- Step 7 claims to run the pre-push rubocop command, but that job unsets `GIT_DIR` and lints `{push_files}` → fixed (step 7 now runs `env -u GIT_DIR rubocop` and calls it the manual equivalent)

Reproduction: committed
