# Plan: Make gh-dash reviews fit my keyboard

From `intent.md` (2026-10-20). Status: accepted.

## Context

gh-dash v4.26.2 runs as a `gh` extension. Its config is `github/.config/gh-dash/config.yml`, stowed to `~/.config/gh-dash/config.yml`. Facts below come from the v4.26.2 source (tag `v4.26.2` of `dlvhdr/gh-dash`):

- `keybindings.universal` entries with `builtin: pageDown` / `builtin: pageUp` rebind the preview scroll (`internal/tui/keys/keys.go`, `Rebind`). `key.SetKeys(kb.Key)` replaces the default key, so one key per action.
- A keybinding with `command:` runs through `$SHELL -c` under `tea.ExecProcess`, so it owns the terminal and can read stdin. PR templates expose `{{.RepoName}}` (owner/repo) and `{{.PrNumber}}` (`internal/tui/modelUtils.go`).
- A non-zero exit of a custom command shows "Whoops, got an error". Exit 0 shows nothing.
- After a custom command, gh-dash only runs `FetchNextPageSectionRows`, which does nothing when the section has no next page. The row of a PR merged by a custom command stays until `r` refreshes the section. The builtin `m` merge updates the row but always runs an interactive `gh pr merge` with three prompts and accepts no flags.
- `pager.diff` becomes `GH_PAGER` for `gh pr diff`. Only the exact value `delta` gets `--paging always` added, so any other value must carry it itself (`internal/config/utils.go`).
- `~/.config/git/config` is a link into this public repository. `git config --global` writes there. A merge-method setting must live in a machine-local file outside the repository.

## Design decisions

