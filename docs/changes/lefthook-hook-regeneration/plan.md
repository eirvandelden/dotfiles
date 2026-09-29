# Plan: Lefthook hook rewrites stop blocking work

From `intent.md` and `spec.md` (2026-09-25). Status: accepted.

Change folder: `docs/changes/lefthook-hook-regeneration/` in worktree `~/Developer/dotfiles/.worktrees/lefthook-hook-regeneration` (branch `lefthook-hook-regeneration`, off `origin/main`). This file is copied to `docs/changes/lefthook-hook-regeneration/plan.md` once accepted.

## Context

The global git hooks (`git/.config/git/hooks/*`, lefthook's template plus `set_global_config` and `--no-auto-install`) are stowed as links into `~/.config/git/hooks/` (`core.hooksPath`). Three times, lefthook 2.1.12 replaced four of them (`pre-commit`, `pre-push`, `post-merge`, `post-rewrite` — the hooks named in the dotfiles `lefthook.yml`) with its own template. The install script then fails to stow `git` ("cannot stow … over existing target … neither a link nor a directory"), and repositories without their own lefthook config lose the global fallback.

Root cause, verified in lefthook 2.1.12 source and a temp repo:

- `lefthook run` syncs hooks when `.git/info/lefthook.checksum` is stale, unless `--no-auto-install` or the config key `no_auto_install: true` is set (`internal/command/run.go:99`).
- The sync is meant to refuse a global `core.hooksPath` (`ensureHooksPathUnset`, `internal/command/install.go:514`). It asks `git config --global core.hooksPath`. Because `~/.gitconfig` exists, git reads only that file for `--global` and never sees `~/.config/git/config`, so lefthook finds no global hooks path and writes.
- The trigger: the dotfiles `lefthook.yml` `post-merge` and `post-rewrite` hooks start a nested `git diff-tree … | lefthook run migrations --files-from-stdin` without `--no-auto-install` (10:05 pull, 11:12 rebase in a dotfiles worktree).

Second problem: in the `migrations` group, `glob` never filters. Lefthook docs (`docs/configuration/glob.md`): a glob is used only with a file template in `run` or a custom `files` command; only `pre-commit`/`pre-push` filter implicitly. So `bundle`, `migrate` and `client-dependencies` run after every pull in every repository. With `{files}` in `run`, lefthook filters the stdin list by the glob and skips the command when nothing matches (verified: `README.md` skipped, `Gemfile.lock` ran, `bundler/Gemfile` skipped). A deleted root `Gemfile` still reaches `{files}` (verified), so `bundle` also needs a root-Gemfile guard. Found while implementing: lefthook 2.1.12 splits `--files-from-stdin` on NUL only, so the newline list from `git diff-tree` reached it as one name and only globs ending in `*` matched; the nested calls need `git diff-tree -z`. Review round 1 found that `{files}` in a trailing shell comment is unsafe: a file name ending in a newline ends the comment and runs its next line. `{files}` is therefore passed as arguments to the no-op `:` (`": {files}; rails db:migrate"`), where lefthook's quoting keeps each name literal.

## Files that change

- `lefthook.yml` — top-level `no_auto_install: true` (with a one-line "why" comment); `{files}` added to the `run` of `bundle`, `migrate` and `client-dependencies` in the `migrations` group (with one "why" comment above the group, citing lefthook's glob rule); `-z` added to the nested `git diff-tree` in `post-merge` and `post-rewrite` (with a "why" comment); `bundle` gains a root-Gemfile guard in the style of `brakeman`'s `config/application.rb` check.
- `test/lefthook_global_hooks_sync_test.rb` — new. Real lefthook binary, real machine layout: `HOME` = temp dir, `core.hooksPath = ~/.config/git/hooks` in `$HOME/.config/git/config`, a separate `$HOME/.gitconfig` holding only `[user]`, `GIT_CONFIG_GLOBAL` and `XDG_CONFIG_HOME` unset, each hook in `$HOME/.config/git/hooks/` a link to a copy of the tracked shim under `$HOME/Developer/dotfiles/git/.config/git/hooks/`. Assertion helper: every hook is still a link, and every target's SHA-256 equals the tracked shim's.
- `test/lefthook_pull_hooks_test.rb` — new tests for criteria 4–6 (it already stubs and logs `bundle`, `rv`, `rails`, `yarn`). Remove `test_pull_does_not_overwrite_hook_scripts`: it runs on a layout where lefthook's own refusal applies (`GIT_CONFIG_GLOBAL` file holds `core.hooksPath`), so it passed while the bug was live; the new file covers the same behaviour on the real layout.

Read only: `git/.config/git/hooks/*`, `test/lefthook_local_hooks_test.rb` (binary lookup pattern: `LEFTHOOK_BIN`, `which lefthook`, rv glob — reuse the same three-step lookup and skip message).

## Order of work

Because Type is bugfix, all reproduction tests (steps 1, 2, 4, 6 and the step-8 test removal) are committed first in one commit, then the fixes (steps 3, 5, 7) follow without touching tests.

1. Write `test_pull_in_dotfiles_repo_keeps_global_hooks_linked` (criterion 1): puller clone carries a copy of the dotfiles `lefthook.yml` as its own config; push a change, pull. Run it alone. Watch it fail because the hooks are no longer links (message names the replaced hooks). If it passes, stop: the layout does not reproduce the bug yet — fix the test setup, not the config.
2. Write `test_rebase_in_dotfiles_repo_keeps_global_hooks_linked` (criterion 2: local commit + pull with `pull.rebase=true`, so `post-rewrite` runs) and `test_pull_in_repo_without_own_config_keeps_global_hooks_linked` (criterion 3: fallback through `LEFTHOOK_CONFIG`). Run; both red for the same reason.
3. Add `no_auto_install: true` to `lefthook.yml`. Run the new file: green. Commit (test + config).
4. Write `test_pull_touching_only_readme_runs_no_migrations` (criterion 4) and `test_pull_touching_only_nested_gemfile_does_not_bundle` (criterion 5). Run; red (all four commands logged).
5. Add `{files}` to the three `migrations` commands. Pass the nested file list with `git diff-tree -z`. Run the pull test file: new tests and existing ones green. Commit.
6. Write `test_pull_deleting_root_gemfile_does_not_bundle_install` (criterion 6: push a `Gemfile`, pull, clear the log, push its deletion, pull). Run; red (`bundle install` logged).
7. Add the root-Gemfile guard to `bundle`, on the `bundle install` branch only: a root `Gemfile.lock` still runs `rv ci` first, as criterion 7's `test_changed_gemfile_lock_triggers_rv_ci` pushes a lock file without a `Gemfile`. Green. Commit.
8. Refactor: remove `test_pull_does_not_overwrite_hook_scripts` (and the now-unused `digest` require / `hooks_checksums` helper if nothing else uses them); share nothing across test files unless a third copy appears. Commit.
9. Full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. Linters on touched files: `yamllint lefthook.yml`, `rubocop test/lefthook_global_hooks_sync_test.rb test/lefthook_pull_hooks_test.rb`. Re-read the full diff.
10. `review` skill, then push and open a PR against `origin` with the repo's PR template. Report: Etienne moves the four real files out of `~/.config/git/hooks/` and restows `git` (`stow -t "$HOME" -R --no-folding git`); name the residual risk (repositories with their own config) and the two ways to close it.

## Risks

- **CI runs the latest lefthook release, not 2.1.12** (`.github/workflows/dotfiles-tests.yml` fetches `releases/latest`). If a newer lefthook changes the hooks-path check or auto-sync, the regression tests may pass or fail for other reasons on CI. They must be red on 2.1.12 locally before the fix. No workflow change (needs Etienne's approval).
- **Linux CI and `$HOME/.gitconfig` precedence**: the bug depends on git reading only `~/.gitconfig` for `--global`. Git behaves the same on Linux; if CI's git differs, criteria 1–3 stay green there regardless, which hides nothing on macOS where the tests were red first.
- **Test env leaks**: the parent shell may set `GIT_CONFIG_GLOBAL`, `XDG_CONFIG_HOME`, `LEFTHOOK`, `LEFTHOOK_CONFIG`. The new test passes them as `nil` in the env hash so git and lefthook see only the temp layout.
- **`{files}` in `run`** puts file names on the command line. They go as arguments to the no-op `:`, never in a shell comment (a name ending in a newline would end the comment and run its next line; review round 1, tested). A YAML comment says why the template is there, so nobody removes it as dead text.
- **Rejected**: hand-written shims (lefthook renames unknown hooks to `.old` and still replaces the link); read-only hooks directory (blocks stow and git); ignoring the hook files in git (links and fallback still lost); adding `--no-auto-install` to each nested call (the config key covers every run that loads this config, including future nested calls); setting `core.hooksPath` in `~/.gitconfig` (out of scope: machine-local file, `core.hooksPath` change).
- **Out of scope**: anything under `claude/`, `codex/`, `agents/`, `herdr/`, other `docs/changes/` folders; `core.hooksPath`; running `stow`; `.github/workflows/`; the shims themselves; repositories with their own lefthook config; the Linux `[[ ]]` issue in `no-push-to-main`.

## Proof

- Criterion 1: pulling into the dotfiles repo leaves every global hook linked and unchanged → `test/lefthook_global_hooks_sync_test.rb` `test_pull_in_dotfiles_repo_keeps_global_hooks_linked`
- Criterion 2: finishing a rebase in the dotfiles repo leaves every global hook linked and unchanged → `test/lefthook_global_hooks_sync_test.rb` `test_rebase_in_dotfiles_repo_keeps_global_hooks_linked`
- Criterion 3: pulling into a repo without its own config leaves every global hook linked and unchanged → `test/lefthook_global_hooks_sync_test.rb` `test_pull_in_repo_without_own_config_keeps_global_hooks_linked`
- Criterion 4: a pull touching only `README.md` runs no migration command → `test/lefthook_pull_hooks_test.rb` `test_pull_touching_only_readme_runs_no_migrations`
- Criterion 5: a pull touching only `bundler/Gemfile` does not bundle → `test/lefthook_pull_hooks_test.rb` `test_pull_touching_only_nested_gemfile_does_not_bundle`
- Criterion 6: a pull deleting the root `Gemfile` does not run `bundle install` → `test/lefthook_pull_hooks_test.rb` `test_pull_deleting_root_gemfile_does_not_bundle_install` (the deleting commit also changes `README.md`: a pull that only deletes files already skips `migrations` with "no files for inspection", because the outer `post-merge` drops deleted files)
- Criterion 7: existing behaviour kept → `test/lefthook_pull_hooks_test.rb` `test_changed_gemfile_lock_triggers_rv_ci`, `test_new_migration_file_triggers_db_migrate`, `test_changed_schema_triggers_db_migrate`, `test_changed_yarn_lock_triggers_yarn_install`, `test_changed_package_lock_json_triggers_yarn_install`, `test_repo_with_own_lefthook_config_ignores_global_defaults`

- Written: `test/rv_ci_fallback_test.rb` `test_main_update_migration_hooks_pass_changed_files_to_nested_migration_hook` (lines 60 and 64) expects the nested `post-merge`/`post-rewrite` command without `-z`; update both expected strings to `git diff-tree -z -r --name-only --no-commit-id ORIG_HEAD HEAD | lefthook run migrations --files-from-stdin`.
- Review round 1, security: a pulled file name holding a newline and a command does not run that command → `test/lefthook_pull_hooks_test.rb` `test_pulled_gemfile_name_with_a_command_on_a_new_line_does_not_run_it`, `test_pulled_migration_name_with_a_command_on_a_new_line_does_not_run_it`. Fix: `{files}` moves out of the trailing shell comment into the arguments of a no-op `:` command, where the quoted names stay literal.
- Review round 1, nit: the sync tests also assert the after-pull hook ran (`assert_after_pull_hook_ran`, a `yarn.lock` change logs `yarn install`), so they cannot pass without running a hook.
- Review round 2, nits: spec requirement 5 narrowed to `bundle install`; a `lefthook.yml` comment says a very long file list splits over several runs; the lefthook binary lookup moves from four test files into `test/lefthook_binary.rb` (refactor, the four files stay green).

Per changed file, the unit tests expected:
- `lefthook.yml`: covered by the acceptance tests above; it is configuration, there is no smaller unit.

Test setup: temp dir per test; real lefthook binary (same lookup as the existing tests, skip when absent); stub `rails`, `yarn`, `rv`, `bundle` log to a file; bare origin + pusher + puller clones as in `lefthook_pull_hooks_test.rb`; for the sync tests, the machine layout described under "Files that change".

Reproduction: committed
