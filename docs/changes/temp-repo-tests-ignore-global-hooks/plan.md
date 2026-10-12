# Plan: temporary-repository tests ignore the machine's global git setup

From `intent.md` (2026-10-12). Status: accepted.

## Context

Fifteen of the 38 `test/*_test.rb` files spawn `git`, some through a private `git` or `run_git` helper, some with direct `system("git", ...)` calls (`auto_accept_test.rb`, `change_scope_test.rb`). Each file isolates a different subset of the global setup, or none:

- `review_report_check_test.rb` and `change_folder_test.rb` pass `-c commit.gpgsign=false` but keep the global `core.hooksPath`. On Etienne's machine the global `pre-commit` runs the `no-push-to-main` rule from `lefthook.yml`. That rule lets the first commit on an unborn branch through, because `git rev-parse --abbrev-ref HEAD` prints `HEAD` there. It refuses every later commit on `main`. So `ReviewReportCheckTest#test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` errors at line 53, where it commits on `main` again.
- `agent_worktree_test.rb`, `worktree_pane_test.rb` and `worktree_create_test.rb` pass `-c core.hooksPath=/dev/null` but keep `commit.gpgsign=true`. Their commits need the 1Password agent (`gpg.ssh.program = op-ssh-sign` in `git/.config/git/config`).
- `herdr_worker_scripts_test.rb#add_submodule` pushes from `child_seed` with neither override.
- The scripts under test (`hand-off-plan.sh`, `worktree-create`, and so on) run their own `git` and inherit the test process environment. A per-call `-c` flag never reaches them.

CI runs each file on its own: `for file in test/*_test.rb; do ruby -Itest "$file"; done` (`.github/workflows/dotfiles-tests.yml`). CI has no global hooks and no signing, so CI stays green either way.

## Design decisions

- **One shared helper, applied through the environment.** A new `test/isolated_git.rb` sets `ENV["GIT_CONFIG_GLOBAL"]` and `ENV["GIT_CONFIG_SYSTEM"]` to `/dev/null` when it is required. Git then never reads `~/.gitconfig`, `$XDG_CONFIG_HOME/git/config` or the system config, in the test process and in every child process. This covers the scripts under test, which per-call `-c` flags cannot reach. Git supports both variables since 2.32; the machine has 2.54.
- **An empty global config, not a checked-in one.** `/dev/null` gives git's defaults: no global hooks, no signing, no identity. That equals CI. A checked-in config with `user.name` and `user.email` was rejected: it would let a commit without an explicit identity pass locally and fail in CI. The existing helpers already pass `-c user.name` and `-c user.email`. `GIT_CONFIG_COUNT` and `GIT_AUTHOR_*` were rejected, because they override repository-local config.
- **Require, not an explicit call.** `require_relative "isolated_git"` applies the isolation, like `minitest/autorun` starts the runner. The regression check looks for that one line, so the line is the whole setup.
- **Every `test/*_test.rb` requires the helper.** A text heuristic for "spawns git" misses a test that only runs a script, where the script commits in a temporary repository. A universal require has no gap, and the regression check stays simple. The cost is one line in each of the 38 files.
- **Hook tests keep their hooks.** The four `lefthook_*` tests set `core.hooksPath` in the repository-local config or pass their own `GIT_CONFIG_GLOBAL` in an explicit environment hash. Both win over the helper, so those tests keep running the hooks they test. A `git` call there that forgets the explicit environment now gets an empty config instead of the machine's.
- **Existing per-call flags stay.** The `-c core.hooksPath=/dev/null` and `-c commit.gpgsign=false` flags in the current helpers become redundant. Removing them is unrelated churn, so this change leaves them.
- **Hostile global setup for the proofs.** The new tests build a temporary `XDG_CONFIG_HOME` with a `git/config` that turns on a global hook or global signing, and unset `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` in the child environment. That reproduces Etienne's machine (`~/.config/git/config`) without touching `HOME`, which `lefthook_binary.rb` and other tests read. The hostile `pre-commit` copies the `no-push-to-main` rule: it allows an unborn `HEAD` and refuses `main` and `master`. So the control fails at the same commit as on the machine, not during setup.

