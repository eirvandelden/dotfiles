# Plan: Agent worktrees end up outside `.worktrees/`

From `intent.md` and `spec.md` (2026-10-02). Status: accepted.

## Context

Agents make worktrees outside `<main checkout>/.worktrees/`, where the `worktree-create` sweep never cleans them up. The spec settles two real causes and drops a third. Cause 1: the `worktree-first` skill tells the agent to skip in any linked worktree. Cause 3: nothing stops a hand-typed `git worktree add <any path>`. Cause 2 (`worktree-create` nesting) is not a bug; an existing test already proves it. This plan fixes cause 1 in the skill text and its Step 1 snippet, adds a `PreToolUse` guard for cause 3 in Claude Code and Codex, and writes the "never type `git worktree add`" rule in every place the spec names.

The branch `worktrees-outside-dot-worktrees` is behind `origin/main`. Main has since gained Codex inline hooks in `codex/.codex/config.toml` (`[[hooks.PreToolUse]]`, matcher `^Bash$` runs `consent-guard.rb`) and `test/guard_parity_test.rb`. This plan builds on those, so the first step is a rebase.

## Files that change

- `claude/.claude/skills/worktree-first/SKILL.md` — "Skip when" drops the "already inside a linked worktree" bullet. Step 1 keeps its branch-naming block. Its second block (the one that runs `worktree-create`) reads a set `$branch` and gains the skip check. It reuses the current worktree, without calling `worktree-create`, only when all three hold: the current branch is `$branch`; `git rev-parse --show-toplevel`, canonicalised with `cd … && pwd -P`, is `<parent>/.worktrees/$branch`; and `<parent>` is a main working tree (`git -C <parent> rev-parse --git-dir` equals its `--git-common-dir`). The third check rejects a worktree nested in another linked worktree, and works for a submodule checkout. It does not use the first line of `git worktree list --porcelain`, which is a git directory inside a submodule. Otherwise the block calls `worktree-create`. Adds the "never type `git worktree add` yourself; use `worktree-create`" sentence. Codex reads the same file through the `agents/.agents/skills/worktree-first` symlink.
- `claude/.claude/hooks/worktree-guard.rb` (new, mode 755) — `PreToolUse` hook. Reads `tool_input.command` and `cwd` from stdin JSON. Splits the command on `&&`, `||`, `;`, `|` into segments, tokenised with `Shellwords` (same fallback as `consent-guard.rb`). Tracks a literal `cd <dir>` segment as the new working directory for later segments.
  - Supported syntax: the `git` word (or a word ending in `/git`) anywhere in a segment, so `command git`, `env git`, `VAR=x git` and `sudo git` are seen. Global options before the subcommand: `-C <dir>` (each one applied in turn), and `-c`, `--git-dir`, `--work-tree`, `--namespace` skipped with their value. Then `worktree add`. Options of `add`: `-b`, `-B`, `--reason` take a value; every other `-…` word is a flag (`-f`, `--detach`, `--orphan`, `--lock`, `--no-checkout`, `-q`, `--track`, …); `--` ends options. The first remaining word is the target.
  - Main checkout: the same logic as `worktree-create`'s `repo_root!` (`git/.config/git/worktree-tools/worktree-create:46`), ported, not shared: first `worktree` line of `git worktree list --porcelain`; when that is not a working tree (a submodule), its `core.worktree` resolved against it. `worktree-create` stays unchanged, and the `claude` package does not require a file from the `git` package.
  - Containment by path component: the real target path must start with `<real main checkout>/.worktrees/`, so `.worktrees-escape/x` and `.worktrees` itself are outside. The target does not exist yet, so it resolves its nearest existing ancestor with `File.realpath` (macOS `/var` → `/private/var`).
  - Blocks (exit 2, stderr names `worktree-first` and `worktree-create`) when the target is outside. Not a git directory, or no target word: exit 0.
- `claude/.claude/settings.json` — second hook in the existing `PreToolUse` entry with matcher `Bash`: `"\"$HOME/.claude/hooks/worktree-guard.rb\""`, timeout 10.
- `codex/.codex/config.toml` — second `[[hooks.PreToolUse.hooks]]` under the existing `^Bash$` entry, command `'"$HOME/.claude/hooks/worktree-guard.rb"'`, timeout 10. Same entry, not a new one, so both tools keep one Bash matcher.
- `test/guard_parity_test.rb` — `codex_hook` takes the script name too, because the `^Bash$` entry now holds two commands. New test that Codex and Claude run the same worktree-guard command.
- `test/worktree_guard_test.rb` (new) — guard tests, in the style of `test/consent_guard_test.rb`, including a Codex-shaped payload.
- `test/worktree_first_skill_test.rb` (new) — runs the skill's Step 1 snippet in fixture repositories, and checks the "Skip when" text.
- `test/worktree_rule_mirror_test.rb` (new) — the rule text in each written place, in the style of `test/markdown_rule_mirror_test.rb`.
- `claude/.claude/WORKTREES.md` — the rule sentence. `codex/.codex/WORKTREES.md` is a symlink to it, so one edit covers both copies.
- `agents.md` (playbook; `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md` are symlinks to it) — rule 7 gains the sentence.
- `claude/.claude/core-values.yml` — the workflow worktree line gains the sentence.
- `project-dictionary.txt` — only if cspell flags a new word.

