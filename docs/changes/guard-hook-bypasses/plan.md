# Plan: Consent guard asks before any way of skipping the git hooks

From `intent.md` (2026-10-07). Status: accepted.

## Context

The consent guard (`claude/.claude/hooks/consent-guard.rb`) is a PreToolUse hook. Claude runs it from `claude/.claude/settings.json`, Codex from the inline `[[hooks.PreToolUse]]` table in `codex/.codex/config.toml`. Both run `"$HOME/.claude/hooks/consent-guard.rb"`. It reads the tool call as JSON on stdin, splits the command into words with `Shellwords.split`, and exits 2 with a reason on stderr when the command needs consent. A command that starts with `I_HAVE_USER_CONSENT=1 ` goes through. Today it asks only for the word `--no-verify` among the ways to skip the git hooks. This change makes it ask for every route that `intent.md` lists, and adds Codex prefix rules for the routes a prefix rule can express.

## Design decisions

1. **New module `HookBypass` in `claude/.claude/hooks/hook_bypass.rb`.** Same shape as `remote_matcher.rb`: a `module` with `module_function`, no gems beyond the standard library. One public method, `HookBypass.reason(words)`, returns a refusal reason or `nil`. `consent-guard.rb` adds `require_relative "hook_bypass"` and calls it first in `consentable_reason`, in place of the inline `--no-verify` line. The `--no-verify` check moves into the module because it is the same family. This keeps the guard small, as its header comment intends.
2. **No restow needed.** `~/.claude/hooks/*.rb` are per-file stow links into the main checkout, so `hook_bypass.rb` gets no link of its own until Etienne restows. `require_relative` resolves the real path of the running script, so the guard finds the new file next to its real self. Probed 2026-10-07 on Ruby 4.0.7: a script run through a symlink loaded a sibling file that exists only beside the real script. Never run `stow` (playbook rule 12).
3. **Word pieces, inside `HookBypass` only.** `Shellwords.split` leaves a shell operator attached to a word: `git commit -n; echo` gives the word `-n;`, and `lefthook install&&echo` gives `install&&echo`. `HookBypass` splits a word on `;`, `&`, `|`, `(` and `)` only when the word holds no whitespace, and drops empty pieces. A word that holds whitespace came from quotes: it is prose and stays whole, so `git commit -m "--no-verify; hooks still matter"` goes through. The other checks (plain `--force`, GitHub posts, deploys, the remote allowlist) keep the raw words, so their behaviour does not change (intent: out of scope).
4. **Program words match by basename.** `File.basename(piece) == "git"` (and `"lefthook"`), so `/usr/bin/git commit -n` and `bin/lefthook install` count.
5. **Route rules.** Each rule checks which pieces are present. Every rule errs towards asking.
   - `--no-verify`: a piece equal to `--no-verify`. Same meaning as today.
   - `git commit -n`: a commit piece plus a short-option cluster that holds `n`, matched by `/\A-[A-Za-z]*n[A-Za-z]*\z/`. That catches `-n`, `-nm` and `-an`; git expands bundled short options (probe: `git commit -nm c` skipped a failing hook). A commit piece is `commit` or `ci`, the alias `git/.config/git/config` defines for `commit`; `HookBypass::COMMIT_WORDS` holds both. `git push -n origin feature` has no commit piece, so it goes through.
   - `LEFTHOOK`: a piece that starts with `LEFTHOOK=` and holds no whitespace, whatever the value. This covers inline, `export`, `env` and `typeset -x` forms. lefthook treats `0` and `false` as off, the global shims only `0`, so the guard does not list values. `LEFTHOOK=1` asks too; nobody writes it. A quoted sentence such as `"LEFTHOOK=0 is refused"` holds whitespace, so it is prose and goes through.
   - `LEFTHOOK_EXCLUDE`: a piece that starts with `LEFTHOOK_EXCLUDE=` and holds no whitespace. lefthook reads the value as a comma-separated list, so a real value needs no space.
   - `core.hooksPath`: compared case-insensitively, because git config keys are (probe: `git -c CORE.HOOKSPATH=/dev/null commit` skipped a failing hook).
     - A piece `GIT_CONFIG_KEY_<n>=core.hooksPath`, or a piece that starts with `GIT_CONFIG_PARAMETERS=` and whose value contains `core.hookspath`. No `git` piece is needed: an `export` alone arms every later command.
     - With a `git` piece: a piece that starts with `core.hookspath=` (the `-c <key>=<value>` form, and `--config-env <key>=<var>`), or with `--config-env=core.hookspath=`. `--config-env` is a way to set the key (probe: `NOPE=/dev/null git --config-env=core.hooksPath=NOPE commit` skipped a failing hook), so "every way to set" covers it.
     - With `git` and `config` pieces: a bare `core.hookspath` piece, unless the piece right before it is a read: `--get`, `--get-all`, `--get-regexp` or `get`. The check runs per occurrence, so `git config --get core.hooksPath; git config core.hooksPath x` asks. The bare read `git config core.hooksPath` asks too; that is the safe direction. Without a `config` piece, `rg core.hooksPath` goes through.
     - With `git` and `config` pieces: a section operation on `core`, which unsets `core.hooksPath` without naming it. That is a `core` piece (any case) plus one of `--remove-section`, `remove-section`, `--rename-section` or `rename-section`.
     - The `core.hookspath=` and `GIT_CONFIG_PARAMETERS=` prefixes may hold whitespace: a hooks path can contain a space, and `GIT_CONFIG_PARAMETERS` is a space-separated list. Prose rarely starts with either word.
   - Plumbing: a `git` piece plus a `commit-tree` or `update-ref` piece.
   - lefthook: a `lefthook` piece with an `install` or `uninstall` piece somewhere after the first `lefthook` piece. `lefthook dump` goes through, and so does `brew install lefthook`, where `install` comes first.
