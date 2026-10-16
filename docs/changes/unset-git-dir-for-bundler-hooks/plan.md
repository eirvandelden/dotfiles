# Plan: Bundler hook jobs work in linked worktrees

From `intent.md` (2026-10-16). Status: accepted.

## Context

Git exports `GIT_DIR` (and in pre-commit `GIT_INDEX_FILE`) to its hooks, and lefthook passes the environment to every job. A gem installed from git can run git while Bundler loads its gemspec (mvpa-css computes its version that way). With `GIT_DIR` set, that git call reads the project repository instead of the gem checkout, the version no longer matches `Gemfile.lock`, and Bundler stops with "can no longer be found in that source", "Could not find" or "Unable to find gem". The `rubocop` jobs (PR #200, comment at `lefthook.yml` pre-commit `rubocop`) and `bundle-audit` already unset it. `test/lefthook_rubocop_git_gem_test.rb` is the regression test for the rubocop jobs: a fixture gem `house-style` with a dynamic version, a real bundle, real lefthook and the global hook shims from `git/.config/git/hooks`.

Repositories that load the dotfiles config through lefthook `remotes` read a shallow clone in `<repo>/.git/info/lefthook-remotes/dotfiles`. The hook shims run lefthook with `--no-auto-install`, so nothing refreshes it. `git/.config/git/worktree-tools/README.md` ("Sweep on pull", rollout list) tells the reader to pull each one by hand. On this machine 12 caches exist under `~/Developer/*/.git/info/lefthook-remotes/dotfiles` (the 11 in `intent.md` plus `fizzy`); all are on `main`, and `ambx` uses an https origin.

## Design decisions

- Clear the variables inside each job's `run` script with `unset`. Lefthook's `env:` key can only set a variable, not remove it, and an empty `GIT_DIR` is not the same as no `GIT_DIR`.
- New fixes unset `GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_OBJECT_DIRECTORY`, the list `worktree-sweep` clears as `HOOK_ENVIRONMENT`. `GIT_INDEX_FILE` leaks into pre-commit, and a gemspec that runs `git ls-files` would read the project index. Only `GIT_DIR` reproduces the bug in the fixture; the others are cleared because they point at the project repository too, and the guard checks `GIT_DIR` only. The existing `rubocop` jobs stay as they are (they work; changing them is out of scope).
- Each changed job gets a one-line comment that points at the pre-commit `rubocop` comment, as the pre-push `rubocop` job does now. No new long explanation.
- Rejected: unsetting the variables in the global hook shims (`git/.config/git/hooks/*`). It would reach every repository without a cache refresh, but `git commit <paths>` runs pre-commit against a temporary index named by `GIT_INDEX_FILE`, so lefthook would see the wrong staged files. It would also change every job, not only Bundler jobs, and `intent.md` asks for a per-job guard.
- The guard test fails closed. It reads every command of every hook in `lefthook.yml` and requires it to clear `GIT_DIR`, unless the test lists that `hook/command` in a `BUNDLE_FREE_COMMANDS` constant. A new job of any kind fails the suite until someone either clears `GIT_DIR` or lists the job as free of Bundler. A list of Bundler executables (rails, rspec, brakeman, ...) was rejected: a new tool not in the list would pass unnoticed.
- "Clears `GIT_DIR`" means the `run` text holds a line that starts with `unset` and names `GIT_DIR`, or the text `env -u GIT_DIR`.
- The behavioural test puts small probe executables on `PATH` and in the project's `bin/` (`brakeman`, `erb_lint`, `bundler-audit`, `rails`, `bi`, `bin/rails`, `bin/rspec`). Each probe is a Ruby script that runs `require "bundler/setup"` and prints `bundle loaded by <name>`. CI has none of the real tools, and the bug is Bundler itself loading the git gem under the hook's environment, which the probe does with real Bundler. The live sticker-app push proves the real tools.
- The shared fixture (gem repository, bundle with the dynamic gemspec restored, project with a linked worktree and a bare origin, isolated `HOME` with `lefthook.yml` and the hook shims) moves out of `test/lefthook_rubocop_git_gem_test.rb` into `test/git_gem_fixture.rb`, a module both test classes include. Both test files need the same slow `bundle install` setup; one copy keeps them in step.
- Refresh command: `lefthook-remotes-refresh`, a plain Ruby script (like `worktree-sweep`: `#!/usr/bin/env ruby`, no rv) at `git/.local/bin/lefthook-remotes-refresh`. Lefthook is a git hook manager, so it belongs in the `git` package; `~/.local/bin` is on `PATH` (`zsh/.config/zsh/paths.zsh`). `.local` is dot-prefixed, so `test/stow_package_roots_test.rb` accepts it.
- The command finds caches with the glob `$HOME/Developer/*/.git/info/lefthook-remotes/dotfiles`. Linked worktrees share the main `.git`, so one level is enough. Caches that lefthook names with a ref suffix (`dotfiles-<ref>`) are not matched; none exist.
- Per cache it runs, with `GIT_TERMINAL_PROMPT=0` and the hook variables removed from its environment: `git fetch --depth 1 origin main`, then `git checkout --force -B main FETCH_HEAD`, then `git clean -ffdx`. It always resets, so a fast-forward, local changes, a diverged history and a cache left on another branch all end equal to origin's `main`. Before and after it compares `HEAD` and `git status --porcelain`. Output, one line per cache, on stdout: `updated <repo>: <old short sha> -> <new short sha>` or `current <repo>`. A cache whose fetch fails prints `failed <repo>: <first line of git's stderr>` on stderr; the command goes on with the next cache and exits 1 at the end. It exits 0 when every cache succeeded, also when none exist.
- Stow timing. A stow run from the worktree would link `~/.local/bin` to a worktree path that is deleted after the merge, and the main checkout does not hold the script until the merge. So nothing is stowed during delivery. After the merge Etienne runs `cd ~/Developer/dotfiles && stow -t "$HOME" git` (check `ls -l ~/.config/git/hooks` first: every hook must already be a link into the dotfiles repository). Until then `~/Developer/dotfiles/git/.local/bin/lefthook-remotes-refresh` works by full path.

## Integration points

- lefthook (native binary from `test/lefthook_binary.rb` in tests), the global hook shims in `git/.config/git/hooks`, and Bundler with a git-sourced gem.
- The nested `lefthook run migrations` from `post-merge` and `post-rewrite`: it inherits the hook environment, so the `bundle` and `migrate` jobs clear it themselves.
- `bi` (`ruby/.local/bin/bi`) runs inside the `bundle` job; it does not change.
- Repositories that use `remotes: - git_url: git@github.com:eirvandelden/dotfiles` (sticker-app `.lefthook.yml`) and their cache clones.
- CI: `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb` with Ruby 3.4, Bundler, lefthook, no brakeman or erb_lint. The new tests must pass there.

## Files that change

- `lefthook.yml` — clear the hook variables in pre-commit `erb_lint`, pre-push `brakeman`, `erb_lint`, `minitest`, `rspec`, and `migrations` `bundle` and `migrate`. One-line comment on each.
- `test/git_gem_fixture.rb` (new) — the fixture extracted from the rubocop test, plus helpers to write probe executables, a `PATH` with the probe directory first, and helpers to commit, push and pull from either checkout.
- `test/lefthook_rubocop_git_gem_test.rb` — include `GitGemFixture`; no test changes.
- `test/lefthook_bundler_git_gem_test.rb` (new) — behavioural regression tests for the Bundler jobs, in the linked worktree and in the main checkout.
- `test/lefthook_git_dir_guard_test.rb` (new) — the static guard over `lefthook.yml`.
- `git/.local/bin/lefthook-remotes-refresh` (new, executable) — the refresh command.
- `test/lefthook_remotes_refresh_test.rb` (new) — tests for the refresh command against local bare repositories.
- `git/.config/git/worktree-tools/README.md` — the rollout line that says to pull each cache by hand names `lefthook-remotes-refresh` instead.

## Order of work

1. Extract the fixture from `test/lefthook_rubocop_git_gem_test.rb` into `test/git_gem_fixture.rb`. Run `ruby -Itest test/lefthook_rubocop_git_gem_test.rb`; it stays green. Commit.
2. Write the first acceptance test in `test/lefthook_bundler_git_gem_test.rb`: from the linked worktree, push a commit that changes `Gemfile` (a comment line) in a project with `config/application.rb`; the `brakeman` probe must print its marker and the push must pass. Add the fixture self-check (`bundle loaded by` is absent and the probe fails when `GIT_DIR` leaks). Run it, watch the brakeman test fail with a Bundler "could not find" error. The `bundler-audit` probe runs in the same push and passes, since that job already unsets.
3. Fix `brakeman` in `lefthook.yml`. Green.
4. Pre-push `erb_lint` test (push an `.erb` file), then the fix. Pre-commit `erb_lint` test (commit an `.erb` file), then the fix.
5. `minitest` test (push `app/models/thing.rb` with `test/models/thing_test.rb` present; probe `bin/rails`), then the fix. `rspec` test (`spec/models/thing_spec.rb`, probe `bin/rspec`), then the fix.
6. Post-merge tests from the linked worktree: a pull that changes `Gemfile.lock` runs the `bi` probe; a pull that adds `db/migrate/*.rb` runs the `rails` probe. Then the fixes for `bundle` and `migrate`. Post-rewrite tests: `git pull --rebase` over a local commit that changes `Gemfile.lock` runs the `bi` probe, and one that adds a migration runs the `rails` probe. The `Gemfile.lock` change appends a blank line at the end of the file; Bundler's lockfile parser skips blank lines, so the bundle still loads. If Bundler rejects it, pick another change it accepts and say so in a test comment.
7. Main-checkout tests: the project checkout switches to its own branch. A commit there runs pre-commit `erb_lint`; a push runs pre-push `brakeman`, `erb_lint`, `minitest` and `rspec`; a pull runs post-merge `bundle` and `migrate`; a rebasing pull runs post-rewrite `bundle` and `migrate`. Every probe prints its marker and every hook passes.
8. Write `test/lefthook_git_dir_guard_test.rb`: a test that a fixture YAML with an unlisted job that does not clear `GIT_DIR` fails and the message names `hook/command`; a test that `lefthook.yml` itself passes. Fill `BUNDLE_FREE_COMMANDS` from the current file. Run; green after steps 3–6. Check that removing the `unset` from one job makes it fail with that job's name, then put it back.
9. Write `test/lefthook_remotes_refresh_test.rb`, one case at a time, red then green against `git/.local/bin/lefthook-remotes-refresh`: a cache behind origin is updated and listed; a current cache is reported `current`; a cache with an uncommitted change and a diverged local commit ends equal to origin `main` with a clean status; a cache on another branch ends on `main`; a cache whose origin path does not exist is named on stderr, the other caches still update, and the exit status is 1. Fixtures: a fake `HOME` with `Developer/<repo>/.git/info/lefthook-remotes/dotfiles` cloned from a local bare repository; no network.
10. Update the README rollout line.
11. Run the full suite (`for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`, as CI runs it; `|| break` would end the loop with status 0), RuboCop with `rubocop/.rubocop.yml` on every changed Ruby file, `yamllint lefthook.yml`, and the markdown no-hardwrap check on the README. Re-read the diff.
12. Live proof in sticker-app, before the merge, after the branch is pushed:
    1. `git -C ~/Developer/sticker-app/.git/info/lefthook-remotes/dotfiles fetch --depth 1 origin unset-git-dir-for-bundler-hooks` and `git -C <same> checkout --detach FETCH_HEAD`.
    2. From `~/Developer/sticker-app/.worktrees/update-dependencies`, run `git push` (its upstream is `origin`). Do not rebase or change the branch. Every pre-push job must pass, without `--no-verify`. Record the output in the report.
    3. A job that fails on a real finding (a brakeman warning, a failing test, an erb_lint offence) and not on a missing gem stops the delivery: put the cache back (next step) and ask Etienne.
    4. `git -C <cache> fetch --depth 1 origin main`, then `git -C <cache> checkout --force -B main FETCH_HEAD`. Confirm `git -C <cache> rev-parse --abbrev-ref HEAD` prints `main` and `git -C <cache> rev-parse HEAD` equals the first field of `git -C <cache> ls-remote origin refs/heads/main`. This leaves the cache on current dotfiles `main`, which may be newer than before the proof.

## Risks

- The probes stand in for the real tools in the automated tests. If a real tool loads Bundler some other way, the tests pass and the tool still fails; the sticker-app push in step 12 covers that.
- The fixture `bundle install` is slow and now runs once per test class (two classes). Acceptable; the shared build stays class-level.
- `git clean -ffdx` in the refresh command deletes untracked files in a cache. The cache is lefthook's own clone, so nothing of value lives there.
- A job listed in `BUNDLE_FREE_COMMANDS` by mistake hides a future regression. The list carries a short reason per group.
- The `bi` and `rails` jobs in `migrations` start with `: {files}` so lefthook filters by glob; the `unset` must come after that line, not replace it.
- sticker-app's `update-dependencies` branch may need its own real fixes once the hooks run. That is a stop-and-ask per `intent.md`, not part of this change.
- Rejected: changing the existing `rubocop` jobs to unset all three variables. They work, and the change is cosmetic.

## Out of scope

- `lefthook-local.yml`, `lefthook-branch-guard.yml`.
- Running `lefthook-remotes-refresh` over all caches after the merge, and the stow run after the merge (Etienne does both).
- A static version in mvpa-css.
- Removing the `pre-push-minitest-unset-git-dir` worktree.
- Any change to the hook shims in `git/.config/git/hooks`.

## Proof

- Linked worktree: pre-push `brakeman` analyses instead of failing → `test/lefthook_bundler_git_gem_test.rb` `test_brakeman_loads_the_bundle_when_pushing_from_a_linked_worktree`
- Linked worktree: `erb_lint` (pre-commit and pre-push), `minitest`, `rspec` check the changed files → `test/lefthook_bundler_git_gem_test.rb` `test_erb_lint_loads_the_bundle_when_committing_from_a_linked_worktree`, `test_erb_lint_loads_the_bundle_when_pushing_from_a_linked_worktree`, `test_minitest_loads_the_bundle_when_pushing_from_a_linked_worktree`, `test_rspec_loads_the_bundle_when_pushing_from_a_linked_worktree`
- Linked worktree: pull runs post-merge `bundle` and `migrate`, rebase runs them through post-rewrite → `test/lefthook_bundler_git_gem_test.rb` `test_a_pull_that_changes_the_lockfile_runs_bi_with_the_bundle_loaded`, `test_a_pull_that_adds_a_migration_runs_rails_with_the_bundle_loaded`, `test_a_rebasing_pull_that_changes_the_lockfile_runs_bi_with_the_bundle_loaded`, `test_a_rebasing_pull_that_adds_a_migration_runs_rails_with_the_bundle_loaded`
- Main checkout still passes → `test/lefthook_bundler_git_gem_test.rb` `test_erb_lint_loads_the_bundle_when_committing_from_the_main_checkout`, `test_the_pre_push_bundler_jobs_pass_in_the_main_checkout`, `test_a_pull_in_the_main_checkout_runs_bi_and_rails_with_the_bundle_loaded`, `test_a_rebasing_pull_in_the_main_checkout_runs_bi_and_rails_with_the_bundle_loaded`
- A new Bundler job without clearing `GIT_DIR` fails the suite and names the job → `test/lefthook_git_dir_guard_test.rb` `test_a_job_that_keeps_git_dir_fails_and_names_the_job`, `test_every_lefthook_job_clears_git_dir_or_is_listed_as_bundle_free`
- Refresh brings every cache to `main` and lists each one updated → `test/lefthook_remotes_refresh_test.rb` `test_a_cache_behind_origin_is_updated_and_listed`, `test_a_current_cache_is_reported_current`
- A cache with local changes or diverged history ends equal to origin `main` → `test/lefthook_remotes_refresh_test.rb` `test_a_cache_with_local_changes_and_a_diverged_commit_ends_equal_to_origin_main`, `test_a_cache_on_another_branch_ends_on_main`
- An unreachable origin is named, the others update, exit non-zero → `test/lefthook_remotes_refresh_test.rb` `test_an_unreachable_origin_is_named_and_the_other_caches_still_update`
- sticker-app `update-dependencies` push passes every pre-push job, cache back on `main` → check: step 12 of Order of work, output recorded in the report

Per changed file, the unit tests expected:

- `test/git_gem_fixture.rb`: covered by `test/lefthook_rubocop_git_gem_test.rb` staying green unchanged, and by `test_the_fixture_reproduces_the_bug_when_git_dir_leaks` in both test classes.
- `lefthook.yml`: the acceptance tests above, plus `LefthookGitDirGuardTest#test_every_lefthook_job_clears_git_dir_or_is_listed_as_bundle_free`.
- `git/.local/bin/lefthook-remotes-refresh`: the refresh tests above, plus `test_no_caches_exits_zero_with_no_output`.

Test setup: one fixture gem with a git-derived version, one bundle installed under a shared `BUNDLE_PATH` with the dynamic gemspec restored (as the rubocop test does now), a project with a linked worktree and a bare origin, an isolated `HOME` holding `lefthook.yml` and the hook shims, and probe executables on `PATH`. The refresh tests use local bare repositories only. Nothing touches the network.

---
Domain skills applied: dotfiles-maintenance (stow package roots, stow timing), ruby-style, rails-testing (Minitest, behaviour-named tests, real boundaries over mocks).

## Critique

### Round 1 (codex exec -p terra)

- The cleanup list is narrower than the six variables `worktree-sweep` clears → fixed (new fixes unset the full `HOOK_ENVIRONMENT` list; the fixture still exercises `GIT_DIR` only, because only that variable reproduces the bug)
- The post-hook proof misses a `Gemfile.lock` pull and a `Gemfile.lock` rebase → fixed (steps 6 and Proof test a `Gemfile.lock` pull and rebase that run `bi`, and a migration pull and rebase that run `rails`)
- Main-checkout coverage omits pre-commit `erb_lint`, `migrations.bundle` and post-rewrite → fixed (step 7 and Proof cover every changed job in the main checkout)
- The full-suite loop with `|| break` exits 0 after a failure → fixed (step 11 uses `|| exit 1`, as CI does)
- The live-proof cleanup checks only the branch name, not that it equals origin `main` → fixed (step 12.4 fetches, resets `main` to `FETCH_HEAD` and compares with `ls-remote`)
