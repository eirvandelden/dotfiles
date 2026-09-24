# Plan: Stop agents hardwrapping markdown — phase 1 (rule and tooling)

From `intent.md` and `spec.md` (2026-09-23). Status: accepted.

Worktree: `/Users/etienne.vandelden/Developer/dotfiles/.worktrees/no-hardwrap-markdown`, branch `no-hardwrap-markdown`, off `origin/main`. Change folder: `docs/changes/no-hardwrap-markdown/`. The worktree and branch already exist, with intent, spec and this plan committed: `cd` into that worktree and work there (the `worktree-first` skill skips itself inside a linked worktree). Do not create a second worktree or branch.

Phase 2 (requirement 8, unwrap existing markdown, acceptance criterion 17) is a separate stacked pull request with its own `plan-phase-2.md`. Before phase 2 starts, agree with Etienne which files count as vendored. Candidates to leave alone: `.clinerules/`, `.windsurf/`, `.opencode/`, `.github/copilot-instructions.md` (written by caveman-init), symlinked `.md` files (`git ls-files -s | grep ^120000`), and skill files adapted from upstream plugins.

## Context

Agents hardwrap markdown paragraphs. The rule against it is only in Claude's dotfiles project memory, the markdown agents copy from is itself wrapped, and markdownlint's default MD013 (80 characters) flags every unwrapped paragraph. Phase 1 puts the rule in the shared playbook, turns MD013 off globally, adds one markdownlint custom rule `no-hardwrap`, and runs it as a warning at commit (lefthook) and after each Claude edit (PostToolUse hook).

## Files that change

- `agents.md` — new §7 rule 26 "Markdown prose": one line per paragraph, list item and block quote; the renderer wraps. This file is the playbook for both Claude and Codex.
- `claude/.claude/core-values.yml` — new line in `workflow:` with the same rule.
- `markdownlint/.config/markdownlint/config` — new stow package (approved by spec acceptance). JSON `{ "MD013": false }`. markdownlint-cli's `rc('markdownlint')` reads `~/.config/markdownlint/config`.
- `markdownlint/.config/markdownlint/no-hardwrap.cjs` — the custom rule (CommonJS; markdownlint-cli 0.48 loads rules with `require`). Uses `parser: "micromark"`.
  - Detection: walk every `paragraph` token at any depth (this covers paragraphs inside list items and block quotes; tables, headings, code, HTML and front matter never produce `paragraph` tokens). A paragraph is wrapped when it contains a `lineEnding`, at any depth (inside emphasis, link labels and code spans too), whose previous sibling is not `hardBreakEscape` or `hardBreakTrailing`. Its lines split into runs at the hard breaks.
  - Default mode: one `onError` per run of two or more soft-joined lines, at the run's first line, detail `"join lines N–M into one line"`. No fix info.
  - Unwrap mode (rule config `{ "unwrap": true }`): per run of soft-joined lines, one error on the run's first line with `fixInfo` appending the rest (continuation text is the whole source line from the first paragraph text token on it, so list indentation and `> ` prefixes drop but inline markup stays; single spaces between; the run's last line keeps a trailing hard break), and one error per continuation line with `fixInfo: { deleteCount: -1 }`. Needed because one markdownlint error can carry only one single-line edit.
- `markdownlint/.config/markdownlint/no-hardwrap.json` — `{ "default": false, "no-hardwrap": true }`, used by the commit check and the Claude hook.
- `markdownlint/.config/markdownlint/unwrap.json` — `{ "default": false, "no-hardwrap": { "unwrap": true } }`, used with `--fix` (phase 2, and by hand).
- `packages.conf` — add `markdownlint` to `STOW=(…)`.
- `claude/.claude/skills/dotfiles-maintenance/references/repository-layout.md` — list the new package.
- `lefthook.yml` — pre-commit command `no-hardwrap`, `glob: "*.{md,markdown}"` (review round 2: same files as the Claude hook), tags `markdown`. Skips with a message when `markdownlint` is not on PATH, or when `~/.config/markdownlint/no-hardwrap.cjs` is missing because the package is not stowed. Runs `markdownlint --config "$HOME/.config/markdownlint/no-hardwrap.json" --rules "$HOME/.config/markdownlint/no-hardwrap.cjs" {staged_files}`, prints the findings and always exits 0.
- `claude/.claude/hooks/markdown-hardwrap.rb` — PostToolUse hook, Ruby, same shape as `test-guard.rb`. Reads `tool_input.file_path`; ignores anything not ending in `.md` or `.markdown` (any case), a missing file, or a missing `markdownlint`. Runs markdownlint with `-j` and the check config; on findings prints `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}` naming file, lines, and the fix (join each paragraph onto one line, or run `markdownlint -c ~/.config/markdownlint/unwrap.json -r ~/.config/markdownlint/no-hardwrap.cjs --fix <file>`). Always exits 0.
- `claude/.claude/settings.json` — new `PostToolUse` entry, matcher `Edit|Write|MultiEdit`, command `"$HOME/.claude/hooks/markdown-hardwrap.rb"`, timeout 10.
- `.github/workflows/dotfiles-tests.yml` — one step `npm install -g markdownlint-cli@0.48.0` next to the cspell step (approved by Etienne in planning).
- `project-dictionary.txt` — new words cspell rejects (for example `hardwrap`, `micromark`).
- Tests: `test/no_hardwrap_rule_test.rb` (new), `test/markdown_hardwrap_hook_test.rb` (new), `test/markdown_rule_mirror_test.rb` (new), `test/lefthook_local_hooks_test.rb` (extended).
- Outside the repository, last step: delete `~/.claude/projects/-Users-etienne-vandelden-Developer-dotfiles/memory/no-hardwrap-markdown.md` and its line in `MEMORY.md`.