6. **One reason per route family.** Each reason names the route and says why it matters, for example: "git commit -n is --no-verify: it skips the git hooks, which are what keep commits off main (playbook rule 19)." The `--no-verify` reason keeps the text `--no-verify` (an existing test asserts `/no-verify/`). The guard keeps adding its "Ask the user first … I_HAVE_USER_CONSENT=1" tail.
7. **Consent stays as it is.** `command.start_with?(CONSENT_MARKER)` unlocks every hook-skipping route.
8. **Codex prefix rules, only where the route starts with fixed words.** A prefix rule matches a command's leading tokens exactly. Rules go into `codex/.codex/rules/default.rules` with `decision = "prompt"`, each with `match` and, where useful, `not_match` examples, which Codex validates when it loads the file:
   - `["git", ["commit", "ci"], "-n"]`, with `not_match` `git push -n origin x`.
   - The existing `["git", "commit", "--no-verify"]` rule becomes `["git", ["commit", "ci"], "--no-verify"]`, so the alias prompts too.
   - `["git", "commit-tree"]` and `["git", "update-ref"]`.
   - `["lefthook", ["install", "uninstall"]]`.
   - `core.hooksPath` writes, with `KEY = ["core.hooksPath", "core.hookspath"]` and `U = ["--global", "--local", "--system", "--worktree", "--unset", "--unset-all", "--replace-all", "--add", "set", "unset"]`: `["git", "config", KEY]`, `["git", "config", U, KEY]` and `["git", "config", U, U, KEY]`. `not_match` holds `git config --get core.hooksPath`.
   - Section operations on `core`, with `S = ["--remove-section", "--rename-section", "remove-section", "rename-section"]`: `["git", "config", S, "core"]`, `["git", "config", U, S, "core"]` and `["git", "config", S, U, "core"]`. Probed 2026-10-07: `codex execpolicy check` matched `git config --rename-section core x` and `git ci -n -m x` against such rules.
   - A list inside a pattern is a set of alternatives for that position. Probed 2026-10-07 with codex-cli 0.160.1: `codex execpolicy check` matched `["git", "config", ["--global", "--local"], "core.hooksPath"]` against `git config --local core.hooksPath x`.
   - No rule for the routes a prefix cannot express: the `LEFTHOOK`, `LEFTHOOK_EXCLUDE` and `GIT_CONFIG_*` assignments come before the program word and carry a varying value; `git -c` and `--config-env` put key and value in one token; `-n` after other flags is not a prefix. The hook covers all of them in Codex too. The comment above the guarded rules says so.
9. **The parity test reads alternatives.** `test/guard_parity_test.rb`'s `rules` expands each pattern into every concrete pattern (`Array#product` over its positions) before the two existing checks run. `GUARDED_COMMANDS` gains the new routes (`git commit -n`, `git ci -n`, `git ci --no-verify`, `git config core.hooksPath`, `git config --global --unset core.hooksPath`, `git config --remove-section core`, `git commit-tree`, `git update-ref`, `lefthook install`, `lefthook uninstall`), so each needs a prompt rule and no allow rule may begin with one. The existing allow rule `["git", "commit"]` stays: execpolicy applies the most restrictive matching decision, so `git commit -n` still prompts.
10. **The commit alias stays in step.** A new test reads the `[alias]` section of `git/.config/git/config` and asserts that every alias whose expansion starts with `commit` is in `HookBypass::COMMIT_WORDS`. A new commit alias then fails the suite instead of opening a route.

