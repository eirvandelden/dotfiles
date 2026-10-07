# Plan: bi installs gems through rv

From `intent.md` (2026-10-07). Status: accepted.

## Context

`bi` is a zsh function in `zsh/.config/zsh/aliases.zsh:44`. It runs `bundle install`, `bin/rails app:update:bin` and a bare `solargraph`. Its `rv ci` path is commented out since March 2026. Agent shells do not load it: `type bi` is "not found" in both zsh and bash in a Claude shell today. The lefthook `migrations` → `bundle` command (`lefthook.yml:313`) has its own copy of the install logic. The installed rv is 0.7.1; `rv ci` is an alias of `rv clean-install` ("Clean install from a Gemfile.lock").

## Design decisions

- `bi` becomes an executable POSIX `sh` script at `ruby/.local/bin/bi`. `~/.local/bin` is on the PATH of every shell through `paths.zsh` (sourced from `.zshenv`), and the README already says "A script in `~/.local/bin` is available everywhere." The `ruby` package already holds the Ruby tooling (`.gemrc`, `.irbrc`, `.railsrc`) and is in `STOW`. No new stow package.
- The `bi()` function leaves `aliases.zsh`, so nothing shadows the script in interactive zsh.
- Steps, in order:
  1. No `${BUNDLE_GEMFILE:-Gemfile}` in the current directory: print `bi: no Gemfile in <dir>, nothing to install`, exit 0.
  2. `rv` not on the PATH: print `bi: rv is missing. Install rv, then run bi again.` to stderr, exit 1. This runs before anything else, so nothing installs.
  3. `bundle lock`. Bundler writes a missing lockfile and adds new Gemfile gems. On an up-to-date lockfile Bundler does not resolve: `Definition#resolve` returns the locked specs when `no_resolve_needed?` (Bundler 4.0.22, `lib/bundler/definition.rb:342`). So Bundler, not `bi`, decides whether the lockfile is stale.
  4. `MAKE="make --jobs $(getconf _NPROCESSORS_ONLN)" rv ci`. `getconf` works on macOS and Linux, unlike the old `sysctl -n hw.ncpu`; CI runs on Ubuntu.
  5. `rv ci` fails: print `bi: rv ci failed, installing with bundle install instead` to stderr, then `bundle install`. A failing fallback exits non-zero.
  6. Only when `bin/rails` is executable: `yes n | bin/rails app:update:bin`, then `solargraph gems`. Bare `solargraph` only prints its command list (0.58.1); `solargraph gems` caches documentation for the installed gems. Etienne chose it on 2026-10-07.
  7. `solargraph` not on the PATH (a project on a Ruby without the global gem): print `bi: solargraph not found, skipping` and exit 0, because the gems are installed. Etienne chose this on 2026-10-07.
- `bundle lock` always runs, and Bundler's own check decides whether to resolve. Etienne accepted this over a hand-written staleness check on 2026-10-07.
- The post-merge hook runs the full `bi`, Rails steps included, as the intent says. Etienne confirmed this on 2026-10-07.
- Binstubs: Thor answers "overwrite" on end of input (thor 1.5.0 `Shell::Basic#file_collision`: `when nil → return true`). A non-interactive run without answers clobbers a customised `bin/dev`. `yes n` answers "n" to every collision prompt, so every differing binstub stays and missing ones are added. The script has no `pipefail`, so the pipe's status is `bin/rails`'s.
- `set -eu`: any failing step stops `bi` with a non-zero exit.
- The Claude refusal extends `claude/.claude/hooks/consent-guard.rb`'s never-allowed path (the same path that refuses plain `--force`). Codex already runs this exact script from `config.toml`'s `[hooks]` table, so one change covers both tools. No consent marker unlocks it.
- The guard refuses a `bundle` word in command position (first word, or after `&&`, `||`, `|`, `;`, `(`, skipping `VAR=value` words) whose next word is missing, `install`, `i`, or a flag other than `-v`, `--version`, `-h`, `--help`. A word ending in `/bundle` (`bin/bundle`, `./bin/bundle`) counts as `bundle`. Quoted text stays one word, as today, so `git commit -m "run bundle install"` runs. `cat bin/bundle` and `which bundle` run, because `bundle` is not in command position.
- Message: `Blocked: install gems with bi, not bundle install. bi resolves the lockfile with Bundler and installs with rv (playbook rule 11).`
- Codex rules: one flat `forbidden` `prefix_rule` per form: `bundle install`, `bundle i`, `bin/bundle install`, `bin/bundle i`. Flat patterns, because `guard_parity_test.rb`'s rule parser reads patterns as flat JSON lists. The `bundle install` allow rule (`default.rules:143`) goes. Bare `bundle` and `bundle --jobs 4` have no rule: prefix rules cannot say "no more words". Checked with `codex execpolicy check`: a `["bundle"]` rule also forbids `bundle exec rake`. Those two forms rely on the shared hook.
- Playbook: a new bullet under rule 11 (Dependency management). `core-values.yml` repeats it under `workflow`.

## Integration points

