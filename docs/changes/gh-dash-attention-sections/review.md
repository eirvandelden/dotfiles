## Round 1 — 2026-10-13T09:18Z — 86519c6c

Checks run: `ruby -Itest test/gh_dash_config_test.rb` green (11 runs, 0 failures); `yamllint` and `rubocop` on the touched files clean; the full `test/*_test.rb` loop was still running when this round was written. No REVIEW.md or REVIEW.local.md exists, so the reviewer defaults apply.

### Bugs

- [ ] Important: Section 4 misses a "changes requested" PR that has no conversation comments. GitHub's `comments:` qualifier counts issue comments only, not reviews or review comments. Live proof: `midagedev/bloomery#107` has one `CHANGES_REQUESTED` review with a 4277-character body and `comments: 0`. `is:pr review:changes_requested comments:0` returns 23707 PRs. The acceptance criterion "My open nedap PR with 'changes requested' shows in the fourth section" holds today only because `work PR G` also has a conversation comment. The plan's "accepted" trade-off covers bot and own comments, not this gap. Classic search allows no `OR`, so a fix probably needs a separate `review:changes_requested` section or a change to the intent — a decision for Etienne. — `github/.config/gh-dash/config.yml:10` → fixed (gh-dash: add a section for my work PRs with changes requested): Etienne chose a fifth section on 2026-10-13
- [ ] Important: `origin/main` already versions this file. `d5c08489` (2026-10-05) added `github/.config/gh-dash/config.yml`, and `ed85ce73` (2026-10-09) changed it. Neither commit is in this branch, which is 107 commits behind. A rebase hits an add/add conflict on the file (`git merge-tree` confirms). The main version is the `pager` and `keybindings` blocks only, byte-identical to this branch's blocks, so the branch version is a superset. The intent's premise "the config lives outside the dotfiles repository" is stale, and the stow step in the intent may already be done or planned through another change. — `github/.config/gh-dash/config.yml:1` → fixed (docs: record live evidence for gh-dash-attention-sections): rebased onto origin/main; the add/add conflict resolved to the branch version, a superset of main's identical pager and keybinding blocks; the stale premise is noted under Base in evidence.md

### Security

Nothing found. The `org:nedap` filters are the only work names in the non-docs diff, as the intent allows. The `C` command is byte-identical to the live config and to `origin/main`.

### Compliance

| Acceptance criterion | Proof in the diff |
| --- | --- |
| Team-requested, unreviewed, non-draft nedap PR in section 1 | `test_pr_sections_put_what_needs_action_first`, `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts` |
| Leaves section 1 after my review | `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts` (`-reviewed-by:@me`) |
| Draft nedap PR not in section 1 | `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts` (`draft:false`) |
| Dependabot PR in section 2; draft not | `test_personal_section_takes_every_ready_pr_in_my_repositories` |
| My nedap draft in section 3 | `test_drafts_section_takes_my_open_work_drafts` |
| "Changes requested" PR in section 4 | `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved` — the filter test passes, but the filter does not meet the criterion in general (see Bugs) |
| Commented-reviews-only PR in section 4 | `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved` |
| Approved PR not in section 4, in "My Pull Requests" | `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved`, `test_default_pr_sections_follow_with_their_gh_dash_filters` |
| Uncommented non-draft PR in neither section 3 nor 4 | `test_drafts_section_takes_my_open_work_drafts`, `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved` |
| "Needs My Review" gone; defaults follow | `test_pr_sections_put_what_needs_action_first`, `test_default_pr_sections_follow_with_their_gh_dash_filters` |
| Issues view opens on assigned issues; "Assigned" gone | `test_issue_sections_open_on_issues_assigned_to_me` |
| `C` still opens octo.nvim through herdr | `test_deep_review_keybinding_opens_octo_in_a_herdr_pane`, `test_diff_pager_stays_delta`; runtime check (plan step 6) has no evidence on the branch |
| Symlink after restow; gh-dash loads without errors | `test_config_is_valid_yaml_inside_the_github_stow_package`; runtime check (plan step 6) has no evidence on the branch; the symlink is Etienne's step |

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted.