## Integration points

- Claude's PreToolUse hook (matcher `Bash`) and Codex's `[[hooks.PreToolUse]]` (matcher `^Bash$`) run the same script. No wiring change; `test_codex_runs_the_same_consent_guard_command_as_claude_for_shell_commands` keeps them equal.
- The live hook is the main checkout's file, through `~/.claude/hooks/consent-guard.rb`. The worktree's guard takes effect only after merge. Verification runs the worktree's script directly.
- `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb` on Ruby 3.4. The module and tests must run on 3.4, not only on the local 4.0.
- lefthook's `guard-parity` pre-push command runs `test/guard_parity_test.rb` whenever the rules, `config.toml`, `settings.json` or `claude/.claude/hooks/*.rb` change.
- `codex/.codex/rules/default.rules` is the live, stowed rules file. Codex appends `allow` rules to it on "always allow"; the parity test guards against an allow rule that loosens a guarded route.
- Agent workflows that now ask: `lefthook install` and `lefthook uninstall` (the `dotfiles-maintenance` and `new-repo-setup` skills already say never run `lefthook install`). Tests that call `git -c core.hooksPath=/dev/null` or `git update-ref` do so inside Ruby, not as an agent's command, so they are unaffected.

## Files that change

- `claude/.claude/hooks/hook_bypass.rb` (new): `HookBypass.reason(words)`, the piece splitting, and one predicate per route family.
- `claude/.claude/hooks/consent-guard.rb`: `require_relative "hook_bypass"`; `consentable_reason` returns `HookBypass.reason(words)` first and drops its inline `--no-verify` check. One header sentence says the guard also asks before every way of skipping the git hooks it can see in the words.
- `codex/.codex/rules/default.rules`: the prompt rules from decision 8, and the comment block above the guarded rules updated to name the new routes and the routes left to the hook.
- `test/consent_guard_test.rb`: one acceptance test per criterion; the Codex-payload parity test gains two new routes.
- `test/hook_bypass_test.rb` (new): unit tests of `HookBypass.reason` for the edge spellings, and the commit-alias test from decision 10.
- `test/guard_parity_test.rb`: pattern expansion and the new `GUARDED_COMMANDS`.

## Order of work

1. Write `test_commit_n_waits_for_consent` in `test/consent_guard_test.rb`. Run it with `ruby -Itest test/consent_guard_test.rb -n test_commit_n_waits_for_consent` and watch it fail: exit 0 instead of 2.
2. Create `hook_bypass.rb` with the piece splitting, the `--no-verify` check and the `commit -n` check. Wire it into `consent-guard.rb`. Run the whole guard test file: the new test and every existing test pass.
3. Add the remaining acceptance tests one criterion at a time, in the order of `## Proof`. Run each, watch it fail (or, for a "goes through" criterion, pass as a guard against regression), then add the route to `HookBypass` until it passes.
4. Write `test/hook_bypass_test.rb` for the edge spellings in decisions 3 and 5, and the commit-alias test from decision 10. Fix `HookBypass` for any that fail.
5. Extend the Codex-payload test in `test/consent_guard_test.rb` with `git commit -n -m x` and `LEFTHOOK=0 git commit -m x`.
6. In `test/guard_parity_test.rb`, add the new routes to `GUARDED_COMMANDS`. Run it and watch `test_every_guarded_command_has_a_prompt_or_forbidden_rule_under_the_hook` fail. Teach `rules` to expand alternatives; the existing tests stay green. Add the rules from decision 8. Run the test until it passes.
7. Check that Codex loads the rules and decides as intended, and record the output: `codex execpolicy check --rules codex/.codex/rules/default.rules <tokens>` for `git commit -n -m x` (prompt), `git ci -n -m x` (prompt), `git config --global --unset core.hooksPath` (prompt), `git config --global remove-section core` (prompt), `git config --get core.hooksPath` (no prompt rule), `git push -n origin feature` (allow only), `lefthook install` (prompt) and `lefthook dump` (no rule).
8. Verify as a human would: in a scratch repository with a failing pre-commit hook, pipe a Claude payload and a Codex payload for each acceptance command into the worktree's `claude/.claude/hooks/consent-guard.rb`. Record exit status and stderr. Write the payloads to a file in the scratchpad first: the live guard reads the agent's own command line, and a bare `--no-verify` word in it asks.
9. Run `rubocop` and `ruby -c` on every touched Ruby file. Then run the full suite: `set -o pipefail; for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`.

## Risks

