# Plan: Rubocop hooks work when Bundler loads a gem from git

From `intent.md` (2026-10-06). Status: accepted.

## Context

The pre-commit and pre-push `rubocop` jobs in the dotfiles `lefthook.yml` fail with `Unable to find gem <name>` in a repository whose bundle holds a gem from git. Git exports `GIT_DIR` to hooks, and lefthook passes it to every job. This plan fixes both jobs in the dotfiles repository and proves the fix with an offline acceptance test. The work in other repositories (criteria 6–9) follows after the merge, in the section "After the merge".

## Design decisions

**The cause, refined.** Bundler's own git calls already clear `GIT_DIR` and `GIT_WORK_TREE` (`SharedHelpers.with_clean_git_env`, in Bundler 2.7.2 and 4.x). The git call that breaks runs inside a gem's own code while Bundler loads its gemspec. In clocky this is mvpa-css: `lib/mvpa/css/version.rb` runs `git -C __dir__ rev-parse --short HEAD` to build the version. With the leaked `GIT_DIR`, that call reads the project's repository (absolute `GIT_DIR`) or no repository (relative `.git`). The version then does not match `Gemfile.lock`, and `Bundler.load` raises `Bundler::GemNotFound` for the whole bundle. RuboCop's `ConfigLoaderResolver#gem_config_path` rescues that error, falls back to RubyGems, and reports `Unable to find gem rubocop-eirvandelden`. Verified on 2026-10-07 in clocky: with `GIT_DIR` set, `Bundler.load` raises `Could not find mvpa-css-0.1.0.pre.git.53caa59`. So the gem that breaks the bundle need not be the gem that the RuboCop config inherits.

**The fix.** Each `rubocop` job's `run` becomes a block scalar whose first line is `unset GIT_DIR`, followed by the unchanged `rubocop` command. This copies the `bundle-audit` job in the same file. `unset` is POSIX sh, so it works under dash on Linux. `env -u` is not in POSIX, so it is not used.

**Only `GIT_DIR`.** The intent keeps `GIT_WORK_TREE` and `GIT_INDEX_FILE` out of scope unless the fix needs them. Bundler clears `GIT_WORK_TREE` for its own git calls. In pre-commit, a leaked `GIT_INDEX_FILE` only changes what a gemspec's `git ls-files` lists. Bundler validates a loaded spec with `validate_for_resolution`, which does not check the file list. The acceptance fixture's gemspec uses `git ls-files`, so the test shows whether this holds.

**`stage_fixed` keeps working.** Lefthook re-stages the fixed files from its own process, which keeps git's environment. The `unset` applies only inside the job's shell.

**A comment says why.** The pre-commit job gets a short comment above `run`, in the style of the `bundle-audit` comment. The pre-push job gets a one-line comment that points to it.

**The acceptance test uses the real tools.** Real git, the real global hook shims from `git/.config/git/hooks/`, real lefthook, real Bundler and real RuboCop. The project has no lefthook config, so the shim falls back to `$HOME/Developer/dotfiles/lefthook.yml`, a copy of this branch's `lefthook.yml`. This is the route `test/lefthook_posix_sh_test.rb` uses.

**The fixture gem mirrors mvpa-css.** A local git repository `house-style` holds the gem. Its `lib/house_style/version.rb` builds the version with `git -C __dir__ rev-parse --short HEAD`, as mvpa-css does. Its gemspec lists files with `git ls-files -z`, as the `bundle gem` template does. Its `config/default.yml` holds the RuboCop config: `AllCops: DisabledByDefault: true`, `SuggestExtensions: false`, `Style/StringLiterals` with `EnforcedStyle: double_quotes`, and `Naming/MethodName`. RuboCop's default is single quotes, so an autocorrect to double quotes proves that the gem config loaded. `Naming/MethodName` has no autocorrect, so it gives the offense that RuboCop cannot fix.

