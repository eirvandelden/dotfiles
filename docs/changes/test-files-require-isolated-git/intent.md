# Intent: Test files require isolated git

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: chore. Delivery: autonomous.

## Problem

A test file in `test/` can run git without `require_relative "isolated_git"`. Nothing notices the omission. The test then reads the machine's global git config: global hooks and commit signing. It passes in CI, where no global config exists, and fails on Etienne's machine. Today `bi_test.rb`, `review_push_hook_test.rb` and `lefthook_rubocop_git_gem_test.rb` run git without the helper. `worktree_guard_test.rb` and `worktree_first_skill_test.rb` keep their own partial copy, which empties the global config but not the system config.

## Proposed outcome

Every test file in `test/` requires `isolated_git`. A test fails, with the file name in the message, when a file in `test/` does not. Local runs and CI runs see the same empty git config.

## Affected users and systems

Etienne and agents who add or run tests in this repository. The CI workflow `dotfiles-tests.yml`, which runs `test/*_test.rb`.

## Constraints

- The test suite stays green locally and in CI.
- No new dependencies.
- Tests that need their own git config keep passing `GIT_CONFIG_GLOBAL` to a child process, as `isolated_git.rb` describes.
- Approved permissions for autonomous delivery: none. The change needs no gems, packages, system tools, migrations or deploy files.

## In scope

- Every `test/*_test.rb` file requires `isolated_git`, including files that do not run git today.
- The duplicate `WITHOUT_GLOBAL_GIT_CONFIG` constants go; those files use the helper.
- A test that fails when a `test/*_test.rb` file does not require `isolated_git`.

## Out of scope

- Test suites outside `test/`: `git/.config/git/worktree-tools/test/`, `conductor/.config/conductor/scripts/test/`, `claude/.claude/test/`.
- Changes to the CI workflow or to `lefthook.yml`.
- Changes to what `isolated_git.rb` sets.

## Acceptance criteria

- A new `test/foo_test.rb` without `require_relative "isolated_git"` makes the suite fail, and the failure names `test/foo_test.rb`.
- Every file in `test/` that ends in `_test.rb` requires `isolated_git` today, and the suite is green.
- `bi_test.rb`, `review_push_hook_test.rb` and `lefthook_rubocop_git_gem_test.rb` pass on a machine whose global git config has a refusing hook and signing with no agent.
- No file in `test/` defines its own `WITHOUT_GLOBAL_GIT_CONFIG`.

## Open questions

None.