- More questions. Harmless `core.hooksPath` writes, plumbing and `lefthook install` now ask. The intent accepted this trade.
- Piece splitting reaches into a quoted word without whitespace. `"a;--no-verify"` now asks. Accepted: prose has spaces, and the error is a question, not a miss.
- A `LEFTHOOK` or `LEFTHOOK_EXCLUDE` value that holds a space, such as `LEFTHOOK_EXCLUDE="a, b"`, reads as prose and goes through. Accepted: lefthook's exclude list is comma-separated, and the prose constraint needs the whitespace rule.
- Only the `ci` alias is known. A commit alias defined outside `git/.config/git/config` (a repository's own config) is not seen; the alias test keeps the global file in step.
- The `-n` cluster rule asks for `git log -n 5 && git commit -m x` and for `git commit -mn` (message "n"). Accepted: the error is a question, not a miss.
- A bare read, `git config core.hooksPath`, asks. Use `--get` or `get` to read without a question.
- A malformed rule or a failing `match` example stops Codex from loading `default.rules`. Step 7 catches it before commit.
- CI runs Ruby 3.4. Avoid Ruby 4.0-only syntax and methods.
- Rejected: parsing shell syntax to find each command's real arguments. The guard's header rejects it on purpose, and the intent keeps the guard word-based.
- Rejected: a Codex rule for every `git -c`. It would prompt for `git -c color.ui=false log` and every other override; the hook already covers the hooks-path case.
- Rejected: piece splitting for the other checks. It would change the `--force` and GitHub checks, which the intent keeps as they are.

## Out of scope

- Everything `intent.md` lists as out of scope: routes hidden in scripts, `sh -c`, `eval` or hook-file edits; lefthook's auto-sync during `lefthook run`; the unborn-branch hole; the other checks; the work repositories' lefthook setup.
- Routes found while planning that the intent does not list: abbreviated `--no-verify` (`--no-veri`), `LEFTHOOK_BIN` and `LEFTHOOK_CONFIG`, and `GIT_CONFIG_GLOBAL`, `XDG_CONFIG_HOME` or `HOME` overrides that drop the global `core.hooksPath` (probe: each of `GIT_CONFIG_GLOBAL=/dev/null` and `XDG_CONFIG_HOME=/nonexistent` made `git config --get core.hooksPath` return nothing). They go to Etienne as decisions, not into this change.
- Restowing, or any change to `settings.json`, `config.toml` or the global shims in `git/.config/git/hooks/`.

## Proof

- `git commit -n -m "x"` waits for consent → `test/consent_guard_test.rb` `test_commit_n_waits_for_consent`
- `git push -n origin feature` goes through → `test/consent_guard_test.rb` `test_a_push_dry_run_runs_without_a_question`
- `LEFTHOOK=0 git commit -m "x"`, `LEFTHOOK=false git commit -m "x"` and `export LEFTHOOK=0; git commit -m "x"` wait → `test/consent_guard_test.rb` `test_turning_lefthook_off_waits_for_consent`
- `LEFTHOOK_EXCLUDE=no-push-to-main git commit -m "x"` waits → `test/consent_guard_test.rb` `test_excluding_a_lefthook_command_waits_for_consent`
- `git -c core.hooksPath=/dev/null commit -m "x"` waits → `test/consent_guard_test.rb` `test_overriding_core_hooks_path_for_one_command_waits_for_consent`
- `core.hooksPath` through `GIT_CONFIG_PARAMETERS` or `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_0` waits → `test/consent_guard_test.rb` `test_setting_core_hooks_path_through_the_environment_waits_for_consent`
- `git config core.hooksPath /dev/null` and `git config --global --unset core.hooksPath` wait → `test/consent_guard_test.rb` `test_writing_or_unsetting_core_hooks_path_waits_for_consent`; the section form `git config --global remove-section core` → `test/consent_guard_test.rb` `test_removing_or_renaming_the_core_section_waits_for_consent`
- `git config --get core.hooksPath` goes through → `test/consent_guard_test.rb` `test_reading_core_hooks_path_runs_without_a_question`
- `git commit-tree HEAD^{tree} -p HEAD -m "x"` and `git update-ref refs/heads/main <sha>` wait → `test/consent_guard_test.rb` `test_plumbing_that_skips_the_commit_hooks_waits_for_consent`
- `lefthook install` and `lefthook uninstall` wait → `test/consent_guard_test.rb` `test_installing_or_uninstalling_lefthook_waits_for_consent`
- `lefthook dump` goes through → `test/consent_guard_test.rb` `test_lefthook_dump_runs_without_a_question`
- `I_HAVE_USER_CONSENT=1 git commit -n -m "x"` goes through → `test/consent_guard_test.rb` `test_commit_n_runs_once_the_user_has_consented`
- `git commit -m "explain why LEFTHOOK=0 is refused"` goes through → `test/consent_guard_test.rb` `test_a_message_naming_a_hook_switch_runs_without_a_question`
- Codex prompts for each route a prefix rule can express, and the parity test passes → `test/guard_parity_test.rb` `test_every_guarded_command_has_a_prompt_or_forbidden_rule_under_the_hook` and `test_no_allow_rule_begins_with_a_guarded_command`, over the extended `GUARDED_COMMANDS`; the Codex hook path → `test/consent_guard_test.rb` `test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload`; plus the recorded `codex execpolicy check` output from step 7.

Per changed file, the unit tests expected:

- `test/hook_bypass_test.rb` (`HookBypass.reason`): `test_an_ordinary_commit_has_no_reason`, `test_no_verify_still_has_a_reason`, `test_an_n_inside_a_short_option_cluster_has_a_reason` (`-nm`, `-an`), `test_the_ci_alias_with_n_has_a_reason` (`git ci -n -m x`), `test_every_commit_alias_in_the_git_config_is_a_commit_word`, `test_quoted_prose_that_starts_with_a_switch_has_no_reason` (`git commit -m "LEFTHOOK=0 is refused"`, `git commit -m "--no-verify; hooks still matter"`), `test_a_shell_operator_against_the_word_does_not_hide_it` (`git commit -n; echo`, `lefthook install&&echo`), `test_git_and_lefthook_match_by_basename` (`/usr/bin/git commit -n`, `bin/lefthook install`), `test_core_hooks_path_matches_in_any_case` (`git -c CORE.HOOKSPATH=/dev/null commit`), `test_config_env_has_a_reason` (both `--config-env` forms), `test_git_config_set_and_unset_subcommands_have_a_reason`, `test_git_config_reads_have_no_reason` (`--get-all`, `get`), `test_a_read_does_not_hide_a_later_write`, `test_a_bare_key_without_a_read_flag_has_a_reason`, `test_searching_for_the_key_has_no_reason` (`rg core.hooksPath`), `test_installing_lefthook_itself_has_no_reason` (`brew install lefthook`), `test_an_exported_exclude_has_a_reason` (`export LEFTHOOK_EXCLUDE=x`).
- `test/guard_parity_test.rb`: the two existing coverage tests now hold for `git config --global --unset core.hooksPath`, which only an alternatives rule covers, so the expansion is proven through them.
- `claude/.claude/hooks/consent-guard.rb`: covered by the acceptance tests above; every existing test in `test/consent_guard_test.rb` stays green.

Test setup: the guard tests keep their helpers. `setup` makes a temporary repository with an `origin` remote and a temporary `HOME`; `run_guard` and `run_codex_guard` pipe a payload into the script. `test/hook_bypass_test.rb` loads the module with `require_relative "../claude/.claude/hooks/hook_bypass"` and passes `Shellwords.split(command)`. No network, no real hooks, no lefthook run.

---
Domain skills applied: dotfiles-maintenance (stow layout, rule 12), object-oriented-design (module boundary), ruby-style (method shape). No conflicts between them.

## Critique

### Round 1 (codex exec -p terra)

- `git ci -n` skips the hooks through the global alias `ci = commit` in `git/.config/git/config`, and the plan matched only `commit` → fixed (decision 5 treats `ci` as a commit word, decision 8 adds `ci` to the `-n` and `--no-verify` rules, decision 10 adds a test that keeps `HookBypass::COMMIT_WORDS` in step with the config's commit aliases)
- `GIT_CONFIG_GLOBAL=/dev/null`, `HOME` and `XDG_CONFIG_HOME` overrides hide the global `core.hooksPath`; include them or amend the intent → dismissed: the accepted intent lists every in-scope route and these are not among them; auto mode turns a change to agreed behaviour into a decision for Etienne, so the plan lists them under Out of scope and the report raises them
- `git config remove-section core` and `rename-section core` unset `core.hooksPath` without naming the key → fixed (decision 5 adds the section operations on `core`, decision 8 adds Codex rules for them, Proof adds `test_removing_or_renaming_the_core_section_waits_for_consent`)
- Splitting every word on shell operators breaks the quoted-prose constraint, and a `LEFTHOOK=` prefix match catches the quoted sentence `"LEFTHOOK=0 is refused"` → fixed (decision 3 splits only words without whitespace, the `LEFTHOOK` and `LEFTHOOK_EXCLUDE` rules require a piece without whitespace, Proof adds `test_quoted_prose_that_starts_with_a_switch_has_no_reason`)