## Integration points

- Git's `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` environment variables.
- The scripts under test inherit the environment: `herdr/.config/herdr/scripts/*`, `git/.config/git/worktree-tools/*`, `claude/.claude/skills/plan/scripts/*`, `claude/.claude/hooks/*`.
- The CI loop in `.github/workflows/dotfiles-tests.yml`. It does not change.

## Files that change

- `test/isolated_git.rb` — new. Module `IsolatedGit` with `ENVIRONMENT = { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null" }.freeze`. The file ends with `ENV.update(IsolatedGit::ENVIRONMENT)`.
- `test/isolated_git_test.rb` — new. The acceptance tests and the regression check, listed under Proof.
- All 38 existing `test/*_test.rb` files — add `require_relative "isolated_git"` after the existing `require` lines. No other change.

## Order of work

1. Write `IsolatedGitTest#test_review_report_check_passes_under_the_global_no_push_to_main_hook`. It runs `ruby -Itest test/review_report_check_test.rb` in a child process with the hostile hook config and `GIT_CONFIG_GLOBAL` unset, and asserts exit 0. Run it and watch it fail: the child reports 1 error, with the hostile hook's refusal message. The test file does not require `isolated_git` yet, because that file does not exist yet.
2. Add `test/isolated_git.rb`. Add `require_relative "isolated_git"` to `test/review_report_check_test.rb` and `test/isolated_git_test.rb`. Run step 1's test and see it pass. Run `ruby -Itest test/review_report_check_test.rb` on the machine and see 0 errors.
3. Write the two control tests: a child `ruby -e <commit script>` without the helper, under each hostile config, fails at the second commit on `main` with the hostile marker message. Write the two helper tests: the same script run as `ruby -Itest -risolated_git -e <commit script>` succeeds under each hostile config. Write the environment test. Run them; all pass. The control tests prove that the hostile setup is real.
4. Write `test_every_test_file_requires_the_helper`. Run it and watch it fail, naming the 37 files without the require.
5. Add `require_relative "isolated_git"` to those 37 files. Run step 4's test and see it pass.
6. Run each changed test file that spawns git on its own, then the full suite with the CI loop. Then run the full suite with a hostile `XDG_CONFIG_HOME` (signing on, a `gpg.ssh.program` that exits 1, a `pre-commit` and `pre-push` that exit 1) and `GIT_CONFIG_GLOBAL` unset. Every file passes in both runs.
7. Run `rubocop` on every new and changed Ruby file and fix all offences. Re-read the full diff.

## Risks

- **Real-repository git calls lose the global config too.** Some tests may run `git` in the dotfiles checkout itself. With the helper, those calls no longer see `core.excludesFile = ~/.config/git/ignore.global`, `url.*.insteadOf` from `work-remotes.config`, `init.defaultBranch` or the global identity. A test that depends on one of these passes locally today and fails in CI the same way, so the fix belongs in that test, not in the helper. Step 6 finds any such test.
- **`git init` without `--initial-branch`.** `consent_guard_test.rb:344` runs `git init --quiet other`. After this change the branch name is git's built-in default, the same as in CI. The test does not read the branch name, so it is not affected.
- **A commit without explicit identity.** With an empty global config, git falls back to an identity it derives from the user and host name, or refuses. Both match CI. Step 6 finds a test that breaks on this.
- **Rejected: change the CI workflow to load the helper with `RUBYOPT=-r`.** That changes `.github/workflows/`, which needs approval under playbook rule 13, and it does not help a local single-file run.
- **Rejected: fix each `git` helper with more `-c` flags.** That misses the git calls inside the scripts under test, and nothing stops the next helper from forgetting a flag.
- **Rejected: require the helper only where a file spawns git.** A text heuristic misses a test whose script commits, so it cannot meet the fourth acceptance criterion.

