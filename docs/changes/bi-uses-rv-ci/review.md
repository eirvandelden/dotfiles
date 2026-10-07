# Review: bi-uses-rv-ci

## Round 1 — 2026-10-07T19:29Z — 94623717

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default policy (`claude/.claude/skills/new-repo-setup/references/REVIEW.md`) applies. Full suite green (every `test/*_test.rb`). `shellcheck`, `rubocop`, `yamllint` and `markdownlint` clean on the changed files. `codex execpolicy check` gives `forbidden` for `bundle install --jobs 4`, `bundle i`, `bin/bundle install` and `bin/bundle i`, and no decision for `bundle exec rake` and `bundle update rails`.

- [ ] Important: The guard misses an install that is not after `&&`, `||`, `|`, `;` or `(`. `Shellwords.split` turns a newline into plain whitespace, and shell keywords and prefix commands do not reset command position. Each of these exits 0 (probed against the guard): `cd app` + newline + `bundle install`; `if [ -f Gemfile ]; then bundle install; fi`; `for d in a b; do bundle install; done`; `{ bundle install; }`; `sleep 1 & bundle install`; `env bundle install`; `command bundle install`; `time bundle install`. Intent acceptance criterion: "When a Claude or Codex agent runs `bundle install` … the command is refused". A multi-line command and an `if … then` block are ordinary agent shell, and the plan's accepted escapes are only `bash -c`, `eval` and `xargs`. Newline, `then`/`do`/`else`/`{`/`&` and `env`/`command`/`time`/`exec` positions need a refusal test each. — `claude/.claude/hooks/consent-guard.rb:40` →
- [ ] Nit: The post-merge hook can now leave `Gemfile.lock` modified after a pull. `bi` always runs `bundle lock`, and Bundler adds the local platform to a lockfile whose `PLATFORMS` lists neither it nor `ruby` (probed: a lockfile with only `x86_64-linux` gained `arm64-darwin-23`; a lockfile with `ruby` stays unchanged). The old hook ran only `rv ci` with a lockfile and never wrote it. The plan's risk note compares only with the old `bi`'s `bundle install`, not with the old hook. — `ruby/.local/bin/bi:18` →
- [ ] Nit: A Bundler global flag before a non-install subcommand counts as an install. `bundle --no-color exec rake` and `bundle -V exec rake` are refused with "install gems with bi", which is the wrong advice for an exec. It errs towards refusing, so it is safe, but the message misleads. — `claude/.claude/hooks/consent-guard.rb:66` →
- [ ] Nit: `bi` looks for the Gemfile only in the current directory. From a subdirectory such as `app/models`, it prints "nothing to install" and exits 0. Bundler (and the old `bi`) walks up and finds the project's Gemfile. This matches the intent's wording, but the silent success hides a skipped install. — `ruby/.local/bin/bi:8` →
- [ ] Nit: Plan step 12 (throwaway Rails app, three `bi` runs, `git diff --exit-code Gemfile.lock`, customised `bin/dev` kept) has no recorded evidence in the commits or the change folder. The reviewer confirmed the Thor half against real Thor: `yes n` gives `skip bin/dev`, and end of input gives `force bin/dev`. Record the real-app run before the pull request. — `docs/changes/bi-uses-rv-ci/plan.md:69` →

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
