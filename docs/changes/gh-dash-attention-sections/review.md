## Round 1 — 2026-10-13T09:18Z — 86519c6c

Checks run: `ruby -Itest test/gh_dash_config_test.rb` green (11 runs, 0 failures); `yamllint` and `rubocop` on the touched files clean; the full `test/*_test.rb` loop was still running when this round was written. No REVIEW.md or REVIEW.local.md exists, so the reviewer defaults apply.

### Bugs

- [ ] Important: Section 4 misses a "changes requested" PR that has no conversation comments. GitHub's `comments:` qualifier counts issue comments only, not reviews or review comments. Live proof: `midagedev/bloomery#107` has one `CHANGES_REQUESTED` review with a 4277-character body and `comments: 0`. `is:pr review:changes_requested comments:0` returns 23707 PRs. The acceptance criterion "My open nedap PR with 'changes requested' shows in the fourth section" holds today only because `work PR G` also has a conversation comment. The plan's "accepted" trade-off covers bot and own comments, not this gap. Classic search allows no `OR`, so a fix probably needs a separate `review:changes_requested` section or a change to the intent — a decision for Etienne. — `github/.config/gh-dash/config.yml:10` →
- [ ] Important: `origin/main` already versions this file. `d5c08489` (2026-10-05) added `github/.config/gh-dash/config.yml`, and `ed85ce73` (2026-10-09) changed it. Neither commit is in this branch, which is 107 commits behind. A rebase hits an add/add conflict on the file (`git merge-tree` confirms). The main version is the `pager` and `keybindings` blocks only, byte-identical to this branch's blocks, so the branch version is a superset. The intent's premise "the config lives outside the dotfiles repository" is stale, and the stow step in the intent may already be done or planned through another change. — `github/.config/gh-dash/config.yml:1` →

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

- [ ] Important: The branch records no evidence for plan steps 6 and 7. These are the gh-dash launch, the `C` key press, and the live search checks per section. §7a requires recorded evidence, and two criteria rely on step 6 alone. The plan puts the evidence in "the implementation report", which is not on the branch, so this review cannot confirm it. — `docs/changes/gh-dash-attention-sections/plan.md:66` →
- [ ] Nit: `config` parses the YAML file again on every call. Most tests call it two or three times. `@config ||=` reads it once per test. — `test/gh_dash_config_test.rb:80` → fixed (Test: read the gh-dash config once and fetch keybindings)
- [ ] Nit: If `keybindings.prs` is missing, `config.dig("keybindings", "prs").find` raises `NoMethodError` before the `refute_nil` message can explain the failure. `fetch` or `Array(...)` gives a clean assertion failure. — `test/gh_dash_config_test.rb:68` → fixed (Test: read the gh-dash config once and fetch keybindings)