- [ ] Important: The branch records no evidence for plan steps 6 and 7. These are the gh-dash launch, the `C` key press, and the live search checks per section. §7a requires recorded evidence, and two criteria rely on step 6 alone. The plan puts the evidence in "the implementation report", which is not on the branch, so this review cannot confirm it. — `docs/changes/gh-dash-attention-sections/plan.md:66` → fixed (docs: record live evidence for gh-dash-attention-sections)
- [ ] Nit: `config` parses the YAML file again on every call. Most tests call it two or three times. `@config ||=` reads it once per test. — `test/gh_dash_config_test.rb:80` → fixed (Test: read the gh-dash config once and fetch keybindings)
- [ ] Nit: If `keybindings.prs` is missing, `config.dig("keybindings", "prs").find` raises `NoMethodError` before the `refute_nil` message can explain the failure. `fetch` or `Array(...)` gives a clean assertion failure. — `test/gh_dash_config_test.rb:68` → fixed (Test: read the gh-dash config once and fetch keybindings)

## Round 2 — 2026-10-13T09:20Z — 86519c6c (codex)

`codex review --base origin/main`: the configuration and tests match the stated section order and filters; `ruby -Itest test/gh_dash_config_test.rb` passes (11 runs, 35 assertions).

No findings.

## Round 3 — 2026-10-13T11:05Z — a4fcaff2

Checks run: `ruby -Itest test/gh_dash_config_test.rb` green (12 runs, 38 assertions, 0 failures); `yamllint github/.config/gh-dash/config.yml` and `rubocop test/gh_dash_config_test.rb` clean. The full `test/*_test.rb` loop did not finish within 10 minutes; other sessions ran heavy suites at the same time, so this round has no full-suite result. The branch contains `origin/main` (0 commits behind). No REVIEW.md or REVIEW.local.md exists, so the reviewer defaults apply.

### Bugs

Nothing found. The section 5 filter `is:open org:nedap author:@me draft:false review:changes_requested` catches a "changes requested" PR without comments, which closes the round 1 finding. Its overlap with section 4 is accepted in the intent.

### Security

- [ ] Important: The change folder names private work repositories and PR numbers: `work repo 1`, `work repo 2`, `work repo 3`, and PRs such as work PR A and work PR E. The intent allows only the `org:nedap` reference in this public repository. Plan step 9 greps with `':!docs'`, so it misses these. `finish` removes the folder, but `origin/main` merges with merge commits (for example `f4060ba3`), so the commits that add these names stay in public history. The branch is already on the public `origin`. Fix: replace the names with neutral labels ("a work PR" → "work PR A") before the merge, or squash the change-folder commits away; Etienne decides whether the already-pushed refs matter. — `docs/changes/gh-dash-attention-sections/evidence.md:9`, also `evidence.md:14-20`, `plan.md:42,72-73,82,98`, `review.md:7` → fixed (docs: describe the gh-dash config as extended, not new): Etienne chose a history rewrite on 2026-10-13; every branch commit now uses neutral labels (work repo 1–3, work PR A–K) and the branch was pushed with --force-with-lease

### Compliance

| Acceptance criterion | Proof in the diff |
| --- | --- |
| Team-requested, unreviewed, non-draft nedap PR in section 1 | `test_pr_sections_put_what_needs_action_first`, `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts`; live: evidence.md step 7 |
| Leaves section 1 after my review | `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts` (`-reviewed-by:@me`); live: no example today, recorded |
| Draft nedap PR not in section 1 | same test (`draft:false`); live: no example today, recorded |
| Dependabot PR in section 2; draft not | `test_personal_section_takes_every_ready_pr_in_my_repositories`; live: 53 dependabot, 0 drafts |
| My nedap draft in section 3 | `test_drafts_section_takes_my_open_work_drafts`; live: recorded |
| "Changes requested" PR in section 4 | `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved`; live: recorded |
| Commented-reviews-only PR in section 4 | same test (`comments:>0`); live: recorded |
| "Changes requested" PR without inline comments in section 5 | `test_changes_requested_section_takes_my_ready_work_prs_with_changes_requested`; live: 1 PR, recorded |
| Approved PR not in section 4, in "My Pull Requests" | `-review:approved` test, `test_default_pr_sections_follow_with_their_gh_dash_filters`; live: 0 approved today, recorded |
| Uncommented non-draft PR in neither section 3 nor 4 | `draft:true` and `comments:>0` tests; live: 16 such PRs absent, recorded |
| "Needs My Review" gone; defaults follow | `test_pr_sections_put_what_needs_action_first`, `test_default_pr_sections_follow_with_their_gh_dash_filters` |
| Issues view opens on assigned issues; "Assigned" gone | `test_issue_sections_open_on_issues_assigned_to_me`; live: evidence.md step 6 |
| `C` still opens octo.nvim through herdr | `test_deep_review_keybinding_opens_octo_in_a_herdr_pane`, `test_diff_pager_stays_delta`; live: evidence.md step 6 |
| Symlink after restow; gh-dash loads without errors | `test_config_is_valid_yaml_inside_the_github_stow_package`; load: evidence.md step 6; the symlink stays Etienne's step |

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted. The non-docs diff contains only the `org:nedap` work reference that the intent allows.