## Order of work

1. Walking skeleton. Write `test/no_hardwrap_rule_test.rb` `test_a_paragraph_over_three_lines_is_reported_once_at_its_first_line`, running the real `markdownlint` CLI against a temp file with `-c`/`-r` pointing at the package. Run it; watch it fail because the rule file does not exist.
2. Minimal `no-hardwrap.cjs` + `no-hardwrap.json`; green.
3. Red/green one at a time: list item, block quote, the not-reported cases, hard breaks.
4. Unwrap mode: `unwrap.json`, then red/green for fixing a paragraph and a list item (`--fix`, read the file back).
5. Global config: test that a 300-character line reports no MD013 with `HOME` pointed at a temp dir whose `.config/markdownlint` links to the package. Add `config`.
6. Lefthook: extend `lefthook_local_hooks_test.rb` (its temp `HOME` gets `.config/markdownlint` linked to the package). Red/green for warning-and-commit, clean commit, and markdownlint missing (PATH without it).
7. Claude hook: `test/markdown_hardwrap_hook_test.rb` feeding JSON on stdin like `test_guard_test.rb`. Red/green for a wrapped `.md`, a clean `.md`, and a `.rb` file. Then register it in `settings.json`.
8. Playbook and core values: `test/markdown_rule_mirror_test.rb` asserts `agents.md` and `claude/.claude/core-values.yml` both carry the rule. Red, then edit both; green.
9. `packages.conf`, `repository-layout.md`, CI step, `project-dictionary.txt`.
10. Refactor pass over the rule and the tests. Run every `test/*_test.rb`, then `yamllint`, `cspell`, `rubocop` and `shellcheck` on the touched files, and markdownlint (with `no-hardwrap`) on the new markdown.
11. Retire the memory file. Commit each step on green, in small commits. Run `review`, then push and open the PR against `origin` using the repository's PR template.

## Risks

- **Continuation text in quotes and lists.** Lazy continuation lines (no `>`) and nested lists shift which token starts a line. Covered by the block-quote and list-item fix tests; if nesting misbehaves, fall back to reporting only and leave that case unfixed.
- **Unwrap-mode fix ordering.** Relies on markdownlint applying one insert on line N and line deletes below it. Checked in `applyFixes` (sorts bottom-to-top, line deletes last); proven by the fix tests.
- **PostToolUse output contract.** Taken from the Claude Code hooks reference (exit 0 + `hookSpecificOutput.additionalContext`). Script-level tests prove the JSON; end-to-end needs `stow -R claude markdownlint -t "$HOME"`, which Etienne runs, then one real `.md` edit.
- **Hook reach.** Other repositories only get the lefthook warning once the global git hook scripts in the main checkout are restored (spec concern). Not fixed here.
- **`settings.json` merge.** The main checkout has uncommitted edits to this file; the next pull may conflict in `hooks`.
- **Lefthook output.** If lefthook hides the output of a successful command, the warning is invisible. Test 12 asserts the output text; if it fails, the command uses the per-command output setting.
- **Rejected:** a Ruby or shell heuristic for paragraphs (does not know markdown structure); prettier `proseWrap: never` (new dependency, reformats more than wrapping); blocking the commit (the intent says warn only).

## Out of scope

- Unwrapping existing markdown (phase 2).
- Repairing the global git hook scripts.
- An edit-time hook for Codex.
- Editor settings (Zed, Nova, Neovim).

## Proof