**Offline.** The project's `Gemfile` holds only `gem "house-style", git: "<tmpdir>/house-style"`, with no rubygems.org source. `bundle install` clones from the local path. `BUNDLE_PATH` points into the tmpdir, so nothing lands in the real gem home. The gem has no dependencies.

**Hooks run in a linked worktree.** Commits and pushes run in a linked worktree on branch `feature`. There git exports an absolute `GIT_DIR`, as in the intent's repro and in Etienne's daily work under `.worktrees/`. In a main checkout git exports a relative `.git`, which also breaks the gem's version. The test does not cover the main checkout; Etienne chose this on 2026-10-07.

**Pre-push stays narrow.** Before each hooked push, the test pushes `feature` once with `LEFTHOOK=0` to set its upstream. Then `{push_files}` holds only the new Ruby file. The `Gemfile` is never in the push range, so `brakeman` and `bundle-audit` (which needs the network) do not run. The test stubs `$HOME/.config/git/worktree-tools/review-report-fresh` as `exit 0`, because the real script resolves a path inside the dotfiles checkout.

**A canary test keeps criterion 5 true.** One test runs `rubocop` directly with `GIT_DIR` set, without any hook, and expects `Unable to find gem house-style`. If a later Bundler or RuboCop stops the bug, this test fails. It then says that the fixture no longer reproduces the bug, so the acceptance tests do not pass for nothing.

## Integration points

- Lefthook: from `LEFTHOOK_BIN` or `PATH` (`test/lefthook_binary.rb`). CI installs the latest release.
- The global hook shims in `git/.config/git/hooks/`: read by the test, not changed.
- Bundler, as shipped with Ruby. RuboCop, installed globally (CI installs it already).
- `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb` on Ubuntu, where `sh` is dash. No change is needed there.
- Repositories with no lefthook config get the fix through `~/Developer/dotfiles/lefthook.yml` once the main checkout pulls `main`.
- Repositories that list the dotfiles under `remotes` read a cached copy in `.git/info/lefthook-remotes/dotfiles`.

## Files that change

- `lefthook.yml`: the pre-commit `rubocop` job and the pre-push `rubocop` job. Each `run` becomes a block scalar that starts with `unset GIT_DIR`. Each job gets a comment. Tags, globs, flags and `stage_fixed` stay as they are.
- `test/lefthook_rubocop_git_gem_test.rb`: new. The acceptance tests and the canary test.

Nothing else changes. Not the hook shims in `git/.config/git/hooks/`, not `.github/workflows/`.

## Order of work

1. Write the fixture setup and the acceptance test for criterion 1. Run it against the unchanged `lefthook.yml`. Watch it fail, and check that the failure output holds `Unable to find gem house-style` (criterion 5). Keep that output for the pull request body.
2. Add the canary test. It passes against the unchanged config, because it checks a precondition.
3. Add the acceptance tests for criteria 2, 3 and 4. Run them. Each fails, and each failure shows `Unable to find gem house-style`.
4. Change the pre-commit `rubocop` job. Run the file. The tests for criteria 1, 2 and the commit half of 4 pass.
5. Change the pre-push `rubocop` job. Run the file. All tests in it pass.
6. Lint: `yamllint lefthook.yml`, and `rubocop test/lefthook_rubocop_git_gem_test.rb`.
7. Run the full suite with `LEFTHOOK_BIN` unset: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. The known failure in `test/review_report_check_test.rb` is out of scope.
8. Re-read the diff. Commit the test and the fix together as one logical change.
9. Run `review` (playbook rule 16). Push, and open a pull request against `origin`. The repository has no pull request template. CI on Ubuntu runs the test under dash.

## After the merge

These steps are not part of the implement stage. They start after Etienne merges the pull request.