- [ ] Nit: `plan.md` still lists the config as "new" and the intent still says the config lives outside dotfiles. The branch modifies the file that `origin/main` already ships (recorded in evidence.md under Base). A pull request body drafted from these files would describe the change wrongly. — `docs/changes/gh-dash-attention-sections/plan.md:56` → fixed (docs: describe the gh-dash config as extended, not new)

## Round 4 — 2026-10-13T12:00Z — b5e2a4c9

Checks run: `ruby -Itest test/gh_dash_config_test.rb` green (12 runs, 38 assertions, 0 failures); `yamllint github/.config/gh-dash/config.yml` and `rubocop test/gh_dash_config_test.rb` clean. The full `test/*_test.rb` loop was not run in this round. The branch is 45 commits behind `origin/main`; `git merge-tree` merges it cleanly, and `origin/main` has no new change to the gh-dash config or its test. No REVIEW.md or REVIEW.local.md exists, so the reviewer defaults apply.

### Bugs

Nothing found. The five new PR sections and the three issue sections match the plan's filter table token for token. The kept `pager` and `C` keybinding are unchanged from `origin/main`.

### Security

- [ ] Nit: `plan.md:42` names the bot `work-bot` next to `work PR I`. If that bot belongs to the work organisation, it is a work name in this public repository, which the intent does not allow (it allows only `org:nedap`). The round 3 relabel and plan step 9 (`':!docs'`) both miss it. Fix: say "a work bot" if it is internal; dismiss if the bot is public. — `docs/changes/gh-dash-attention-sections/plan.md:42` → fixed (docs: describe the plan steps against the shipped gh-dash config): the bot is internal; the branch history was rewritten again so every commit says `work-bot`

### Compliance

Every acceptance criterion keeps the proof listed in round 3; this round adds no code. Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted.

- [ ] Nit: `plan.md` still says the config "moves to" `github/.config/gh-dash/config.yml` (line 7), that step 1 fails because the file "does not exist" (line 62), and that step 3 "Create"s it (line 64). Round 3's fix changed only line 56. `origin/main` already ships the file, so these lines describe a change that did not happen. — `docs/changes/gh-dash-attention-sections/plan.md:7` → fixed (docs: describe the plan steps against the shipped gh-dash config)
- [ ] Nit: Round 1 says `comments:` counts issue comments only, but `evidence.md:19` shows it counts inline review comments too (work PR G and work PR F have 0 issue comments and match `comments:>0`). The round 1 finding stays valid for a review body without inline comments, which section 5 now covers. No action beyond awareness when writing the pull request body. — `docs/changes/gh-dash-attention-sections/evidence.md:19` → dismissed: awareness only; evidence.md records the correct behaviour and section 5 covers the remaining gap

## Round 5 — 2026-10-13T12:10Z — a4fcaff2 (codex)

`codex review --base origin/main` on the commit that added section 5 (pre-rewrite SHA): configuration matches the stated section order and filters; the focused test passes.

No findings.

## Round 6 — 2026-10-13T12:15Z — b5e2a4c9 (codex)

`codex review --base origin/main` after the round 3 fixes (pre-rewrite SHA): the configuration and tests match the stated section order and filters; the focused test passes (12 runs, 38 assertions).

No findings.