- 1 Playbook carries the rule → `test/markdown_rule_mirror_test.rb` `test_the_playbook_tells_agents_one_line_per_paragraph`
- 2 Core values carry the rule → `test/markdown_rule_mirror_test.rb` `test_the_core_values_repeat_the_one_line_per_paragraph_rule`
- 3 Memory entry gone → manual: `ls` the memory directory and `grep no-hardwrap MEMORY.md` return nothing (outside the repository, no test)
- 4 No line-length error → `test/no_hardwrap_rule_test.rb` `test_the_global_config_does_not_report_a_long_paragraph_line`
- 5 Three-line paragraph → `test/no_hardwrap_rule_test.rb` `test_a_paragraph_over_three_lines_is_reported_once_at_its_first_line`
- 6 List item → `test/no_hardwrap_rule_test.rb` `test_a_list_item_continuing_on_an_indented_line_is_reported`
- 7 Block quote → `test/no_hardwrap_rule_test.rb` `test_a_block_quote_over_two_lines_is_reported`
- 8 Not reported → `test/no_hardwrap_rule_test.rb` `test_one_line_paragraphs_code_tables_headings_and_front_matter_are_not_reported`
- 9 Hard breaks → `test/no_hardwrap_rule_test.rb` `test_lines_joined_by_a_hard_line_break_are_not_reported`
- 10 Fix paragraph → `test/no_hardwrap_rule_test.rb` `test_unwrapping_a_three_line_paragraph_leaves_one_line_joined_by_single_spaces`
- 11 Fix list item → `test/no_hardwrap_rule_test.rb` `test_unwrapping_a_list_item_leaves_one_bullet_line_without_the_indentation`
- 12 Commit warns → `test/lefthook_local_hooks_test.rb` `test_pre_commit_warns_about_a_wrapped_paragraph_and_still_commits`
- 13 Clean commit → `test/lefthook_local_hooks_test.rb` `test_pre_commit_prints_no_hardwrap_warning_for_one_line_paragraphs`
- 14 No markdownlint → `test/lefthook_local_hooks_test.rb` `test_pre_commit_skips_the_hardwrap_check_without_markdownlint`
- 15 Claude told → `test/markdown_hardwrap_hook_test.rb` `test_a_wrapped_markdown_file_tells_claude_the_file_line_and_fix`
- 16 Claude told nothing → `test/markdown_hardwrap_hook_test.rb` `test_a_clean_markdown_file_tells_claude_nothing`, `test_a_non_markdown_file_is_not_checked`
- 17 → phase 2.

Per changed file, the unit tests expected:
- `markdownlint/.config/markdownlint/no-hardwrap.cjs`: covered by `test/no_hardwrap_rule_test.rb` through the CLI (criteria 4–11); plus `test_a_paragraph_mixing_a_hard_break_and_a_soft_wrap_is_reported`, `test_a_nested_list_item_is_unwrapped_at_its_own_indentation`; review round 1: `test_unwrapping_keeps_inline_markup_on_a_continuation_line`, `test_unwrapping_keeps_an_indented_continuation_line`, `test_unwrapping_a_block_quote_keeps_the_whole_second_line`, `test_a_wrap_inside_emphasis_is_reported_and_unwrapped`, `test_a_wrap_inside_a_link_label_is_reported_and_unwrapped`, `test_a_hard_break_then_a_soft_wrap_reports_only_the_soft_run`, `test_unwrapping_does_not_leave_a_double_space_after_trailing_whitespace`, `test_unwrapping_keeps_a_trailing_hard_break_at_the_end_of_a_run`; review round 2: `test_unwrapping_keeps_the_words_of_an_inline_html_comment`, `test_unwrapping_a_footnote_definition_drops_its_continuation_indentation`; review round 3: `test_unwrapping_trims_trailing_spaces_inside_an_inline_html_comment`.
- `claude/.claude/hooks/markdown-hardwrap.rb`: `test_a_missing_file_tells_claude_nothing`, `test_missing_markdownlint_tells_claude_nothing`, `test_the_hook_always_exits_zero`, `test_a_markdown_file_with_a_long_extension_or_upper_case_is_checked`, `test_the_fix_command_quotes_a_path_with_a_space`.
- `lefthook.yml`: covered by criteria 12–14, plus `test_pre_commit_warns_about_a_wrapped_paragraph_in_a_markdown_extension_file`; review round 3: `test_pre_commit_skips_the_hardwrap_check_when_the_markdownlint_package_is_not_stowed`.

Test setup: Minitest, `Dir.mktmpdir` per test, markdown written inline with heredocs. The real `markdownlint` CLI is used (tests skip with a message when it is missing locally; CI installs it). `HOME` points at the temp dir with `.config/markdownlint` symlinked to the package in this worktree. The Claude hook gets JSON on stdin; "markdownlint missing" is faked with a `PATH` that omits it.
