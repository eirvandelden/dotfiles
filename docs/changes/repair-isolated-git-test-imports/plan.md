# Plan: Every test file requires the isolated_git helper

From `intent.md` (2026-10-13). Status: accepted.

## Design decisions

- The reproduction already exists. `IsolatedGitTest#test_every_test_file_requires_the_helper` (`test/isolated_git_test.rb:84`) is on `main` and fails there. It is the RED proof; no new test is written.
- `Type: chore`, not `bugfix`, and this plan has no `Reproduction: committed` line. The fix itself edits test files. `test-guard.rb` refuses every test-file write while `plan.md` carries `Reproduction: committed`, which the bugfix flow in `implement` adds. That would block the only correct fix.
- Position: the established one. In the files that already have the helper, `require_relative "isolated_git"` is the last line of the top require block, after any other `require_relative` (for example `require_relative "lefthook_binary"`). Each of the eleven files gets one line in that slot, nothing else.
- Work from the live `origin/main` (534781ca), not from 3826d72e. PR #204 added three more files without the helper, so the list is eleven, not eight. Before the push, fetch again and re-run the contract test against any newer `main`.

## Integration points

- `.github/workflows/dotfiles-tests.yml` runs each `test/*_test.rb` with `ruby -Itest` on Ruby 3.4, after it installs minitest, RuboCop plugins, zsh, lefthook and markdownlint. It is not changed.
- `test/isolated_git.rb` sets `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` to `/dev/null` for the process and its children. Tests that pass their own `GIT_CONFIG_GLOBAL` to a child still win. A file that needs the global config would now fail; the per-file runs below catch that.
- PR #202 touches other test files only. No overlap, no dependency.

## Files that change

Each gets one added line, `require_relative "isolated_git"`, as the last line of its top require block:

- `test/bi_test.rb` — after `require "tmpdir"`.
- `test/gem_install_rule_mirror_test.rb` — after `require "minitest/autorun"`.
- `test/herdr_quieter_tones_test.rb` — after `require "tmpdir"`.
- `test/lefthook_rubocop_git_gem_test.rb` — after `require_relative "lefthook_binary"`.
- `test/neovim_avante_dependencies_test.rb` — after `require "json"`.
- `test/pull_request_flow_test.rb` — after `require "minitest/autorun"`.
- `test/rbs_inline_tooling_test.rb` — after `require "open3"`.
- `test/review_push_hook_test.rb` — after `require_relative "lefthook_binary"`.
- `test/worktree_first_skill_test.rb` — after `require "tmpdir"`.
- `test/worktree_guard_test.rb` — after `require "tmpdir"`.
- `test/worktree_rule_mirror_test.rb` — after `require "minitest/autorun"`.
- `test/worktree_sweep_on_pull_test.rb` — after `require_relative "lefthook_binary"`. Added after PR #205 landed on `main` (489b5988) without the helper (step 8).
- `test/worktree_sweep_test.rb` — after `require "tmpdir"`. Same origin as the line above.

## Order of work

1. Run `ruby -Itest test/isolated_git_test.rb -n test_every_test_file_requires_the_helper` and watch it fail, listing the eleven files.
2. Add the line to the eleven files.
3. Run the contract test again; it passes.
4. Run each of the eleven files on its own with `ruby -Itest`; each passes.
5. Run the full suite with the same loop CI uses (the local Ruby and tools may differ; the pull request CI run is the Ruby 3.4 proof): `for file in test/*_test.rb; do ruby -Itest "$file" || exit 1; done`.
6. Run `rubocop --force-exclusion` on the eleven files.
7. Re-read the diff: eleven one-line additions and nothing else. Commit as one change.
8. Fetch `origin/main` again. If it moved, rebase, then list missing files with `git grep -L "^require_relative \"isolated_git\"$" -- "test/*_test.rb"`. Add the helper to every newly listed file in the same position, then repeat steps 3 to 7.

## Risks

- A test in one of the files relies on the global git config, for example a global identity for `git commit`. The helper would then break it locally. The per-file runs in step 4 catch this. A failure is fixed in that test's own setup, never by removing the helper.
- `main` moves again and adds another file without the helper. Step 8 catches this before the push.
- Rejected: a guard that adds the require automatically, or a softer contract. Both change the contract, which the intent puts out of scope.

## Proof

- The contract test lists no missing file → `test/isolated_git_test.rb` `IsolatedGitTest#test_every_test_file_requires_the_helper`
- Each of the eleven files passes on its own with the helper → check: `for f in bi gem_install_rule_mirror herdr_quieter_tones lefthook_rubocop_git_gem neovim_avante_dependencies pull_request_flow rbs_inline_tooling review_push_hook worktree_first_skill worktree_guard worktree_rule_mirror worktree_sweep worktree_sweep_on_pull; do ruby -Itest "test/${f}_test.rb" || exit 1; done`
- The full suite passes locally with the CI test loop → check: `for file in test/*_test.rb; do ruby -Itest "$file" || exit 1; done`
- The pull request's CI is green → check: `gh pr checks <pr-number>`

Per changed file, the unit tests expected: none new. Each file's existing tests must still pass.

Test setup: none beyond the existing helper.

---
Domain skills applied: dotfiles-maintenance, ruby-style.

## Critique

### Round 1 (codex exec -p terra)

- The test-guard rationale was inaccurate: `test-guard.rb` checks only for `Reproduction: committed`, not for `Type:` → fixed (Design decisions now state that this plan carries no `Reproduction: committed` line and why)
- Step 8 detected new missing files after a rebase but gave no repair step → fixed (step 8 now lists missing files with `git grep -L`, adds the helper to each, and repeats steps 3 to 7)
- The local suite is not the full CI environment, which pins Ruby 3.4 and installs test tools → fixed (Integration points and step 5 name the CI environment; the pull request CI run is the Ruby 3.4 proof)
