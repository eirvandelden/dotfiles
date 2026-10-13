# Plan: Consent guard asks before any way of skipping the git hooks

From `intent.md` (2026-10-07, amended 2026-10-12). Status: draft.

## Context

The consent guard (`claude/.claude/hooks/consent-guard.rb`) is a PreToolUse hook. Claude runs it from `claude/.claude/settings.json`, Codex from the inline `[[hooks.PreToolUse]]` table in `codex/.codex/config.toml`. Both run `"$HOME/.claude/hooks/consent-guard.rb"`. It reads the tool call as JSON on stdin and splits the command into words with `Shellwords.split` (falling back to `command.split` on an unmatched quote). It exits 2 with a reason on stderr when the command needs consent. A command that starts with `I_HAVE_USER_CONSENT=1 ` goes through, except a plain `--force` push, which nothing unlocks.

Today the guard asks only for the word `--no-verify` among the ways to skip the git hooks. Its word checks (`never_allowed_reason`, `posts_to_github?`, `deploys?`, `destroys_database?`) see a word with a shell operator glued to it, such as `--force;`, as a different word. Only the remote check (`disallowed_remote`, with `push_windows` and `window`) already splits on `SHELL_OPERATOR` itself.

This change makes the guard ask for every route `intent.md` lists, makes every word check see chained commands split, and adds Codex prefix rules for the routes a prefix rule can express. The plan was re-verified on 2026-10-12 against the code after the branch was rebased onto `origin/main`.

## Design decisions