Unchanged: `git/.config/git/worktree-tools/worktree-create`, `consent-guard.rb`, `codex/.codex/rules/default.rules`.

## Order of work

0. Rebase the branch onto `origin/main` (`sync` skill). Run the full suite once; it must be green before step 1.
1. Write `test/worktree_first_skill_test.rb` `test_inside_the_tasks_own_worktree_it_reuses_it_without_calling_worktree_create`. Run it, watch it fail: today's snippet always calls `worktree-create`. This is the walking skeleton.
2. Add the other skill tests: the "Skip when" text test (fails today) and the two "from another worktree" tests (pass today; they guard against regression). Change `SKILL.md`: the "Skip when" bullet and the Step 1 snippet. Run the file until green. Commit.
3. Write `test/worktree_guard_test.rb` with the first acceptance case, `git worktree add ../elsewhere -b x` from the main checkout. Run it, watch it fail (no script). Write the smallest `worktree-guard.rb` that passes. Add the other acceptance and unit cases one at a time, red then green. Commit.
4. Add the parity test for the worktree guard. Watch it fail. Register the hook in `settings.json` and `config.toml`; change `codex_hook` to take the script. Run `test/guard_parity_test.rb` until green. Commit.
5. Write `test/worktree_rule_mirror_test.rb`. Watch it fail. Add the sentence to `WORKTREES.md`, `SKILL.md`, `agents.md` rule 7, `core-values.yml`. Green. Commit.
6. Run the full suite (`for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`), `rubocop` on the changed Ruby files, markdownlint and cspell on the changed Markdown. Re-read the full diff.
7. Exercise the guard for real in a Claude Code session: a hand-typed `git worktree add /tmp/x -b x` is refused with the message. Tell Etienne to run `/hooks` once in the Codex CLI to trust the new hook; report this as not verified in Codex until then.

## Risks

- **Shell parsing is approximate.** The guard tokenises; it is not a shell. Variables (`$WT`), subshells and `eval` are not expanded. Such a target is taken literally and usually resolves outside `.worktrees/`, so it blocks. A `cd "$X" && git worktree add …` is resolved against the hook's `cwd`. The written rule and `worktree-create` are the way out, and the block message says so.
- **False block on legitimate work.** Only a target outside `.worktrees/` blocks, so `worktree-create` (its own subprocess, never seen by the hook) and `git worktree add .worktrees/x` still run.
- **Path comparison on macOS.** `/tmp` and `/var` are symlinks. Both sides are compared as real paths; the test fixtures use `Dir.mktmpdir`, which hits this case.
- **Codex trust.** The Codex hook does not run until Etienne trusts it with `/hooks`. A dotfiles change cannot do that step.
- **A hook that cannot run blocks nothing** (Ruby missing from `PATH`). The written rule is the fallback.
- **The skill fix is prose plus a snippet.** An agent that ignores the skill still gets the guard for cause 3, but nothing forces cause 1. Accepted by the spec.
- **Ported root logic can drift** from `worktree-create`'s `repo_root!`. The guard's submodule tests pin the same cases `worktree_create_test.rb` pins. Rejected: a shared library file, because it changes `worktree-create` (spec: unchanged) and couples the `claude` package to the `git` package.
- Second-model critique (`codex -p terra`, 2026-10-02) found: the porcelain first line is a git directory in a submodule; the parser missed `command`/`env`/assignment wrappers and `--detach`/`--orphan`/`--`; containment must be by path component; the skill test must not run the branch-naming block. All four are folded in above.
- Rejected: extending `consent-guard.rb` (different policy, no consent override); `default.rules` `prefix_rule` (cannot test a path); a sweep for `.claude/worktrees/` (out of scope); a separate Bash matcher entry per tool (the parity helpers find the first entry per matcher).

## Out of scope

- Worktrees made by `claude --worktree` and teaching the sweep to clean `.claude/worktrees/`.
- Removing the existing stray worktree in the work repository (by hand, after its PR merges).
- Any change to `worktree-create`.

## Proof

