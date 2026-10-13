# Intent: Every test file requires the isolated_git helper

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: chore.
Delivery: autonomous

## Problem

CI on `main` is red. Run 38400321672 (3826d72e, PR #203) and run 38401129980 (534781ca, PR #204) both fail one test: `IsolatedGitTest#test_every_test_file_requires_the_helper` (`test/isolated_git_test.rb:89`).

That test requires every `test/*_test.rb` file to contain the line `require_relative "isolated_git"`. Eleven test files on `main` do not: `bi_test.rb`, `gem_install_rule_mirror_test.rb`, `herdr_quieter_tones_test.rb`, `lefthook_rubocop_git_gem_test.rb`, `neovim_avante_dependencies_test.rb`, `pull_request_flow_test.rb`, `rbs_inline_tooling_test.rb`, `review_push_hook_test.rb`, `worktree_first_skill_test.rb`, `worktree_guard_test.rb` and `worktree_rule_mirror_test.rb`. The first eight came in before or with PR #203; PR #204 added the last three.

Without the helper, a test that starts git can read the machine's global git setup (hooks, signing), so a local run can differ from CI.

## Proposed outcome

Every test file on the branch requires `isolated_git`, so the contract test passes and the `Dotfiles tests` workflow is green again. The in-progress autonomous-delivery-reliability work can then rebase on this fix.

## Affected users and systems

- The `Dotfiles tests` GitHub Actions workflow on `main` and on every pull request.
- Local test runs on Etienne's machines.
- The eleven test files listed under Problem.

## Constraints

- Authorization: playbook rule 25 requires that a pre-existing CI failure gets its own worktree and pull request, before the in-progress work rebases on it. Etienne approved the autonomous-delivery-reliability task; this repair is a necessary step of that task. On 2026-10-13 the root Codex coordinator instructed this repair; the Claude coordinator records this intent as accepted under that authority. Etienne keeps the merge decision.
- No permissions under playbook rules 8, 9, 11, 12 or 13 are needed or approved: no new dependency, no system tool, no migration, no symlink or stow change, no CI or deploy configuration change.
- The contract in `test/isolated_git_test.rb` and the helper `test/isolated_git.rb` stay unchanged.
- PR #202 (`test-repos-ignore-global-git-setup`) is open and related. It does not touch these eleven files. This change does not edit or depend on it.

## In scope

- Add `require_relative "isolated_git"` to each test file that misses it on the current `origin/main`, in the established position: the last line of the file's top require block.
- The change artifacts for this repair.

## Out of scope

- Any change to `test/isolated_git.rb`, `test/isolated_git_test.rb` or other test logic.
- Skipping, deleting or weakening a test.
- Hooks, git guards, CI workflows, dependencies, machine settings and symlinks.
- PR #202 and any other cleanup.

## Acceptance criteria

- On this branch, the contract test lists no missing file: `IsolatedGitTest#test_every_test_file_requires_the_helper` passes.
- Each of the eleven files still passes on its own, with the helper loaded.
- The full `test/*_test.rb` suite passes locally, the same way the CI workflow runs it.
- The pull request's `Dotfiles tests` CI run is green.

## Open questions

None.
