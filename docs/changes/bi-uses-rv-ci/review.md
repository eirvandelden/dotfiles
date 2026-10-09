# Review: bi-uses-rv-ci

## Round 1 — 2026-10-07T19:29Z — 94623717

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default policy (`claude/.claude/skills/new-repo-setup/references/REVIEW.md`) applies. Full suite green (every `test/*_test.rb`). `shellcheck`, `rubocop`, `yamllint` and `markdownlint` clean on the changed files. `codex execpolicy check` gives `forbidden` for `bundle install --jobs 4`, `bundle i`, `bin/bundle install` and `bin/bundle i`, and no decision for `bundle exec rake` and `bundle update rails`.

- [ ] Important: The guard misses an install that is not after `&&`, `||`, `|`, `;` or `(`. `Shellwords.split` turns a newline into plain whitespace, and shell keywords and prefix commands do not reset command position. Each of these exits 0 (probed against the guard): `cd app` + newline + `bundle install`; `if [ -f Gemfile ]; then bundle install; fi`; `for d in a b; do bundle install; done`; `{ bundle install; }`; `sleep 1 & bundle install`; `env bundle install`; `command bundle install`; `time bundle install`. Intent acceptance criterion: "When a Claude or Codex agent runs `bundle install` … the command is refused". A multi-line command and an `if … then` block are ordinary agent shell, and the plan's accepted escapes are only `bash -c`, `eval` and `xargs`. Newline, `then`/`do`/`else`/`{`/`&` and `env`/`command`/`time`/`exec` positions need a refusal test each. — `claude/.claude/hooks/consent-guard.rb:40` → fixed (consent-guard: find gem installs in every command position)
- [ ] Nit: The post-merge hook can now leave `Gemfile.lock` modified after a pull. `bi` always runs `bundle lock`, and Bundler adds the local platform to a lockfile whose `PLATFORMS` lists neither it nor `ruby` (probed: a lockfile with only `x86_64-linux` gained `arm64-darwin-23`; a lockfile with `ruby` stays unchanged). The old hook ran only `rv ci` with a lockfile and never wrote it. The plan's risk note compares only with the old `bi`'s `bundle install`, not with the old hook. — `ruby/.local/bin/bi:18` →
- [ ] Nit: A Bundler global flag before a non-install subcommand counts as an install. `bundle --no-color exec rake` and `bundle -V exec rake` are refused with "install gems with bi", which is the wrong advice for an exec. It errs towards refusing, so it is safe, but the message misleads. — `claude/.claude/hooks/consent-guard.rb:66` → fixed (consent-guard: find gem installs in every command position)
- [ ] Nit: `bi` looks for the Gemfile only in the current directory. From a subdirectory such as `app/models`, it prints "nothing to install" and exits 0. Bundler (and the old `bi`) walks up and finds the project's Gemfile. This matches the intent's wording, but the silent success hides a skipped install. — `ruby/.local/bin/bi:8` → fixed (bi: install for the nearest Gemfile at or above the directory)
- [ ] Nit: Plan step 12 (throwaway Rails app, three `bi` runs, `git diff --exit-code Gemfile.lock`, customised `bin/dev` kept) has no recorded evidence in the commits or the change folder. The reviewer confirmed the Thor half against real Thor: `yes n` gives `skip bin/dev`, and end of input gives `force bin/dev`. Record the real-app run before the pull request. — `docs/changes/bi-uses-rv-ci/plan.md:69` → fixed (Record evidence of bi in a real Rails app)

### Compliance

Files: every file the plan names changed as described; nothing unplanned. The four removed `test/rv_ci_fallback_test.rb` tests are the ones the accepted plan names, with successors in `test/bi_test.rb` and `test/lefthook_pull_hooks_test.rb`. `test_changed_gemfile_lock_triggers_rv_ci` became `test_changed_gemfile_lock_installs_through_bi` and now also refutes `bundle install`. No other test was weakened, skipped or deleted. Every unit test the Proof list names exists.

Acceptance criteria:

- Up-to-date lockfile installs with `rv ci`, no `bundle install` → `test/bi_test.rb` `test_up_to_date_lockfile_installs_with_rv_ci_and_never_bundle_install`.
- No lockfile: Bundler writes it, then `rv ci` → `test_missing_lockfile_is_written_by_bundler_before_rv_ci`.
- Added gem is locked, then installed with `rv ci` → `test_gem_added_to_gemfile_is_locked_then_installed_with_rv_ci`.
- Failing `rv ci` warns, then `bundle install` → `test_failing_rv_ci_warns_and_falls_back_to_bundle_install`.
- No rv: error, nothing installs → `test_missing_rv_stops_with_an_error_and_installs_nothing`.
- No Gemfile: nothing to install, success → `test_directory_without_gemfile_has_nothing_to_install`.
- Rails app: binstubs and solargraph; plain gem only installs → `test_rails_app_regenerates_binstubs_and_runs_solargraph_after_install`, `test_plain_gem_only_installs`.
- Customised `bin/dev` kept, no prompt → `test_customised_binstub_is_kept_without_a_prompt` (stub Thor; real-app evidence missing, see the Nit above).
- Claude and Codex agents can run `bi` → `test_bi_runs_by_name_from_non_interactive_bash_and_zsh`, `test_aliases_no_longer_define_a_bi_function`. Partial: the test puts the repository's `ruby/.local/bin` on PATH by hand. The `command -v bi` check in a Claude and a Codex session waits on `stow -R -t "$HOME" ruby`; `command -v bi` finds nothing in an agent shell today.
- Install forms refused with a message naming `bi` → `test/consent_guard_test.rb` `test_gem_install_forms_are_refused_with_bi_advice`, `test/guard_parity_test.rb` `test_gem_install_forms_are_forbidden_for_codex`. Gap: multi-line and keyword-position forms, see the Important finding.
- `bundle exec rake` and `bundle update rails` still run → `test_non_install_bundler_commands_run`, `test_non_install_bundler_commands_are_not_forbidden_for_codex`.
- Post-merge installs through `bi` → `test/lefthook_pull_hooks_test.rb` `test_changed_gemfile_lock_installs_through_bi`.

Security: nothing found. The new refusal sits on the never-allowed path, so no consent marker unlocks it, and the Codex change only removes an allow rule.

## Round 2 — 2026-10-08T12:08Z — 4cb61a73

Whole branch against `origin/main`, with focus on the three commits since round 1. No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default policy applies. Every `test/*_test.rb` passes except `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`. The global `no-push-to-main` hook in `~/.config/git/hooks` refuses that test's commit on `main` in its temporary repository. This branch touches neither the test nor the hook, so it is not a finding here. `shellcheck`, `rubocop`, `yamllint` and `markdownlint` are clean on the changed files. Round 1's Nit about a modified `Gemfile.lock` after a pull is still open.

- [ ] Important: A line continuation before `bundle` hides the install from the guard. `SHELL_PIECE` keeps a backslash and its newline as one escape, and `Shellwords.split` returns that escape as a word of its own (`"\\\n"`). That word takes command position, so `bundle` becomes an argument. Probed, each exits 0: `cd app && \` newline, two spaces, `bundle install`; `cd app && \` newline `bundle install`; `RAILS_ENV=test \` newline, two spaces, `bundle install`. A continuation after `&&` is ordinary multi-line agent shell, and the plan accepts only `bash -c`, `eval` and `xargs` as escapes. `test_install_in_any_command_position_is_refused` has no continuation case. — `claude/.claude/hooks/consent-guard.rb:56` → fixed (consent-guard: catch installs behind continuations, comments and wrappers)
- [ ] Important: `bi` searches for a Gemfile past the repository root. From a Git repository without a Gemfile under a directory with one, `bi` runs `bundle lock`, `rv ci` and `bin/rails app:update:bin` in that parent directory. Probed with stubs: a Gemfile-less repository at `main/.worktrees/no-gemfile` ran all three in `main`. Worktrees live under `.worktrees/` in the main checkout, so a pull that deletes a worktree's Gemfile makes the post-merge hook lock, install and add binstubs in the main checkout. The `lefthook.yml:316` comment ("bi reports a missing Gemfile and exits 0") then does not hold. The intent's criterion "In a directory without a Gemfile, `bi` prints that there is nothing to install" fails for that repository root. `test_pull_deleting_root_gemfile_does_not_bundle_install` refutes only `bundle install`, and its temporary directory has no Gemfile above it, so it cannot see this. Bundler searches up the same way, but the old hook looked only at the repository root. — `ruby/.local/bin/bi:7` → fixed (bi: stop the Gemfile search at the Git work tree root)
- [ ] Nit: A prefix command with an option argument, or a wrapper outside `COMMAND_PREFIXES`, still hides an install. Probed, each exits 0: `timeout 600 bundle install`, `sudo bundle install`, `nice -n 10 bundle install`, `env -u FOO bundle install`. Of these, `timeout` is the form an agent writes most. — `claude/.claude/hooks/consent-guard.rb:48` → fixed (consent-guard: catch installs behind continuations, comments and wrappers)
- [ ] Nit: An apostrophe in a comment line hides a later install. In `# don't forget the gems` newline `bundle install`, the `'` opens an unmatched quote. `separate_operators` then keeps the line break, and the `command.split` fallback treats it as a space. Probed: exits 0; the same command without the apostrophe exits 2. — `claude/.claude/hooks/consent-guard.rb:56` → fixed (consent-guard: catch installs behind continuations, comments and wrappers)
- [ ] Nit: `bundle cache`, `bundle package` and `bundle pack` install gems, but the guard lets them run. Bundler 4.1's `CLI::Cache#run` calls `CLI::Install#run` first (`bundler/cli/cache.rb`). `BUNDLER_COMMANDS` lists all three, and the intent allows only non-install commands. — `claude/.claude/hooks/consent-guard.rb:45` → fixed (consent-guard: catch installs behind continuations, comments and wrappers)