1. Pull `main` into `~/Developer/dotfiles`. This updates the fallback config for every repository without a lefthook config.
2. In each repository that lists the dotfiles under `remotes`, refresh the cache: `git -C .git/info/lefthook-remotes/dotfiles pull --ff-only`. Never run `lefthook install` (the `dotfiles-maintenance` skill forbids it). Check with `git -C .git/info/lefthook-remotes/dotfiles log -1` that the merge commit is there.
3. Prove criteria 6 and 7 in each of those repositories. Make a scratch worktree on a throwaway branch. Commit a clean Ruby file with hooks on. Then run `git push --dry-run origin HEAD:refs/heads/<throwaway>`, which runs pre-push and changes nothing on the remote. Before the first repository, check that `--dry-run` fires the pre-push hook. Record the hook output of each repository. Then remove the scratch worktree and delete the throwaway branch. Etienne chose this method on 2026-10-07.
4. Start one `intent` chain per repository with its own `rubocop` job (criterion 8): appkit, cityofbrass, journal_administration, my-rails-template. happiness needs a check only, because it already uses `env -u GIT_DIR`.
5. Start one `intent` chain for mvpa.css (criterion 9). Its own `version.rb` runs git at load time, which is a likely reason for the skip.

Fresh check of `~/Developer` on 2026-10-07:

- Lists the dotfiles under `remotes`: ambx, babybuddy-kamal-deploy, clocky, ddicompendium, dm-adventure-book, fizzy, journal_administration, mvpa.css, rspec-testing-101, selenized_rails.novaextension, sticker-app, writebook. New since the intent: ambx, babybuddy-kamal-deploy, rspec-testing-101, selenized_rails.novaextension.
- writebook has no git remote, but it pulls the dotfiles config. Criterion 7 covers every repository that pulls the config, so writebook is in.
- Has its own `rubocop` job: appkit, cityofbrass, happiness, journal_administration, my-rails-template. mvpa.css skips the remote's pre-commit `rubocop` job in `lefthook-local.yml`.
- Re-run this check before step 2, because the list can change.

## Risks

- **Slow tests.** Each test runs `bundle install` and RuboCop. Six tests take some seconds each. If the file takes more than 30 seconds, build the fixture gem and the bundle once per process.
- **`{push_files}` without an upstream.** Lefthook's push range for a new branch is not clear. The test sets the upstream first, so it does not depend on that.
- **`GIT_INDEX_FILE` still leaks in pre-commit.** The fixture's `git ls-files` gemspec covers this. If the test fails on it, add `GIT_INDEX_FILE` to the `unset`. The intent allows that when the fix needs it.
- **A different Bundler in CI.** CI uses Ruby 3.4 with its own Bundler. The trigger is the gem's own git call, which does not depend on the Bundler version. The canary test shows it if that changes.
- Rejected: `env -u GIT_DIR`. It works on macOS and GNU, but POSIX does not define `-u`.
- Rejected: lefthook's `env:` key. It sets variables but cannot unset them, and an empty `GIT_DIR` breaks git.
- Rejected: an `unset` in the hook shims. The shims are out of scope, and the `unset` would also reach lefthook's own `git add` for `stage_fixed`.
- Rejected: a fix in mvpa-css's `version.rb` only. That removes one trigger, not the class of bug. It can be proposed as a separate change.

## Proof

- Criterion 1, a clean commit passes and RuboCop inspected the file → `test/lefthook_rubocop_git_gem_test.rb` `test_committing_a_clean_ruby_file_passes_after_rubocop_inspects_it`
- Criterion 2, a fixable offense commits fixed with nothing unstaged → `test/lefthook_rubocop_git_gem_test.rb` `test_committing_a_fixable_offense_commits_the_fixed_file_with_nothing_unstaged`
- Criterion 3, a clean push passes → `test/lefthook_rubocop_git_gem_test.rb` `test_pushing_a_clean_ruby_file_passes_after_rubocop_inspects_it`
- Criterion 4, an unfixable offense blocks the commit → `test/lefthook_rubocop_git_gem_test.rb` `test_an_unfixable_offense_blocks_the_commit`
- Criterion 4, an unfixable offense blocks the push → `test/lefthook_rubocop_git_gem_test.rb` `test_an_unfixable_offense_blocks_the_push`
- Criterion 5, the test fails with `Unable to find gem` without the fix → the red run in steps 1 and 3, quoted in the pull request body, and `test/lefthook_rubocop_git_gem_test.rb` `test_the_fixture_reproduces_the_bug_when_git_dir_leaks`
- Criterion 6, clocky commits and pushes a Ruby file → "After the merge" step 3: scratch-worktree commit and `git push --dry-run`, with recorded hook output
- Criterion 7, every other repository with the remote config commits a Ruby file → "After the merge" step 3: scratch-worktree commit, with recorded hook output per repository
- Criterion 8, every repository with its own `rubocop` job → one pull request per repository from its own chain, or a recorded passing check (happiness)
- Criterion 9, mvpa.css → its own chain, which removes the skip or records the real reason