- Preview scroll: `keybindings.universal` gets `{ key: ctrl+down, builtin: pageDown }` and `{ key: ctrl+up, builtin: pageUp }`. These replace `ctrl+d`/`ctrl+u` as page keys; gh-dash cannot bind two keys to one builtin. `ctrl+d` still submits comments, which gh-dash hard-codes. Each press moves half a page (gh-dash's `HalfPageDown`); there is no full-page builtin.
- Side-by-side diff: `pager.diff: delta --paging always --side-by-side`. Only gh-dash's diff changes; git's own pager and delta's global config stay unified.
- Merge: one script, `github/.config/gh-dash/scripts/merge-pr.sh <owner/repo> <number>`, bound in `keybindings.prs` to both `ctrl+m` and `M` with the same command: `~/.config/gh-dash/scripts/merge-pr.sh {{.RepoName}} {{.PrNumber}}`. Bash, like the herdr scripts, linted by shellcheck.
- The script prints `Merge <owner/repo>#<n> with <method> and delete its branch? Enter merges, anything else cancels: `. An empty line merges. Any other answer, or end of input, prints `Cancelled.` and exits 0, so gh-dash shows no error. On Enter it `exec`s `gh pr merge <n> -R <owner/repo> --<method> --delete-branch`; with a method flag `gh` asks nothing more. `-R` makes `gh` delete only the remote branch, never a local one: gh v2.102.0 sets `CanDeleteLocalBranch = !cmd.Flags().Changed("repo")` (`pkg/cmd/pr/merge/merge.go:124`).
- Merge method setting: git config key `pr-merge.<subsection>.method`, value `merge`, `squash` or `rebase`. The subsection is `<owner>/<repo>` for one repository or `<owner>` for every repository of an owner. Lookup order: repository, owner, then `merge`. Subsections match case-insensitively, because people type owner names in any case and gh-dash passes GitHub's canonical case. Any other value makes the script exit 2 with `merge-pr: unknown merge method '<value>' in pr-merge.<subsection>.method; use merge, squash or rebase`, and `gh` is not run.
- The script reads all git config scopes (`git config --get-regexp`), so any included file counts. The machine-local home of the setting is `~/.config/git/pr-merge.config`, which `git/.config/git/config` includes. Git ignores a missing include file. Docs write it with `git config --file ~/.config/git/pr-merge.config ...`, never `--global`. dotfiles-work may instead put the work owner's setting in its own included file; that change is out of scope.
- Agent documentation: a new shared skill `pr-merge-method` in `agents/.agents/skills/pr-merge-method/` (with `agents/openai.yaml`), linked from `claude/.claude/skills/pr-merge-method`, and listed in `SKILLS-INDEX.md`. Its description triggers on "merge method", "squash-merge", "merge commit" and "gh-dash merge". A skill is how both Claude and Codex find guidance in any repository; a playbook line would load in every session for a rare task.
- Human documentation: a new README section `## 🐙 gh-dash`, with the review keys and the merge-method recipes (owner, repository, change, remove, default). The skill points to the same commands; the README does not depend on the skill.
- Tests: per playbook rule 3, configuration has no new tests. The script is code and gets an integration test. The existing `test_diff_pager_stays_delta` in `test/gh_dash_config_test.rb` pins the old pager value; it is updated to the new value as an intended behaviour change, not deleted.
- No step contradicts intent's `## Decisions`. One conflict with the acceptance criteria remains: "gh-dash shows the PR as merged, with no further prompt" cannot hold in v4.26.2 with a custom command. After the merge the row stays listed as open until `r`. The plan meets every other part of that criterion and documents `r`. Etienne settled it on 2026-10-20: press `r` after merging. `intent.md` records the amended criterion.

## Integration points

- gh-dash v4.26.2 keybinding and pager config.
- `gh pr merge` flags `--merge`, `--squash`, `--rebase`, `--delete-branch`, `-R`.
- delta 0.20.1 flags `--paging always`, `--side-by-side`.
- Git config include chain: `git/.config/git/config` → `~/.config/git/pr-merge.config` (machine-local, not in any repository).
- Stow packages `github`, `agents`, `claude`: the new script and skill reach `~` only after a restow (rule 12). Etienne approved the restow on 2026-10-20. A restow from the main checkout picks up the new files only after the merge. Before the merge, the manual checks use the worktree files: `gh dash --config <temp copy>` whose merge command points at the worktree script, and the agent check reads the skill from the worktree. After Etienne merges, `stow -R -t "$HOME" github agents claude` from the main checkout installs them.
- Ghostty's kitty keyboard protocol for `ctrl+m`; herdr is unverified, which is why `M` exists.

## Files that change

- `test/gh_dash_merge_test.rb` — new. Integration tests of `merge-pr.sh` with a stub `gh` on `PATH` and git config isolated through `GIT_CONFIG_GLOBAL`.
- `github/.config/gh-dash/scripts/merge-pr.sh` — new, executable. Prompt, method lookup, `gh pr merge`.
- `github/.config/gh-dash/config.yml` — `pager.diff`; `keybindings.universal` scroll keys; `keybindings.prs` `ctrl+m` and `M`. The `C` binding and the sections stay untouched.
- `test/gh_dash_config_test.rb` — `test_diff_pager_stays_delta` asserts `delta --paging always --side-by-side`; rename it to `test_diff_pager_is_delta_side_by_side`.
- `git/.config/git/config` — `[include] path = ~/.config/git/pr-merge.config`, with a one-line comment that the file is machine-local and names no owner.
- `agents/.agents/skills/pr-merge-method/SKILL.md` and `agents/.agents/skills/pr-merge-method/agents/openai.yaml` — new skill.
- `claude/.claude/skills/pr-merge-method` — relative link `../../../agents/.agents/skills/pr-merge-method`.
- `SKILLS-INDEX.md` — one line under "Working with git and pull requests".
- `README.md` — new `## 🐙 gh-dash` section after `## 📖 Reading files in herdr`.

## Order of work

1. Write `test/gh_dash_merge_test.rb` with the no-setting acceptance test first. Run `ruby test/gh_dash_merge_test.rb -n test_merges_with_a_merge_commit_and_deletes_the_branch_without_a_setting` and watch it fail (script missing).
2. Write `merge-pr.sh` until that test passes. `chmod +x`. Run `shellcheck -x -S warning` on it.
3. Add the remaining script tests one at a time (owner squash, repository overrides owner, case-insensitive match, cancel on `n`, cancel on end of input, unknown method, `gh` failure passes its exit status). Red, then green, each.
4. Edit `config.yml`: pager, scroll keys, `ctrl+m` and `M`. Update `test_diff_pager_stays_delta`. Run `ruby test/gh_dash_config_test.rb` and `yamllint` on the file.
5. Add the include to `git/.config/git/config`. Check: `GIT_CONFIG_GLOBAL=git/.config/git/config git config --get-regexp '^include\.'` lists it, and `git config --list` still runs with the file missing.
6. Write the `pr-merge-method` skill, its `openai.yaml`, the Claude link and the `SKILLS-INDEX.md` line. Run `ruby test/skill_parity_test.rb` and `ruby test/vendored_skills_test.rb`.
7. Write the README section. Run the repository's markdown hooks on it (no hard wrap).
8. Manual checks in Ghostty, below in Proof, with a temporary copy of `config.yml` whose command paths point at this worktree's script: `gh dash --config <copy>`. Record the results in the change folder.
9. Run the full suite: `for f in test/*_test.rb; do ruby "$f" || exit 1; done`. Grep the diff for the work names listed in the no-work-references memory note; it must print nothing new.

## Risks

- Settled by Etienne on 2026-10-20: accept "press `r` after merging". The criterion "gh-dash shows the PR as merged" cannot hold with a custom command in v4.26.2; the row stays until `r` (or the section's refetch). The plan documents "press `r` after merging". The alternative, the builtin `m`, brings back the three `gh` prompts.
- macOS binds `ctrl+↑`/`ctrl+↓` to Mission Control by default. On this machine those hotkeys use another modifier, so the keys reach the terminal. A machine with the defaults loses them; the README notes this.
- herdr may not pass the kitty keyboard protocol through; then `ctrl+m` arrives as Enter and does nothing. `M` covers that.
- `--side-by-side` in a narrow pane wraps long lines. Accepted; Etienne asked for side by side.
- A typo in the subsection (owner name) silently falls back to the default. The prompt shows the method before anything happens, so the user sees it and can cancel.
- Rejected: `git config --global` for the setting, because it writes into the public repository through the link. Rejected: a full-page scroll, because gh-dash has no such builtin. Rejected: keeping `ctrl+d`/`ctrl+u` too, because one builtin takes one key.
- Out of scope: the work owner's squash setting (dotfiles-work), expanded descriptions, the footer, the existing `org:` filters, the `C` binding and the sections.

## Proof

- With a PR selected, `ctrl+↓` pages its description down and `ctrl+↑` up → check: in Ghostty, `gh dash --config <worktree copy>`, select a PR with a long description, press `ctrl+↓` twice and `ctrl+↑` once; the preview moves down, down, up.
- `d` shows the diff side by side → check: same session, press `d` on a PR; delta shows old and new columns.
- No setting: `ctrl+m`, Enter merges with a merge commit and deletes the branch → `test/gh_dash_merge_test.rb` `test_merges_with_a_merge_commit_and_deletes_the_branch_without_a_setting`; check: in gh-dash, on a throwaway PR in an `eirvandelden` repository, `ctrl+m`, Enter; `gh pr view` shows MERGED with a merge commit, the remote branch is gone, no further prompt; `r` removes the row.
- Owner says squash → `test/gh_dash_merge_test.rb` `test_squashes_when_the_owner_says_squash`.
- Repository says merge, owner says squash → `test/gh_dash_merge_test.rb` `test_repository_setting_wins_over_the_owner_setting`.
- `ctrl+m`, `n`, Enter leaves the PR open and shows no error → `test/gh_dash_merge_test.rb` `test_any_answer_other_than_enter_cancels_without_error`; check: in gh-dash, `ctrl+m`, `n`, Enter; no error banner, PR still open.
- `M` behaves exactly like `ctrl+m` → check: `ruby -ryaml -e` comparing the two `keybindings.prs` commands prints equal; in gh-dash, `M`, `n`, Enter shows the same prompt.
- README alone: set owner squash, override one repository to merge, remove both → check: follow the README commands for `eirvandelden` and one of its repositories; after each step `ctrl+m` on a PR there shows the expected method in the prompt; answer `n`.
- An agent in another repository sets squash from "squash-merge this repository's PRs from gh-dash" → check: before the merge, run `claude -p` with the worktree skill made available to it (not through stow) with that prompt in a scratch clone of an `eirvandelden` repository; it loads `pr-merge-method` and writes `pr-merge.<owner>/<repo>.method squash` to `~/.config/git/pr-merge.config`; then unset it.

Per changed file, the unit tests expected:

- `github/.config/gh-dash/scripts/merge-pr.sh`: `test_merges_with_a_merge_commit_and_deletes_the_branch_without_a_setting`, `test_squashes_when_the_owner_says_squash`, `test_rebases_when_the_repository_says_rebase`, `test_repository_setting_wins_over_the_owner_setting`, `test_settings_match_owner_and_repository_case_insensitively`, `test_any_answer_other_than_enter_cancels_without_error`, `test_end_of_input_cancels_without_error`, `test_unknown_method_fails_without_merging`, `test_prompt_names_the_pull_request_and_the_method`, `test_gh_failure_is_the_script_exit_status`, `test_passes_the_repository_with_r_so_no_local_branch_is_deleted`.
- `github/.config/gh-dash/config.yml`: `test_diff_pager_is_delta_side_by_side` (renamed from `test_diff_pager_stays_delta`).

Test setup: each test makes a temp dir with a stub `gh` (a Ruby script that appends its arguments to a log file and exits with `$STUB_GH_EXIT`, default 0) and a git config file passed as `GIT_CONFIG_GLOBAL`, with `GIT_CONFIG_SYSTEM=/dev/null` from `isolated_git.rb`. Settings are written with `git config --file`. The script runs through `Open3.capture3` with `PATH` led by the stub dir and stdin `"\n"`, `"n\n"` or empty. Owners in tests are `eirvandelden` and `example-org`; no work names.

---
Domain skills applied: dotfiles-maintenance, dependencies (no new dependency).

## Critique

### Round 1 (codex exec -p terra)

- The plan says `r` removes the merged row, but the criterion wants gh-dash to show the PR merged; the plan must not claim no conflict → fixed (Design decisions now names the conflict with the criterion; Risks keeps it as a Decision needed for Etienne)
- `--delete-branch` deletes the local and the remote branch; `-R` only selects the repository → dismissed: gh v2.102.0 `pkg/cmd/pr/merge/merge.go:124` sets `CanDeleteLocalBranch = !cmd.Flags().Changed("repo")`, so with `-R` only the remote branch goes; the plan now cites it and adds a test that `-R` is passed