### Compliance, round 2

Since round 1, `consent-guard.rb` splits at operators and line breaks, strips heredoc bodies, and allows a list of known Bundler commands. The plan's design refused only a missing next word, `install`, `i` or a flag; the new rule also refuses any unknown word after `bundle`. That answers round 1's Nit and errs towards refusing, so it is not a finding. `bi` now searches upward for the Gemfile (second Important finding). `evidence.md` records plan step 12.

Tests were only added or extended. `test_gem_install_forms_are_refused_with_bi_advice` gained two forms. `test_install_in_any_command_position_is_refused`, `test_bundle_install_in_messages_heredocs_and_lookups_runs`, `test_bundler_options_before_a_non_install_command_run` and `test_subdirectory_installs_for_the_project_above_it` are new. No test was weakened, skipped or deleted. Every test the Proof list names exists.

Acceptance criteria: as in round 1, with these changes.

- No Gemfile: nothing to install, success → `test_directory_without_gemfile_has_nothing_to_install`. Gap: a Gemfile-less repository under a Ruby project, see the second Important finding.
- Customised `bin/dev` kept, no prompt → `test_customised_binstub_is_kept_without_a_prompt`, plus `evidence.md` (Rails 8.1.4, `skip bin/dev`, `bin/dev` byte-identical).
- Install forms refused with a message naming `bi` → the round 1 tests plus `test_install_in_any_command_position_is_refused`. Gap: line continuations, see the first Important finding.
- Claude and Codex agents can run `bi` → still partial. `command -v bi` in an agent session waits on `stow -R -t "$HOME" ruby`.

Security: nothing new. The post-merge hook now boots the pulled app for `app:update:bin`, but its `migrate` command already runs pulled code.

## Round 3 — 2026-10-09T08:58Z — 5238fc53

