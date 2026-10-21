# Review: gh-dash-review-keys

## Round 1 — 2026-10-21T09:58:14Z — 680ae01e

No `REVIEW.md` at the repository root; the passes follow the default policy. Checks run: `test/gh_dash_merge_test.rb` (11 runs, green), `test/gh_dash_config_test.rb` (12, green), `test/skill_parity_test.rb` (15, green), `test/vendored_skills_test.rb` (6, green), `shellcheck -x -S warning` on `merge-pr.sh` (clean), `yamllint` on `config.yml` and `openai.yaml` (clean). The added lines name no work owner. gh-dash v4.26.2 links `charm.land/bubbletea/v2@v2.0.2`, so `ctrl+m` can arrive apart from Enter under the kitty keyboard protocol.

Compliance — acceptance criteria against proof:

- `ctrl+↓` / `ctrl+↑` page the preview → manual check only; no recorded result.
- `d` shows the diff side by side → `test_diff_pager_is_delta_side_by_side` pins the pager value; the manual check has no recorded result.
- No setting: merge commit, branch deleted, no further prompt → `test_merges_with_a_merge_commit_and_deletes_the_branch_without_a_setting`; the real merge and the `r` refresh have no recorded result.
- Owner squash → `test_squashes_when_the_owner_says_squash`.
- Repository merge wins over owner squash → `test_repository_setting_wins_over_the_owner_setting`.
- `n` and Enter cancel without error → `test_any_answer_other_than_enter_cancels_without_error`.
- `M` behaves like `ctrl+m` → manual check only; no recorded result.
- README walkthrough → manual check only; no recorded result.
- Agent sets the setting from the skill → manual check only; no recorded result.

Every test named in `plan.md`'s Proof exists. `test_diff_pager_stays_delta` is renamed and updated as the plan says, not weakened.

- [ ] Important: The plan's manual Proof checks have no recorded result. Plan step 8 says to record them in the change folder, and §7a requires evidence. Missing: the `ctrl+↓`/`ctrl+↑` scroll, `d` side by side, a real `ctrl+m` merge with no further prompt and the `r` refresh, `M` equal to `ctrl+m`, the README walkthrough, and the agent check with the `pr-merge-method` skill. Five of the nine acceptance criteria rest on these checks alone. — `docs/changes/gh-dash-review-keys/plan.md:59` → fixed (Record the manual checks for gh-dash-review-keys)
- [ ] Nit: `test_settings_match_owner_and_repository_case_insensitively` only sets an owner subsection in mixed case. Its name and the plan promise the repository subsection too, which no test covers. — `test/gh_dash_merge_test.rb:60` → fixed (Test the repository setting in mixed case too)
- [ ] Nit: A `method` key with no value (`[pr-merge "eirvandelden"]` then a bare `method`) prints `unknown merge method 'eirvandelden' in pr-merge..method`. The tab `IFS` folds the empty first field, so the subsection lands in `method`. The script still exits 2 and does not merge; only the message is wrong. — `github/.config/gh-dash/scripts/merge-pr.sh:42` → fixed (Show the setting name when a merge method has no value)

## Round 2 — 2026-10-21T10:40:00Z — 238ff3a6

No `REVIEW.md` at the repository root; the passes follow the default policy in `new-repo-setup/references/REVIEW.md`. Checks run: `test/gh_dash_merge_test.rb` (12 runs, green), `test/gh_dash_config_test.rb` (12, green), `test/skill_parity_test.rb` (15, green), `test/vendored_skills_test.rb` (6, green), `shellcheck -x -S warning` on `merge-pr.sh` (clean), `yamllint` on `config.yml` and `openai.yaml` (clean). The script runs under the macOS `bash` 3.2 on `PATH`, and the tests pass with it.

Round 1 fixes hold. `evidence.md` records eight of the nine criteria as passed. `test_settings_match_owner_and_repository_case_insensitively` now sets a mixed-case repository subsection that wins over a mixed-case owner. `test_method_without_a_value_names_its_setting_in_the_error` pins the corrected message.

`evidence.md` leaves the real merge and the `r` refresh to Etienne's first real merge. That is correct: the plan's throwaway-PR check would need an agent to open and merge a pull request, which rule 5 and §7a forbid. No finding.

Bugs: no Important finding. Security: template values reach `$SHELL -c` unquoted, but GitHub limits owner and repository names to `[A-Za-z0-9._-]` and `{{.PrNumber}}` is an integer; the method is checked against an allowlist before `exec`. Compliance: every file the plan names changed as it says; `evidence.md` is the record step 8 asks for. Every test named in Proof exists; none was weakened.

- [ ] Nit: A config file git cannot parse makes `git config --get-regexp` exit 128. `2>/dev/null` hides the error, and the script offers `merge` in place of the configured method. Reproduced: with `pr-merge.eirvandelden.method squash` and a broken line after it, the prompt says `with merge`. The prompt shows the method, and every other git command fails too, so the risk is small. Fix: treat only exit 1 (no match) as "no setting" and fail on any other status. — `github/.config/gh-dash/scripts/merge-pr.sh:24` → fixed (Stop merging when git config cannot be read)
- [ ] Nit: `plan.md` step 9 spells out the work names as a grep pattern. intent.md says no work name may appear in the change. The names are already public in `config.yml` on main and `deliver` removes the folder, but the branch history keeps the line. Fix: point at the check without the literal names, for example "grep the diff for the work names in the memory note". — `docs/changes/gh-dash-review-keys/plan.md:60` → fixed (docs: drop the literal work names from the plan)

## Round 3 — 2026-10-21T12:56:23Z — 54ef7ced

No `REVIEW.md` at the repository root; the passes follow the default policy in `new-repo-setup/references/REVIEW.md`, plus a Design pass. Checks run: `test/gh_dash_merge_test.rb` (13 runs, green), `test/gh_dash_config_test.rb` (12, green), `test/skill_parity_test.rb` (15, green), `test/vendored_skills_test.rb` (6, green), `shellcheck -x -S warning` on `merge-pr.sh` (clean), `yamllint` on `config.yml` and `openai.yaml` (clean). The added lines name no work owner.

Round 2 fixes hold. `test_unreadable_git_config_fails_without_merging` pins exit 2, no prompt and no `gh` call when git config cannot be parsed; only exit 1 counts as "no setting". `plan.md` step 9 now points at the memory note and no longer spells out the names.

Bugs: no finding. Probed by hand: a capitalised value (`Squash`) exits 2 with the setting named and does not merge; names match case-insensitively, values do not, and the docs say only names do. An empty method, a missing setting, end of input and a typed answer all behave as the tests say. Security: unchanged from round 2; the method passes an allowlist before `exec`, and template values are GitHub names and an integer. Compliance: every acceptance criterion maps to a test or to a recorded check in `evidence.md`; the real merge and the `r` refresh stay with Etienne's first real merge, as round 2 settled. Every test named in Proof exists; none was weakened. Design: the script is one short flow with three small functions; the README and the skill repeat the recipes on purpose, so neither depends on the other.

The branch is 80 commits behind `origin/main`. `git merge-tree` shows no conflict: main changed only the "Work reviews" filter and its test, and `SKILLS-INDEX.md` lines elsewhere. Rebase before delivery (rule 20); that is not a code finding.

Nothing found.