- New task from inside `.worktrees/foo` lands in `<main>/.worktrees/<new>` → `test/worktree_first_skill_test.rb` `test_from_inside_another_dot_worktrees_worktree_it_creates_the_new_one_under_the_main_checkout`
- New task from inside `.claude/worktrees/foo` lands in `<main>/.worktrees/<new>` → `test/worktree_first_skill_test.rb` `test_from_inside_a_claude_worktree_it_creates_the_new_one_under_the_main_checkout`
- Inside `.worktrees/bar` for task `bar`: nothing happens, `bar` is reused → `test/worktree_first_skill_test.rb` `test_inside_the_tasks_own_worktree_it_reuses_it_without_calling_worktree_create`
- No "skip in any linked worktree" text → `test/worktree_first_skill_test.rb` `test_skip_when_no_longer_skips_in_any_linked_worktree`
- `git worktree add ../elsewhere -b x` from main is blocked, message names `worktree-first` → `test/worktree_guard_test.rb` `test_a_worktree_beside_the_main_checkout_is_blocked_naming_worktree_first`
- `git worktree add .claude/worktrees/x -b x` is blocked → `test/worktree_guard_test.rb` `test_a_worktree_under_dot_claude_is_blocked`
- `git -C <repo> worktree add /tmp/x -b x` is blocked → `test/worktree_guard_test.rb` `test_git_dash_c_with_an_absolute_target_outside_is_blocked`
- `git worktree add ../../x -b x` from `.worktrees/foo` is blocked → `test/worktree_guard_test.rb` `test_a_relative_target_from_a_linked_worktree_that_leaves_the_main_checkout_is_blocked`
- `git worktree add ../bar -b bar` from `.worktrees/foo` is allowed → `test/worktree_guard_test.rb` `test_a_relative_target_from_a_linked_worktree_into_dot_worktrees_is_allowed`
- `git worktree add .worktrees/baz -b baz` from main is allowed → `test/worktree_guard_test.rb` `test_a_target_inside_dot_worktrees_is_allowed`
- `git worktree list` and `git status` are allowed → `test/worktree_guard_test.rb` `test_other_git_commands_are_allowed`
- `git worktree add` outside a git repository is allowed → `test/worktree_guard_test.rb` `test_outside_a_git_repository_it_allows_everything`
- Both registrations name the same script → `test/guard_parity_test.rb` `test_codex_runs_the_same_worktree_guard_command_as_claude_for_shell_commands`
- The rule sentence is in all four places → `test/worktree_rule_mirror_test.rb` `test_worktrees_md_says_never_type_git_worktree_add`, `test_the_worktree_first_skill_says_never_type_git_worktree_add`, `test_the_playbook_says_never_type_git_worktree_add`, `test_the_core_values_say_never_type_git_worktree_add`

Per changed file, the unit tests expected, named as behaviour:

- `claude/.claude/hooks/worktree-guard.rb` (in `test/worktree_guard_test.rb`): `test_the_block_message_names_worktree_create`, `test_a_worktree_add_after_a_literal_cd_resolves_against_that_directory`, `test_a_worktree_add_later_in_a_chain_is_still_checked`, `test_the_path_after_dash_b_is_the_target_not_the_branch_name`, `test_flags_and_double_dash_before_the_target_are_skipped`, `test_a_git_behind_command_env_or_an_assignment_is_still_checked`, `test_a_sibling_directory_whose_name_starts_with_dot_worktrees_is_blocked`, `test_dot_worktrees_itself_as_the_target_is_blocked`, `test_a_target_through_a_symlinked_tmp_directory_is_compared_by_real_path`, `test_inside_a_submodule_dot_worktrees_under_the_submodule_checkout_is_allowed`, `test_from_a_linked_worktree_of_a_submodule_a_target_outside_is_blocked`, `test_a_command_that_cannot_be_tokenised_still_gets_checked`, `test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload`, `test_a_null_tool_input_is_allowed`.
- `claude/.claude/skills/worktree-first/SKILL.md` (in `test/worktree_first_skill_test.rb`): the four tests above, plus `test_inside_a_worktree_nested_in_another_linked_worktree_it_does_not_skip` and `test_inside_a_submodules_own_worktree_for_the_task_it_reuses_it`. Each snippet test also asserts the shell ends in the expected worktree path.
- `test/guard_parity_test.rb`: the two existing Codex parity tests keep passing after `codex_hook` takes a script name.

Test setup: fixture repositories from `git init` in `Dir.mktmpdir`, with a bare `origin` clone as in `test/worktree_create_test.rb`, and `.worktrees` added to `.git/info/exclude`. Linked worktrees made with `git worktree add` inside the fixture. Submodule fixtures as `add_submodule` in `test/worktree_create_test.rb`. The skill test extracts only the Step 1 `bash` block that names `worktree-create` (not the branch-naming block, which would overwrite `branch`) and runs it with `bash`, `branch` set, and `HOME` pointed at a temporary directory. There, `.config/git/worktree-tools/worktree-create` is a wrapper that logs its call and then runs the real script. `gh` is left off `PATH` and `HERDR_ENV` unset, as `test_without_gh_on_path_worktree_create_still_succeeds` already does. The guard test sends JSON on stdin to the script, as `consent_guard_test.rb` does.