1. **New module `CommandPieces` in `claude/.claude/hooks/command_pieces.rb`.** Same shape as `remote_matcher.rb`: a `module` with `module_function`, standard library only. `CommandPieces.of(words)` splits each word on `;`, `&`, `|`, `(`, `)` and `` ` `` and drops empty pieces, but only when the word holds no whitespace. A word that holds whitespace came from quotes: it is prose and stays whole, so `git commit -m "--no-verify; hooks still matter"` goes through. `(`, `)` and the backtick are in the set so `$(git commit -n)` gives the pieces `$`, `git`, `commit`, `-n`, and `` `git commit -n` `` gives `git`, `commit`, `-n`; that only adds questions. A separate module because two callers use it: the guard's existing checks and `HookBypass`.
2. **Every word check reads pieces; the remote check keeps words.** The guard computes `command_pieces = CommandPieces.of(command_words)` once. `never_allowed_reason`, `posts_to_github?`, `deploys?` and `destroys_database?` take the pieces; `HookBypass.reason` takes the pieces and the raw command (decision 6). `consentable_reason(words, pieces, working_directory)` passes the raw words to `disallowed_remote`, because its `window` needs the operators to find where each `push` ends; it already splits on them. So `git push --force origin x; echo done` gives the piece `--force` and is refused, while `git push --force-with-lease origin x; echo done` gives `--force-with-lease` and goes through. The checks keep their logic; only their input changes (intent: other checks keep their behaviour except the split).
3. **New module `HookBypass` in `claude/.claude/hooks/hook_bypass.rb`.** One public method, `HookBypass.reason(pieces, command)`, returns a refusal reason or `nil`. `consent-guard.rb` adds `require_relative "command_pieces"` and `require_relative "hook_bypass"`, and calls `HookBypass.reason(pieces, command)` first in `consentable_reason`, in place of the inline `--no-verify` line. The `--no-verify` check moves into the module because it is the same family. This keeps the guard small, as its header comment intends.
4. **No restow needed.** `~/.claude/hooks/*.rb` are per-file stow links into the main checkout (checked 2026-10-12: `consent-guard.rb` and `remote_matcher.rb` are links, the new files have none). `require_relative` resolves the real path of the running script, so the guard finds the new files next to its real self. Probed 2026-10-07 on Ruby 4.0.7: a script run through a symlink loaded a sibling file that exists only beside the real script. Never run `stow` (playbook rule 12).
5. **Program words match by basename.** `File.basename(piece) == "git"` (and `"lefthook"`), so `/usr/bin/git commit -n` and `bin/lefthook install` count.
6. **Route rules.** Each rule checks which pieces are present. Every rule errs towards asking.
   - `--no-verify` and its abbreviations: a piece that is a prefix of `--no-verify` and at least as long as `--no-v`. Probed 2026-10-12 with git 2.54.0: `git commit --no-veri` and `--no-verif` skip a failing hook; `--no-v`, `--no-ve` and `--no-ver` are ambiguous with `--no-verbose` and git refuses them. Asking for those too is the safe direction and covers commands with a different option set (`push`, `merge`, `am`). The reason keeps the text `--no-verify` (an existing test asserts `/no-verify/`).
   - `git commit -n`: a `git` piece, a commit piece and a short-option cluster that holds `n`, matched by `/\A-[A-Za-z]*n[A-Za-z]*\z/`. That catches `-n`, `-nm` and `-an`; git expands bundled short options (probe 2026-10-07: `git commit -nm c` skipped a failing hook). A commit piece is `commit` or `ci`, the alias `git/.config/git/config` defines for `commit`; `HookBypass::COMMIT_WORDS` holds both. `git push -n origin feature` has no commit piece, so it goes through.
   - lefthook switches: a piece that starts with `LEFTHOOK=`, `LEFTHOOK_EXCLUDE=`, `LEFTHOOK_BIN=` or `LEFTHOOK_CONFIG=` and holds no whitespace, whatever the value. This covers inline, `export`, `env` and `typeset -x` forms. lefthook treats `0` and `false` as off, the global shims only `0`, so the guard lists no values; `LEFTHOOK=1` asks too. The global shims run `$LEFTHOOK_BIN` in place of lefthook when it is set (`git/.config/git/hooks/pre-commit`, `call_lefthook`). A quoted sentence such as `"LEFTHOOK=0 is refused"` holds whitespace, so it is prose and goes through. One exception: a switch piece that holds whitespace still counts when the raw command holds the switch name followed directly by `="` or `='`. That is an assignment with a quoted value, such as `LEFTHOOK_CONFIG="/tmp/hook dir/x.yml"` or `LEFTHOOK_EXCLUDE="a, b"`; prose that names a switch quotes the sentence, not the value.
   - `core.hooksPath`: compared case-insensitively, because git config keys are (probe 2026-10-07: `git -c CORE.HOOKSPATH=/dev/null commit` skipped a failing hook).
     - A piece `GIT_CONFIG_KEY_<n>=core.hooksPath`, or a piece that starts with `GIT_CONFIG_PARAMETERS=` and whose value contains `core.hookspath`. No `git` piece is needed: an `export` alone arms every later command.
     - With a `git` piece: a piece that starts with `core.hookspath=` (the `-c <key>=<value>` form, and `--config-env <key>=<var>`), or with `--config-env=core.hookspath=`. `--config-env` is a way to set the key (probe 2026-10-07: `NOPE=/dev/null git --config-env=core.hooksPath=NOPE commit` skipped a failing hook).
     - With `git` and `config` pieces: a bare `core.hookspath` piece, unless the piece right before it is a read: `--get`, `--get-all`, `--get-regexp` or `get`. The check runs per occurrence, so `git config --get core.hooksPath; git config core.hooksPath x` asks. The bare read `git config core.hooksPath` asks too; that is the safe direction. Without a `config` piece, `rg core.hooksPath` goes through.
     - With `git` and `config` pieces: a section operation on `core`, which unsets `core.hooksPath` without naming it. That is a `core` piece (any case) plus one of `--remove-section`, `remove-section`, `--rename-section` or `rename-section`.
     - The `core.hookspath=` and `GIT_CONFIG_PARAMETERS=` prefixes may hold whitespace: a hooks path can contain a space, and `GIT_CONFIG_PARAMETERS` is a space-separated list. Prose rarely starts with either word.
   - Plumbing: a `git` piece plus a `commit-tree` or `update-ref` piece.
   - lefthook: a `lefthook` piece with an `install` or `uninstall` piece somewhere after the first `lefthook` piece. `lefthook dump` goes through, and so does `brew install lefthook`, where `install` comes first.
7. **One reason per route family.** Each reason names the route and says why it matters, for example: "git commit -n is --no-verify: it skips the git hooks, which are what keep commits off main (playbook rule 19)." The guard keeps adding its "Ask the user first … I_HAVE_USER_CONSENT=1" tail.
8. **Consent stays as it is.** `command.start_with?(CONSENT_MARKER)` unlocks every hook-skipping route.
9. **Codex prefix rules, only where the route starts with fixed words.** A prefix rule matches a command's leading tokens exactly; a list inside a pattern is a set of alternatives for that position. Rules go into `codex/.codex/rules/default.rules` with `decision = "prompt"`, each with `match` and, where useful, `not_match` examples, which Codex validates when it loads the file:
   - `["git", ["commit", "ci"], "-n"]`, with `not_match` `git push -n origin x`.
   - The existing `["git", "commit", "--no-verify"]` and `["git", "push", "--no-verify"]` rules become one rule, `["git", ["commit", "ci", "push", "merge", "pull", "am"], ["--no-verify", "--no-verif", "--no-veri"]]`. Each of those subcommands takes `--no-verify`; the hook already asks for the word in any position.
   - `["git", "commit-tree"]` and `["git", "update-ref"]`.
   - `["lefthook", ["install", "uninstall"]]`.
   - `core.hooksPath` writes, with `KEY = ["core.hooksPath", "core.hookspath"]` and `U = ["--global", "--local", "--system", "--worktree", "--unset", "--unset-all", "--replace-all", "--add", "set", "unset"]`: `["git", "config", KEY]`, `["git", "config", U, KEY]` and `["git", "config", U, U, KEY]`. `not_match` holds `git config --get core.hooksPath`.
   - Section operations on `core`, with `S = ["--remove-section", "--rename-section", "remove-section", "rename-section"]`: `["git", "config", S, "core"]`, `["git", "config", U, S, "core"]` and `["git", "config", S, U, "core"]`.
   - Probed 2026-10-12 with codex-cli 0.162.1: `codex execpolicy check` matched `git config --unset core.hooksPath` against `["git", "config", ["--global", "--unset"], ["core.hooksPath", "core.hookspath"]]`, and loaded a rule whose `match` was `git ci -n -m x` and `not_match` was `git push -n origin x`.
   - No rule for the routes a prefix cannot express: the `LEFTHOOK*` and `GIT_CONFIG_*` assignments come before the program word and carry a varying value; `git -c` and `--config-env` put key and value in one token; `-n` after other flags is not a prefix. Codex's rules documentation says Codex splits a plain chain (`;`, `&&`, `||`, `|`) and applies the rules to each part, and treats a command with assignments, redirections or a background `&` as one opaque shell call that no prefix rule matches. The hook covers all of these in Codex too. The comment above the guarded rules says so.
   - `codex execpolicy check` takes tokens and does no shell parsing (probed 2026-10-12: `zsh -lc "git status; git commit -n -m x"` matched no rule against a `["git", ["commit", "ci"], "-n"]` rule). Step 8 therefore checks direct tokens only; the chain behaviour is Codex's own and the hook backs it up.
10. **The parity test reads alternatives.** `test/guard_parity_test.rb`'s `rules` regex (`pattern\s*=\s*(\[.*?\])\s*,\s*decision`) already captures a nested list, because the lazy match only stops at a `]` followed by `, decision`; `JSON.parse` reads it. `rules` then expands each pattern into every concrete pattern (`Array#product` over its positions) before the existing checks run. `GUARDED_COMMANDS` gains the new routes (`git commit -n`, `git ci -n`, `git ci --no-verify`, `git commit --no-veri`, `git config core.hooksPath`, `git config --global --unset core.hooksPath`, `git config --remove-section core`, `git commit-tree`, `git update-ref`, `lefthook install`, `lefthook uninstall`), so each needs a prompt rule and no allow rule may begin with one. The existing allow rule `["git", "commit"]` stays: execpolicy applies the most restrictive matching decision, so `git commit -n` still prompts.
11. **The commit alias stays in step.** A new test reads the `[alias]` section of `git/.config/git/config` and asserts that every alias whose expansion starts with `commit` is in `HookBypass::COMMIT_WORDS`. A new commit alias then fails the suite instead of opening a route.

## Integration points

- Claude's PreToolUse hook (matcher `Bash`) and Codex's `[[hooks.PreToolUse]]` (matcher `^Bash$`) run the same script. No wiring change; `test_codex_runs_the_same_consent_guard_command_as_claude_for_shell_commands` keeps them equal.
- The live hook is the main checkout's file, through `~/.claude/hooks/consent-guard.rb`. The worktree's guard takes effect only after merge. Verification runs the worktree's script directly.
- `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb` on Ruby 3.4. The modules and tests must run on 3.4, not only on the local Ruby 4.0.
- `lefthook-local.yml`'s parity command runs `ruby -Itest test/guard_parity_test.rb` when the rules, `config.toml`, `settings.json` or `claude/.claude/hooks/*.rb` change.
- `codex/.codex/rules/default.rules` is the live, stowed rules file. Codex appends `allow` rules to it on "always allow"; the parity test guards against an allow rule that loosens a guarded route.
- Agent workflows that now ask: `lefthook install` and `lefthook uninstall` (the `dotfiles-maintenance` and `new-repo-setup` skills already say never run `lefthook install`). Tests that call `git -c core.hooksPath=…` or `git update-ref` do so inside Ruby, not as an agent's command, so they are unaffected.

## Files that change

- `claude/.claude/hooks/command_pieces.rb` (new): `CommandPieces.of(words)`.
- `claude/.claude/hooks/hook_bypass.rb` (new): `HookBypass.reason(pieces, command)`, `COMMIT_WORDS`, and one predicate per route family.
- `claude/.claude/hooks/consent-guard.rb`: the two `require_relative` lines; `command_pieces` computed once; the word checks take pieces; `consentable_reason` takes words and pieces, returns `HookBypass.reason(pieces)` first and drops its inline `--no-verify` check. One header sentence says the guard also asks before every way of skipping the git hooks it can see in the words, and that chained commands are read as separate words.
- `codex/.codex/rules/default.rules`: the prompt rules from decision 9, and the comment block above the guarded rules updated to name the new routes and the routes left to the hook.
- `test/consent_guard_test.rb`: one acceptance test per criterion; the Codex-payload parity test gains two new routes.
- `test/command_pieces_test.rb` (new): unit tests of `CommandPieces.of`.
- `test/hook_bypass_test.rb` (new): unit tests of `HookBypass.reason` for the edge spellings, and the commit-alias test from decision 11.
- `test/guard_parity_test.rb`: pattern expansion and the new `GUARDED_COMMANDS`.

## Order of work

1. Write `test_commit_n_waits_for_consent` in `test/consent_guard_test.rb`. Run it with `ruby -Itest test/consent_guard_test.rb -n test_commit_n_waits_for_consent` and watch it fail: exit 0 instead of 2.
2. Write `test/command_pieces_test.rb`, watch it fail, then create `command_pieces.rb` until it passes.
3. Create `hook_bypass.rb` with the `--no-verify` check and the `commit -n` check. Wire both modules into `consent-guard.rb`, with every word check reading pieces. Run the whole guard test file: the new test and every existing test pass.
4. Add the remaining acceptance tests one criterion at a time, in the order of `## Proof`. Run each, watch it fail (or, for a "goes through" criterion, pass as a guard against regression), then add the route to `HookBypass` until it passes.
5. Write `test/hook_bypass_test.rb` for the edge spellings in decisions 5 and 6, and the commit-alias test from decision 11. Fix `HookBypass` for any that fail.
6. Extend the Codex-payload test in `test/consent_guard_test.rb` with `git commit -n -m x` and `LEFTHOOK=0 git commit -m x`.
7. In `test/guard_parity_test.rb`, add the new routes to `GUARDED_COMMANDS`. Run it and watch `test_every_guarded_command_has_a_prompt_or_forbidden_rule_under_the_hook` fail. Teach `rules` to expand alternatives; the existing tests stay green. Add the rules from decision 9. Run the test until it passes.
8. Check that Codex loads the rules and decides as intended, and record the output: `codex execpolicy check --rules codex/.codex/rules/default.rules <tokens>` for `git commit -n -m x` (prompt), `git ci -n -m x` (prompt), `git commit --no-veri -m x` (prompt), `git merge --no-verify x` (prompt), `git config --global --unset core.hooksPath` (prompt), `git config --global remove-section core` (prompt), `git config --get core.hooksPath` (no prompt rule), `git push -n origin feature` (allow only), `lefthook install` (prompt) and `lefthook dump` (no rule).
9. Verify as a human would: in a scratch repository with a failing pre-commit hook, pipe a Claude payload and a Codex payload for each acceptance command into the worktree's `claude/.claude/hooks/consent-guard.rb`. Record exit status and stderr. Write the payloads to a file in the scratchpad first: the live guard reads the agent's own command line, and a bare `--no-verify` word in it asks.
10. Run `rubocop` and `ruby -c` on every touched Ruby file. Then run the full suite: `set -o pipefail; for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`.

## Risks

- More questions. Harmless `core.hooksPath` writes, plumbing and `lefthook install` now ask. The intent accepted this trade.
- Piece splitting reaches into a quoted word without whitespace. `"a;--no-verify"` now asks, and `--body 'x;comment'` now gives a `comment` piece. Accepted: prose has spaces, and the error is a question, not a miss.
- Splitting changes what the old checks see. `db:drop;` now asks, and `kamal app logs|grep deploy` now gives a `deploy` piece and asks. Each change is towards asking, which the intent wants.
- The `--force` check stays word-presence: `git push --force-with-lease a; git push --force b` still passes it, as it does today on `main`. The intent keeps that check's logic; only the split is new.
- A `LEFTHOOK*` value that holds a space is caught only through the `="` or `='` check on the raw command. A value with an escaped space, `LEFTHOOK_CONFIG=/tmp/a\ b.yml`, holds whitespace after splitting and has no quote, so it goes through. Accepted: rare, and the prose constraint needs the whitespace rule.
- A one-word quoted message, `git commit -m "LEFTHOOK=0"`, holds no whitespace and asks. Accepted: it is not prose, and the error is a question, not a miss.
- Only the `ci` alias is known. A commit alias defined outside `git/.config/git/config` (a repository's own config) is not seen; the alias test keeps the global file in step.
- The `-n` cluster rule asks for `git log -n 5 && git commit -m x` and for `git commit -mn` (message "n"). Accepted: the error is a question, not a miss.
- A bare read, `git config core.hooksPath`, asks. Use `--get` or `get` to read without a question.
- A malformed rule or a failing `match` example stops Codex from loading `default.rules`. Step 8 catches it before commit.
- CI runs Ruby 3.4. Avoid Ruby 4.0-only syntax and methods.
- Rejected: parsing shell syntax to find each command's real arguments. The guard's header rejects it on purpose, and the intent keeps the guard word-based.
- Rejected: a Codex rule for every `git -c`. It would prompt for `git -c color.ui=false log` and every other override; the hook already covers the hooks-path case.
- Rejected: feeding pieces to `disallowed_remote`. Its windows need the operators to find where a `push` ends, and it already splits on them.
- Rejected: asking for every `LEFTHOOK_*=` assignment. `LEFTHOOK_VERBOSE` and `LEFTHOOK_QUIET` change no checks; the intent names four switches.

## Out of scope

- Everything `intent.md` lists as out of scope: routes hidden in scripts, `sh -c`, `eval` or hook-file edits; lefthook's auto-sync during `lefthook run`; the unborn-branch hole; the other checks' logic; `GIT_CONFIG_GLOBAL=`, `XDG_CONFIG_HOME=` and `HOME=` overrides; the work repositories' lefthook setup.
- Commands that create a commit without running `pre-commit`, such as `git cherry-pick` (probed 2026-10-12: it committed past a failing `pre-commit`). The intent does not list them; they go to Etienne as a decision.
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
- `git commit --no-veri -m "x"` waits → `test/consent_guard_test.rb` `test_an_abbreviated_no_verify_waits_for_consent`
- `LEFTHOOK_BIN=true git commit -m "x"` and `LEFTHOOK_CONFIG=/tmp/empty.yml git commit -m "x"` wait → `test/consent_guard_test.rb` `test_replacing_lefthook_or_its_config_waits_for_consent`
- `git push --force origin feature; echo done` is refused outright → `test/consent_guard_test.rb` `test_a_plain_force_push_chained_to_another_command_is_refused`
- `git push --force-with-lease origin feature; echo done` goes through → `test/consent_guard_test.rb` `test_a_force_with_lease_push_chained_to_another_command_is_allowed`
- `git commit -m "explain why LEFTHOOK=0 is refused"` goes through → `test/consent_guard_test.rb` `test_a_message_naming_a_hook_switch_runs_without_a_question`
- Codex prompts for each route a prefix rule can express, and the parity test passes → `test/guard_parity_test.rb` `test_every_guarded_command_has_a_prompt_or_forbidden_rule_under_the_hook` and `test_no_allow_rule_begins_with_a_guarded_command`, over the extended `GUARDED_COMMANDS`; the Codex hook path → `test/consent_guard_test.rb` `test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload`; plus the recorded `codex execpolicy check` output from step 8.

Per changed file, the unit tests expected:

- `test/command_pieces_test.rb` (`CommandPieces.of`): `test_a_glued_operator_splits_the_word` (`-n;`, `install&&echo`, `a|b`), `test_parentheses_and_backticks_split_the_word` (`$(git`, `-n)`, `` `git ``, `` -n` ``), `test_a_word_with_whitespace_stays_whole` (`"--no-verify; hooks still matter"`), `test_empty_pieces_are_dropped` (`;`, `&&`), `test_plain_words_pass_through`.
- `test/hook_bypass_test.rb` (`HookBypass.reason`): `test_an_ordinary_commit_has_no_reason`, `test_no_verify_still_has_a_reason`, `test_every_unambiguous_abbreviation_of_no_verify_has_a_reason` (`--no-veri`, `--no-verif`), `test_a_short_prefix_that_is_not_no_verify_has_no_reason` (`--no-edit`, `--no`), `test_an_n_inside_a_short_option_cluster_has_a_reason` (`-nm`, `-an`), `test_the_ci_alias_with_n_has_a_reason` (`git ci -n -m x`), `test_every_commit_alias_in_the_git_config_is_a_commit_word`, `test_quoted_prose_that_starts_with_a_switch_has_no_reason` (`git commit -m "LEFTHOOK=0 is refused"`, `git commit -m "LEFTHOOK_BIN=true is refused"`), `test_a_shell_operator_against_the_word_does_not_hide_it` (`git commit -n; echo`, `lefthook install&&echo`), `test_git_and_lefthook_match_by_basename` (`/usr/bin/git commit -n`, `bin/lefthook install`), `test_core_hooks_path_matches_in_any_case` (`git -c CORE.HOOKSPATH=/dev/null commit`), `test_config_env_has_a_reason` (both `--config-env` forms), `test_git_config_set_and_unset_subcommands_have_a_reason`, `test_git_config_reads_have_no_reason` (`--get-all`, `get`), `test_a_read_does_not_hide_a_later_write`, `test_a_bare_key_without_a_read_flag_has_a_reason`, `test_searching_for_the_key_has_no_reason` (`rg core.hooksPath`), `test_installing_lefthook_itself_has_no_reason` (`brew install lefthook`), `test_an_exported_switch_has_a_reason` (`export LEFTHOOK_EXCLUDE=x`, `export LEFTHOOK_CONFIG=x`), `test_a_quoted_switch_value_with_a_space_has_a_reason` (`LEFTHOOK_CONFIG="/tmp/hook dir/x.yml" git commit -m x`, `LEFTHOOK_EXCLUDE='a, b' git commit -m x`).
- `test/guard_parity_test.rb`: the two existing coverage tests now hold for `git config --global --unset core.hooksPath` and `git commit --no-veri`, which only an alternatives rule covers, so the expansion is proven through them.
- `claude/.claude/hooks/consent-guard.rb`: covered by the acceptance tests above; every existing test in `test/consent_guard_test.rb` stays green, including `test_a_push_hidden_behind_shell_syntax_is_still_checked` and `test_naming_a_guarded_flag_in_a_commit_message_is_allowed`.

Test setup: the guard tests keep their helpers. `setup` makes a temporary repository with an `origin` remote and a temporary `HOME`; `run_guard` and `run_codex_guard` pipe a payload into the script. `test/command_pieces_test.rb` and `test/hook_bypass_test.rb` load their module with `require_relative "../claude/.claude/hooks/<file>"` and build input with `Shellwords.split(command)` (through `CommandPieces.of` for `HookBypass`, which also gets the raw command). No network, no real hooks, no lefthook run.

---
Domain skills applied: dotfiles-maintenance (stow layout, rule 12), object-oriented-design (module boundaries), ruby-style (method shape). No conflicts between them.

## Coordinator decisions (2026-10-13)

Main changed under this plan. #186 (`pr-only-via-finish`) and its follow-ups rewrote `claude/.claude/hooks/consent-guard.rb`: `words(command)` is now a tokenizer that splits `;`, `&`, `|`, newlines, comments and redirects outside quotes, and the guard gained `gh pr create`/`gh pr merge` checks. Revise the plan against `origin/main` (`c01d6282`), then run a new critique round.

- Verified on main's guard: `git push --force origin feature; echo done` and `...&&echo done` exit 2; `git push --force-with-lease origin feature; echo done` exits 0; `echo "a;b --force"` exits 0. The splitting criterion already holds on main.
- Drop `CommandPieces`. Build `HookBypass` on main's `words`. Keep a test for each splitting acceptance criterion, so it stays pinned.
- The first implementation (on main before #186) is on the local branch `guard-hook-bypasses-impl1` (`a2dd2238`, `8a430c9d`, `2c62e6c6`). Reuse what still fits: `HookBypass`, the Codex rules, the parity test extension, the tests.
- Unchanged: scope, out of scope and acceptance criteria in `intent.md`. Sequencer commits (`cherry-pick`, `am`) stay out of scope (Etienne: known gap). The mixed `--force-with-lease a; --force b` case stays an accepted risk.
- `test/review_report_check_test.rb` is red on main for an unrelated reason; intent `review-report-test-bypasses-guard` fixes it. It is not this change's concern.

## Critique

### Round 1 (codex exec -p terra)

- `git ci -n` skips the hooks through the global alias `ci = commit` in `git/.config/git/config`, and the plan matched only `commit` → fixed (decision 6 treats `ci` as a commit word, decision 9 adds `ci` to the `-n` and `--no-verify` rules, decision 11 adds a test that keeps `HookBypass::COMMIT_WORDS` in step with the config's commit aliases)
- `GIT_CONFIG_GLOBAL=/dev/null`, `HOME` and `XDG_CONFIG_HOME` overrides hide the global `core.hooksPath`; include them or amend the intent → dismissed: the amended intent of 2026-10-12 lists them as a known limit, out of scope
- `git config remove-section core` and `rename-section core` unset `core.hooksPath` without naming the key → fixed (decision 6 adds the section operations on `core`, decision 9 adds Codex rules for them, Proof adds `test_removing_or_renaming_the_core_section_waits_for_consent`)
- Splitting every word on shell operators breaks the quoted-prose constraint, and a `LEFTHOOK=` prefix match catches the quoted sentence `"LEFTHOOK=0 is refused"` → fixed (decision 1 splits only words without whitespace, the lefthook switch rule requires a piece without whitespace, Proof adds `test_quoted_prose_that_starts_with_a_switch_has_no_reason`)

### Round 2 (codex exec -p terra)

- `git -c core.hooksPath commit` sets the key to `true` without `=`, a relative hooks directory that is normally empty → dismissed: probed 2026-10-12 with git 2.54.0, git refuses it with "missing value for 'core.hookspath'" and makes no commit
- `git am -n` is also `--no-verify`, and `git am`, `git merge` and `git pull --no-verify` have no Codex rule → fixed (decision 9 merges the commit and push `--no-verify` rules into one rule over `commit`, `ci`, `push`, `merge`, `pull` and `am`, and step 8 checks `git merge --no-verify`; the `am -n` part is left out because the global shims install no `applypatch-msg` or `pre-applypatch` hook, so `git am -n` skips nothing)
- Shell variable indirection, such as `key=core.hooksPath; git -c "$key=/dev/null" commit`, hides the key from every predicate → dismissed: a value the shell computes is the same class as `eval` and `sh -c` strings, which the intent puts out of scope, and catching it means evaluating shell, which the guard's header rejects
- The whitespace rule lets `LEFTHOOK_CONFIG="/tmp/hook dir/empty.yml"` through and makes the one-word message `git commit -m "LEFTHOOK=0"` ask → fixed (decision 6 counts a switch piece with whitespace when the raw command holds the switch name followed by `="` or `='`, `HookBypass.reason` takes the raw command, Proof adds `test_a_quoted_switch_value_with_a_space_has_a_reason`; the one-word message keeps asking, recorded under Risks, because it is not prose)
- Backtick substitution leaves `` `git `` and `` -n` `` unmatched → fixed (decision 1 splits on the backtick too, Proof adds it to `test_parentheses_and_backticks_split_the_word`)
- The plan misstated how Codex applies rules to chained commands, and step 8 proves neither case → fixed (decision 9 now says Codex splits plain chains and treats assignments, redirections and a background `&` as opaque, both covered by the hook; a `zsh -lc` check is left out because `codex execpolicy check` does no shell parsing, probed 2026-10-12)