- GNU Stow: the new file needs `stow -R -t "$HOME" ruby` once. Etienne runs it; agents never run stow (rule 12).
- Global git hooks: `git/.config/git/hooks` runs `lefthook.yml` from the dotfiles in every repository without its own lefthook config. The `bundle` command then runs `bi` from the hook's PATH.
- Claude `PreToolUse` and Codex `[[hooks.PreToolUse]]` both run `consent-guard.rb`; Codex also applies `codex/.codex/rules/default.rules`.
- Bundler (`bundle lock`, fallback `bundle install`), rv (`rv ci`), Rails (`app:update:bin`), solargraph.
- CI (`.github/workflows/dotfiles-tests.yml`) runs every `test/*_test.rb` on Ubuntu. The new test file is picked up without a workflow change.

## Files that change

- `ruby/.local/bin/bi` — new executable script, the steps above.
- `zsh/.config/zsh/aliases.zsh` — remove the `bi()` function. `be` and `audit` stay under `## Bundler`.
- `lefthook.yml` — `migrations.commands.bundle.run` becomes `: {files}` then `bi`. The comment about a deleted root Gemfile moves to say `bi` handles a missing Gemfile.
- `claude/.claude/hooks/consent-guard.rb` — gem-install refusal in the never-allowed path; header comment names it.
- `codex/.codex/rules/default.rules` — four forbidden rules with `match`/`not_match` examples; remove the `bundle install` allow rule; comment that bare `bundle` is the hook's job.
- `agents.md` — rule 11 bullet: install gems with `bi`, never `bundle install`, `bundle`, `bundle i` or `bin/bundle install`; a guard refuses them.
- `claude/.claude/core-values.yml` — one `workflow` line: install gems with `bi`, never `bundle install`.
- `claude/.claude/skills/worktree-first/SKILL.md` — Step 2 says `bi` instead of `bundle install`.
- `test/bi_test.rb` — new; every `bi` behaviour.
- `test/lefthook_pull_hooks_test.rb` — the real `bi` on PATH; the Gemfile-lock test pushes a Gemfile too and asserts the install went through `bi`.
- `test/rv_ci_fallback_test.rb` — remove `test_bi_uses_bundle_install_without_lockfile`, `test_bi_uses_bundle_install_with_lockfile`, `test_lefthook_uses_bundle_install_without_lockfile`, `test_lefthook_uses_rv_ci_with_lockfile`, and the helpers only they use. They assert the behaviour the accepted intent replaces; their successors are in `test/bi_test.rb` and `test/lefthook_pull_hooks_test.rb`.
- `test/consent_guard_test.rb` — refusal and pass-through cases.
- `test/guard_parity_test.rb` — install forms join `GUARDED_COMMANDS`; new forbidden and not-forbidden tests.
- `test/gem_install_rule_mirror_test.rb` — new; playbook, core values and worktree-first all name `bi`.

## Order of work

1. Write `test/bi_test.rb` `test_up_to_date_lockfile_installs_with_rv_ci_and_never_bundle_install`. Run it, watch it fail (no script).
2. Write the missing-lockfile and added-gem acceptance tests. Run them, watch them fail.
3. Create `ruby/.local/bin/bi` with steps 1–4. Run the three tests green.
4. Fallback, missing rv and no-Gemfile tests, red then green.
5. Rails-step tests (binstubs, solargraph, plain gem, customised `bin/dev`), red then green.
6. Reachability tests (bash, zsh, no `bi` function), red; remove `bi()` from `aliases.zsh`; green.
7. Rewrite the pull-hook Gemfile-lock test, red; change `lefthook.yml`; green. Remove the four superseded tests from `test/rv_ci_fallback_test.rb`.
8. Consent-guard tests, red; implement; green.
9. Guard-parity tests, red; change `default.rules`; green. Run `codex execpolicy check --rules codex/.codex/rules/default.rules` for each install form, `bundle exec rake` and `bundle update rails`.
10. Mirror test, red; edit `agents.md`, `core-values.yml`, `worktree-first/SKILL.md`; green.
11. Lint: `shellcheck ruby/.local/bin/bi`; `rubocop` on the changed Ruby files; `yamllint lefthook.yml claude/.claude/core-values.yml`; `markdownlint` on the changed Markdown. Full suite: every `test/*_test.rb`, stopping at the first failure.
12. Real-tool check, with `PATH="$PWD/ruby/.local/bin:$PATH"` instead of a restow: in a throwaway Rails app, run `bi` three times (no lockfile; gem added; up to date). Confirm `git diff --exit-code Gemfile.lock` after the up-to-date run, and that a customised `bin/dev` survives.

## Risks