What each test asserts:

- Criterion 1: the commit succeeds, `HEAD` holds the file, and the hook output holds `1 file inspected`.
- Criterion 2: the commit succeeds, `git show HEAD:<file>` holds double quotes, the working file matches it, and `git status --porcelain` is empty.
- Criterion 3: the Ruby commit lands with `LEFTHOOK=0`, the hooked push succeeds, `git ls-remote origin feature` equals `HEAD`, and the hook output holds `1 file inspected`.
- Criterion 4, commit: the commit fails, `HEAD` does not move, the output holds `Naming/MethodName`, and the output does not hold `Unable to find gem`.
- Criterion 4, push: the commit lands with `LEFTHOOK=0`, the hooked push fails, the remote `feature` ref does not move, the output holds `Naming/MethodName`, and the output does not hold `Unable to find gem`.
- Canary: `rubocop` run directly with `GIT_DIR` set exits non-zero, and its output holds `Unable to find gem house-style`.

Unit tests per changed file:

- `lefthook.yml`: configuration only. The acceptance tests above cover both changed jobs.
- `test/lefthook_rubocop_git_gem_test.rb`: is the test.

Test setup: one tmpdir per test, with `home/` as `HOME`, a copy of `lefthook.yml` at `home/Developer/dotfiles/`, the `review-report-fresh` stub, a copy of the hook shims, a global gitconfig with `core.hooksPath`, the `house-style` gem repository, a bare `origin.git`, the project's main checkout, its linked worktree on `feature`, and `bundle/` for `BUNDLE_PATH`. The main checkout holds `Gemfile`, `Gemfile.lock` and `.rubocop.yml` (`inherit_gem: { house-style: config/default.yml }`) in one commit made with `LEFTHOOK=0`, pushed to `origin`. The env for hooked commands keeps the caller's `PATH`, `GEM_HOME` and `GEM_PATH`, and sets `HOME`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM=/dev/null`, `BUNDLE_PATH`, `LEFTHOOK_BIN` and the author and committer variables. It clears `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `LEFTHOOK`, `LEFTHOOK_EXCLUDE`, `LEFTHOOK_CONFIG`, `BUNDLE_GEMFILE` and `RUBYOPT` from the caller. Each git command captures stdout and stderr together, because git sends hook output to stderr. A missing lefthook skips, as in the other lefthook tests. A missing `rubocop` or `bundle` skips locally and fails in CI, as in `test/rubocop_fallback_test.rb`.

## Out of scope

- Every other job in the dotfiles config: erb_lint, minitest, rspec, brakeman, bundle-audit and the post-merge bundle job.
- `GIT_WORK_TREE`, and `GIT_INDEX_FILE` unless the test proves the fix needs it.
- The hook shims in `git/.config/git/hooks/`.
- The known failure `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, and the `[[ ]]` bash-ism in the `no-push-to-main` job on Linux.
- The `LEFTHOOK_BIN` leak in `test/lefthook_local_hooks_test.rb`.
- A static version in mvpa-css. Propose it separately.
- Work repositories, and rails-console-on-nomad.

---
Domain skills applied: dotfiles-maintenance (never `lefthook install`; the global hook route), rails-testing (plain Minitest, no Rails assertions), ruby-style (test code shape).