Whole branch against `origin/main`, with focus on `1f0d251c` (guard) and `0542e0e4` (`bi`). No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default policy applies. Every `test/*_test.rb` passes except `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, the same global `no-push-to-main` refusal as in round 2. `shellcheck` and `rubocop` are clean on the changed files. Round 1's Nit about a modified `Gemfile.lock` after a pull is still open.

Both round 2 Important findings hold when probed. The guard refuses each round 2 continuation, prefix, comment and `bundle cache` form. `bi` prints "nothing to install" and runs nothing in a Gemfile-less `git worktree add` worktree under a checkout with a Gemfile: from the worktree root, from a subdirectory, through a symlinked path, and with a hook-style `GIT_DIR` set.

- [ ] Nit: A prefix flag that follows another prefix flag still hides an install. After `:option_value`, any word becomes `:prefix`, so a second flag's value is read as the command, and `bundle` becomes an argument. Probed, each exits 0: `sudo -E -u root bundle install`, `env -i -u FOO bundle install`, `timeout --preserve-status -s KILL 60 bundle install`. One flag, or a flag after a value (`sudo -u root -H bundle install`), is refused. A flag in `:option_value` position needs the same handling as in `:prefix` position, plus a refusal test. — `claude/.claude/hooks/consent-guard.rb:109` → fixed (consent-guard: read a flag after a prefix flag as a flag)

### Compliance, round 3

Since round 2, the guard drops a line continuation and a comment before it splits words, treats `sudo` and `timeout` as prefixes, skips a prefix's option value and a duration, and refuses `bundle cache`, `package` and `pack`. `bundle cache` installs first, so refusing it matches the intent's "every install form". The Codex rules have no `bundle cache` entry; the shared hook covers both tools. `bi` stops its Gemfile search at `git rev-parse --show-toplevel`; the `lefthook.yml` comment ("bi reports a missing Gemfile and exits 0") now holds for a worktree.

Tests were only added or extended. `test_git_repository_without_gemfile_stops_at_its_root` is new. `test_gem_install_forms_are_refused_with_bi_advice`, `test_install_in_any_command_position_is_refused` and `test_bundle_install_in_messages_heredocs_and_lookups_runs` gained cases. No test was weakened, skipped or deleted. Every test the Proof list names exists.

Acceptance criteria: as in round 2, with these changes.

- No Gemfile: nothing to install, success → `test_directory_without_gemfile_has_nothing_to_install`, `test_git_repository_without_gemfile_stops_at_its_root`. Round 2's gap is closed.
- Install forms refused with a message naming `bi` → the earlier tests plus the new continuation, prefix and comment cases. Remaining gap: chained prefix flags, see the Nit above.
- Claude and Codex agents can run `bi` → still partial. `command -v bi` in an agent session waits on `stow -R -t "$HOME" ruby`.

Security: nothing new. The guard changes only widen what it refuses, and `bi` now runs in fewer directories.

## Round 4 — 2026-10-09T21:00Z — f54421c3

Whole branch against `origin/main`, with focus on `98e93031` (guard). No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default policy applies. Every `test/*_test.rb` passes except `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, the same global `no-push-to-main` refusal as in rounds 2 and 3. `shellcheck` and `rubocop` are clean on the changed files. Round 1's Nit about a modified `Gemfile.lock` after a pull is still open.

Round 3's Nit holds when probed. The guard refuses `sudo -E -u root bundle install`, `env -i -u FOO bundle install` and `timeout --preserve-status -s KILL 60 bundle install`. It also refuses `nice -n -5`, `timeout -k 5 60`, `env -u FOO -u BAR`, `sudo --user root`, `sudo -u root --` and `env -C app` before `bundle install`. `sudo -u root bundle exec rake`, `env -i bundle exec rake`, `command -v bundle` and `timeout 10m bundle exec rspec` still run.

- [ ] Nit: `rv run bundle install` runs `bundle install`, and the guard lets it run. `rv run` is rv 0.7.1's "Run a command or script with Ruby" (probed: `rv run bundle --version` prints Bundler's version). `rv` is not in `COMMAND_PREFIXES`, so `bundle` is an argument. In an rv-only setup this is the form an agent writes when Ruby is not on PATH. `arch -arm64 bundle install` and `caffeinate -i bundle install` pass the same way. The plan accepts only `bash -c`, `eval` and `xargs` as escapes. — `claude/.claude/hooks/consent-guard.rb:49` →

### Compliance, round 4

Since round 3, `next_position` reads a flag in option-value position as a new flag, not as the value. `test_install_in_any_command_position_is_refused` gained the three round 3 forms. No test was weakened, skipped or deleted. Every test the Proof list names exists.

Acceptance criteria: as in round 3, with these changes.

- Install forms refused with a message naming `bi` → the earlier tests plus the chained prefix flag cases. Round 3's gap is closed. Remaining gap: `rv run` and other wrappers outside the prefix list, see the Nit above.
- Claude and Codex agents can run `bi` → still partial. `command -v bi` in an agent session waits on `stow -R -t "$HOME" ruby`.

Security: nothing new. The change only widens what the guard refuses.