- `bundle lock` may still rewrite an up-to-date lockfile, for example to add the local platform. `bundle install` did the same, so `bi` does not regress. The real-Bundler acceptance test asserts a byte-identical lockfile.
- rv may ignore a work repository's `BUNDLE_BUILD__*` flag. The native build then fails, and `bi` falls back to `bundle install` with a warning, by design.
- Until Etienne restows `ruby`, `bi` is not on any PATH. Agents get "command not found", and the post-merge hook fails loudly instead of installing.
- A pull that changes a Gemfile now also boots the Rails app for `app:update:bin`. With `yes n`, a missing binstub is added as a new untracked file.
- The guard reads words, not shell. `bash -c "bundle install"`, `eval` and `xargs bundle` pass. It steers agents; it is not a sandbox.
- Rejected: a separate install-guard hook (two more config entries and parity checks for one rule); a hand-written staleness check (misses version, source and platform changes Bundler sees); `bin/rails app:update:bin --skip` (only Rails ≥ 7.1 parses it; on older Rails `app:update:bin` is a rake task that rejects unknown flags); a Codex `["bundle"]` rule (also forbids `bundle exec`).

## Proof

- Up-to-date lockfile installs with `rv ci`, no `bundle install` → `test/bi_test.rb` `test_up_to_date_lockfile_installs_with_rv_ci_and_never_bundle_install`
- No lockfile: Bundler writes it, then `rv ci` → `test/bi_test.rb` `test_missing_lockfile_is_written_by_bundler_before_rv_ci`
- Added gem is locked, then installed with `rv ci` → `test/bi_test.rb` `test_gem_added_to_gemfile_is_locked_then_installed_with_rv_ci`
- Failing `rv ci` warns, then `bundle install` → `test/bi_test.rb` `test_failing_rv_ci_warns_and_falls_back_to_bundle_install`
- No rv: error names rv, nothing installs → `test/bi_test.rb` `test_missing_rv_stops_with_an_error_and_installs_nothing`
- No Gemfile: nothing to install, success → `test/bi_test.rb` `test_directory_without_gemfile_has_nothing_to_install`
- Rails app regenerates binstubs and runs solargraph; plain gem only installs → `test/bi_test.rb` `test_rails_app_regenerates_binstubs_and_runs_solargraph_after_install`, `test_plain_gem_only_installs`
- Customised `bin/dev` kept, no prompt → `test/bi_test.rb` `test_customised_binstub_is_kept_without_a_prompt`
- Claude and Codex agents can run `bi` → `test/bi_test.rb` `test_bi_runs_by_name_from_non_interactive_bash_and_zsh`, `test_aliases_no_longer_define_a_bi_function`; plus `command -v bi` in a Claude and a Codex session after the restow
- Install forms refused with a message naming `bi` → `test/consent_guard_test.rb` `test_gem_install_forms_are_refused_with_bi_advice`; `test/guard_parity_test.rb` `test_gem_install_forms_are_forbidden_for_codex`
- `bundle exec rake` and `bundle update rails` still run → `test/consent_guard_test.rb` `test_non_install_bundler_commands_run`; `test/guard_parity_test.rb` `test_non_install_bundler_commands_are_not_forbidden_for_codex`
- Post-merge installs through `bi` → `test/lefthook_pull_hooks_test.rb` `test_changed_gemfile_lock_installs_through_bi`

Per changed file, the unit tests expected:

- `ruby/.local/bin/bi`: `test_failing_fallback_exits_non_zero`, `test_bundle_gemfile_names_the_gemfile_to_look_for`, `test_missing_rv_is_reported_before_bundler_runs`, `test_rails_app_runs_solargraph_gems`, `test_missing_solargraph_is_skipped_with_a_note`.
- `consent-guard.rb`: `test_consent_does_not_unlock_a_gem_install`, `test_bundle_named_as_an_argument_is_not_an_install` (`cat bin/bundle`, `which bundle`), `test_quoted_prose_mentioning_bundle_install_runs`, `test_bundle_version_and_help_run`, `test_install_after_a_separator_or_env_assignment_is_refused`.
- `default.rules`: `test_no_allow_rule_begins_with_a_guarded_command` covers the new entries.
- `lefthook.yml`: `test_pull_deleting_root_gemfile_does_not_bundle_install` keeps passing with the real `bi`.
- `agents.md`, `core-values.yml`, `worktree-first/SKILL.md`: `test_the_playbook_tells_agents_to_install_gems_with_bi`, `test_the_core_values_repeat_it`, `test_worktree_first_installs_gems_with_bi`.

Test setup: each `bi` test builds a project in `Dir.mktmpdir` with `HOME` there and a PATH of stubs plus `/usr/bin:/bin`. Stubs log their argv to one file: `rv` (fails on request, or without `Gemfile.lock`), `solargraph`, `bin/rails`. The `bin/rails` stub imitates Thor: it reads one line, overwrites `bin/dev` on end of input or `Y`, keeps it on `n`. `bundle` is a logging shim; the three lockfile tests make it `exec` the real Bundler through `RbConfig.ruby`, so the restricted PATH needs no Ruby. Those tests use path gems and no `source`, so Bundler stays offline.

## Out of scope

`bundle exec`, `bundle update <gem>`, `bundle add`, `bundle lock` and other non-install commands; vendored skills' `bundle install` text; installs inside project scripts such as `bin/setup`; installing or upgrading rv; running `stow`.

---
Domain skills applied: dotfiles-maintenance, dependencies.