## Out of scope

- The hook scripts, `lefthook.yml`, and the global git configuration in `git/.config/git/config`.
- `.github/workflows/dotfiles-tests.yml`.
- The tests in `git/.config/git/worktree-tools/test/` and `claude/.claude/test/`. They are not `test/*_test.rb` files, the intent names that scope.
- Removing the now-redundant per-call `-c` flags from existing helpers.

## Proof

- With the global `no-push-to-main` hook active, `test/review_report_check_test.rb` passes → `test/isolated_git_test.rb` `IsolatedGitTest#test_review_report_check_passes_under_the_global_no_push_to_main_hook`
- With commit signing on globally and no signing agent reachable, every temporary-repository test passes → `test/isolated_git_test.rb` `IsolatedGitTest#test_a_commit_ignores_global_signing_with_no_agent` and `IsolatedGitTest#test_every_test_file_requires_the_helper`, plus check: run the CI loop with `XDG_CONFIG_HOME` pointing at a hostile `git/config` (signing on, failing `gpg.ssh.program`) and `GIT_CONFIG_GLOBAL` unset; every file passes.
- The full suite passes locally and in CI → check: `for file in test/*_test.rb; do ruby -Itest "$file" || exit 1; done` on Etienne's machine, and the `Dotfiles tests` workflow on the pull request.
- A new temporary-repository test that forgets the setup is caught by a test → `test/isolated_git_test.rb` `IsolatedGitTest#test_every_test_file_requires_the_helper`

Per changed file, the unit tests expected:

- `test/isolated_git.rb`: `IsolatedGitTest#test_a_commit_ignores_the_global_no_push_to_main_hook`, `#test_a_commit_ignores_global_signing_with_no_agent`, `#test_without_the_helper_the_global_hook_blocks_the_second_commit_on_main`, `#test_without_the_helper_global_signing_blocks_the_commit`, `#test_the_helper_empties_the_global_and_system_config`.
- The 38 existing test files: their existing tests, unchanged, plus `#test_every_test_file_requires_the_helper`.

Test setup: a private helper in `isolated_git_test.rb` writes a hostile `XDG_CONFIG_HOME` into a `Dir.mktmpdir`, with `hook:` and `signing:` switches. `hook: true` sets `core.hooksPath` to a directory whose `pre-commit` copies the `no-push-to-main` rule (allow `HEAD`, refuse `main` and `master` with `global hook refused main`) and whose `pre-push` exits 1. `signing: true` sets `commit.gpgsign = true`, `gpg.format = ssh`, a dummy `user.signingkey`, and `gpg.ssh.program` to a script that prints `no signing agent` and exits 1. The child environment sets `XDG_CONFIG_HOME` to that directory and unsets `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM`. The commit script runs `git init --initial-branch=main` in a temporary directory, then two `git commit --allow-empty` with `-c user.name=Test -c user.email=test@example.com`, and exits with git's status. Teardown removes every temporary directory.

---
Domain skills applied: ruby-style, object-oriented-design, dotfiles-maintenance (rule 13 boundary on `.github/workflows/`).

## Critique

### Round 1 (codex exec -p terra)

- A text heuristic for "spawns git" misses a test whose script commits, so the regression check does not meet the fourth acceptance criterion → fixed (every `test/*_test.rb` requires the helper; the check asserts the universal require; the heuristic moved to Rejected)
- A hostile hook that refuses every commit fails `ReviewReportCheckTest` in setup, not at the reported commit on `main` → fixed (the hostile `pre-commit` copies the `no-push-to-main` rule; the control asserts failure at the second commit on `main`)
- A checked-in config with `user.name` and `user.email` lets a commit without identity pass locally and fail in CI → fixed (the helper points both variables at `/dev/null`; the checked-in config file is gone)
- The claim that all fifteen files have a `git` helper is false; `auto_accept_test.rb` and `change_scope_test.rb` call `system("git", ...)` directly → fixed (Context corrected)

Reproduction: committed
