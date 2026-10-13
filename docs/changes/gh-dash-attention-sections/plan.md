# Plan: gh-dash sections for what needs my attention

From `intent.md` (2026-10-13). Status: accepted.

## Design decisions

- The config moves to `github/.config/gh-dash/config.yml`. The `github` stow package is already in `packages.conf` (`STOW` list), so no new package appears. Stow links the file into the existing real directory `~/.config/gh-dash/`, next to the untouched `config.yml.bak`.
- The `pager` block and the `C` keybinding are copied byte for byte from the live `~/.config/gh-dash/config.yml` (Etienne's machine, read on 2026-10-13). Their current text:

  ```yaml
  pager:
    diff: delta

  keybindings:
    prs:
      - key: C
        name: deep review (octo.nvim)
        command: >
          pane=$(herdr pane split --current --direction down --focus | jq -r
          '.result.pane.pane_id') && [ -n "$pane" ] && herdr pane run "$pane"
          "nvim -c 'silent Octo pr edit {{.PrNumber}} {{.RepoName}}'"
  ```

- Setting `prSections` or `issuesSections` replaces gh-dash's defaults. So the two kept defaults are written out again with the exact filters from the gh-dash v4.26.0 binary: "My Pull Requests" = `is:open author:@me`, "Involved" = `is:open involves:@me -author:@me`, "My Issues" = `is:open author:@me`. The default "Needs My Review" (`is:open review-requested:@me`) and "Assigned" (`is:open assignee:@me`) are left out.
- Every filter starts with `is:open`, like the defaults. gh-dash adds the `is:pr` / `is:issue` part itself.
- Section filters, each checked live against GitHub search on 2026-10-13 (counts in brackets):

  | View | Title | Filters |
  | --- | --- | --- |
  | PRs | Work reviews | `is:open org:nedap review-requested:@me -reviewed-by:@me draft:false` (4) |
  | PRs | Personal PRs | `is:open user:eirvandelden draft:false` (76, of which 53 dependabot) |
  | PRs | My work drafts | `is:open org:nedap author:@me draft:true` (1) |
  | PRs | My work: needs reply | `is:open org:nedap author:@me draft:false comments:>0 -review:approved` (6) |
  | PRs | My Pull Requests | `is:open author:@me` |
  | PRs | Involved | `is:open involves:@me -author:@me` |
  | Issues | Assigned to me | `is:open assignee:@me` (9) |
  | Issues | My Issues | `is:open author:@me` |
  | Issues | Involved | `is:open involves:@me -author:@me` |

- `review-requested:@me` includes team requests: it returns 4 work PRs, `user-review-requested:@me` returns 0. That satisfies "team requests included".
- Section 4 uses `comments:>0 -review:approved` (Etienne's decision, 2026-10-13, after the plan stage raised it). Live search shows that a PR whose only reviews are `COMMENTED` matches `review:none` (`work PR F`, `work PR J`, `work PR H` all have commented reviews and match `review:none`). `review:commented` does not exist (0 results). The only qualifier that also catches commented reviews is `comments:>0`, and it also counts bot and self comments: `work PR I` has only `work-bot`, `github-actions` and own comments, no review, and matches `comments:>0`. Etienne accepts that: the intent now says a PR with no comments and no review stays out of sections 3 and 4, and section 4 also shows PRs with only bot or own comments. `-review:approved` keeps approved PRs out.
- Section 4 adds `draft:false`, so a commented draft shows only in section 3. The sections stay disjoint; no acceptance criterion depends on it.
- The `org:nedap` reference is allowed in this public repository for this change only (intent constraint). No other work name enters the diff.

## Integration points

- gh-dash v4.26.0 (`gh extension` `dlvhdr/gh-dash`) reads `~/.config/gh-dash/config.yml`, or the file given with `gh dash --config <path>`.
- GitHub classic issue search (GraphQL `search(type: ISSUE)`), which gh-dash calls with each filter.
- herdr and octo.nvim, through the unchanged `C` keybinding.
- GNU Stow, through the `github` package. Etienne runs it himself (rule 12).

## Files that change

- `test/gh_dash_config_test.rb` — new. Minitest that loads the YAML and checks the sections, filters, pager and keybinding.
- `github/.config/gh-dash/config.yml` — new. The versioned gh-dash config.

No other file changes. `packages.conf` already lists `github` under `STOW`.

## Order of work

1. Write `test/gh_dash_config_test.rb` with the acceptance test `test_pr_sections_put_what_needs_action_first`. Run `ruby -Itest test/gh_dash_config_test.rb`. Watch it fail because `github/.config/gh-dash/config.yml` does not exist.
2. Add the other tests from `## Proof` to the same file. Run it; all fail for the same reason.
3. Create `github/.config/gh-dash/config.yml`: the `prSections` and `issuesSections` from the table above, then the `pager` and `keybindings` blocks copied verbatim. Run the test file until green.
4. Run `yamllint github/.config/gh-dash/config.yml` and `rubocop test/gh_dash_config_test.rb`. Fix every finding without disable comments.
5. Preflight: run `gh auth status`. If it does not report an active, valid login, stop and report that Etienne must reauthenticate; do not skip steps 6 and 7.
6. Run `gh dash --config github/.config/gh-dash/config.yml` in a herdr pane. Confirm it opens on "Work reviews" with no config error. Select a PR and press `C`: confirm a herdr pane opens below and runs `nvim -c 'silent Octo pr edit <number> <repo>'` for that PR. Switch to the issues view and confirm it opens on "Assigned to me". Record what you saw.
7. Live search check: run each PR and issue filter through `gh api graphql` search (`type: ISSUE`) with `is:pr` / `is:issue` prepended. Record counts. For each named PR, also fetch `isDraft`, `reviewDecision`, `reviewRequests` (user or team) and `reviews` (state, author), and record them next to its section membership:
   - Section 1: at least one PR whose review request is a team, not me directly, and that has no review by me.
   - Post-review exclusion: run the section 1 filter without `-reviewed-by:@me`, and list any PR it adds; each must have a review by me. If none exists today, say so.
   - Section 2: at least one `app/dependabot` PR in an `eirvandelden` repository; and the 2 open `eirvandelden` drafts are absent.
   - Section 3: `work PR E` (draft) is present and is absent from section 1.
   - Section 4: `work PR G` (changes requested) and `work PR F` (only commented reviews) are present; `work PR I` (only bot and own comments) is present too, as accepted. A non-draft work PR of mine with `comments:0` is absent from sections 3 and 4; if none exists today, say so.
   - Approved: `is:open org:nedap author:@me review:approved` returned 0 on 2026-10-13. If it is still 0, say so; else confirm each is absent from section 4 and present in "My Pull Requests".
   - PR numbers come from the 2026-10-13 probe. Use whatever matching PRs exist at implementation time and say so if they changed.
8. Run the full suite so a failure fails the command: `(set -e; for file in test/*_test.rb; do ruby -Itest "$file"; done)`.
9. Grep the diff for work names: `git diff main -- . ':!docs' | grep -inE 'nedap|<work repo names>'`. Only the `org:nedap` filters may match.
10. Commit test and config together: `gh-dash: version the config with attention sections`.

## Risks

- Section 4 shows PRs whose only comments come from bots or from me (today `work PR I`). Accepted by Etienne in exchange for catching the 4 PRs with only commented reviews.
- Stow conflict: `~/.config/gh-dash/config.yml` is a real file today. `stow github` refuses until Etienne trashes it. The implement stage never touches it.
- `-reviewed-by:@me` hides a PR where my review was re-requested after I reviewed (accepted in intent).
- `smartFilteringAtLaunch` stays on: inside a repository every section narrows to that repository, so a personal-repo run shows empty work sections. Accepted in intent.
- gh-dash may add `is:pr` and also respect a user `is:pr`; the plan leaves it out to match the defaults. Step 6 catches a load error.
- Rejected: one section with `OR` (classic search returns 0 results; checked live, `review-requested:@me OR draft:true` returns 0).
- Rejected: `archived:false` on section 2. The intent does not ask for it.

## Proof

- A non-draft nedap PR with a team review request for me, unreviewed, shows in the first PR section → `test/gh_dash_config_test.rb` `test_pr_sections_put_what_needs_action_first` (title order) and `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts` (filter has `org:nedap`, `review-requested:@me`, `-reviewed-by:@me`, `draft:false`, and no `user-review-requested`); live: Order of work step 7.
- After I review that PR, it leaves the first section even if the team request stays → `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts` (`-reviewed-by:@me`).
- A draft nedap PR with a review request for me does not show in the first section → `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts` (`draft:false`); live: step 7.
- A non-draft dependabot PR in an `eirvandelden` repository shows in the second section; a draft there does not → `test_personal_section_takes_every_ready_pr_in_my_repositories` (filter is `user:eirvandelden draft:false` with no `author:` qualifier); live: step 7.
- My open nedap draft shows in the third section → `test_drafts_section_takes_my_open_work_drafts`; live: step 7.
- My open nedap PR with "changes requested" shows in the fourth section → `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved`; live: step 7.
- My open nedap PR with only commented reviews shows in the fourth section → `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved` (`comments:>0`); live: step 7 with `work PR F`.
- My open approved nedap PR does not show in the fourth section; it shows in "My Pull Requests" → `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved` (`-review:approved`) and `test_default_pr_sections_follow_with_their_gh_dash_filters`.
- My open non-draft nedap PR with no comments and no review shows in neither section 3 nor 4 → `test_drafts_section_takes_my_open_work_drafts` (`draft:true`) and `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved` (`comments:>0`); live: step 7.
- The default "Needs My Review" is gone; "My Pull Requests" and "Involved" follow → `test_pr_sections_put_what_needs_action_first` and `test_default_pr_sections_follow_with_their_gh_dash_filters`.
- The issues view opens on open issues assigned to me; "Assigned" is gone → `test_issue_sections_open_on_issues_assigned_to_me`.
- The `C` keybinding still opens the PR in octo.nvim through herdr → `test_deep_review_keybinding_opens_octo_in_a_herdr_pane` (exact command text) and `test_diff_pager_stays_delta`; check: Order of work step 6 (press `C` on a PR).
- After Etienne restows `github`, the config is a symlink into dotfiles and gh-dash loads it without errors → `test_config_is_valid_yaml_inside_the_github_stow_package`; check: Order of work step 6 (`gh dash --config github/.config/gh-dash/config.yml` opens without error). The symlink itself: check: Etienne runs `trash ~/.config/gh-dash/config.yml && stow -t "$HOME" -R github`, then `readlink ~/.config/gh-dash/config.yml` points into dotfiles. Agents never run this.
- No section uses `OR` (constraint) → `test_no_filter_uses_or`.

Per changed file, the unit tests expected:

- `test/gh_dash_config_test.rb`: `test_config_is_valid_yaml_inside_the_github_stow_package`, `test_pr_sections_put_what_needs_action_first`, `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts`, `test_personal_section_takes_every_ready_pr_in_my_repositories`, `test_drafts_section_takes_my_open_work_drafts`, `test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved`, `test_default_pr_sections_follow_with_their_gh_dash_filters`, `test_issue_sections_open_on_issues_assigned_to_me`, `test_no_filter_uses_or`, `test_deep_review_keybinding_opens_octo_in_a_herdr_pane`, `test_diff_pager_stays_delta`.
- `github/.config/gh-dash/config.yml`: covered by the test file above; no code of its own.

Test setup: `YAML.safe_load_file` on `github/.config/gh-dash/config.yml`, path from `File.expand_path("../github/.config/gh-dash/config.yml", __dir__)`, like `test/herdr_config_test.rb`. Compare filters as whitespace-split token sets, so token order does not matter but no token is missing or extra. No network, no gh-dash binary in the unit tests; the live checks are Order of work steps 6 and 7 and their evidence is recorded in the implementation report.

## Out of scope

- `smartFilteringAtLaunch`, notification sections, layouts, theme, other keybindings.
- `~/.config/gh-dash/config.yml.bak`.
- Running `stow`, or touching anything under `~/.config/gh-dash/`.
- `github/.config/gh/` files.

---
Domain skills applied: dotfiles-maintenance (stow package layout, rule 12), rails-testing (Minitest shape only). None of the Rails domain skills apply.

## Critique

### Round 1 (codex exec -p terra)

- Section 4 uses only `review:changes_requested`, which drops the "or commented" part of the accepted in-scope list; amend the intent with Etienne's choice → dismissed: the plan cannot change an accepted intent; it follows the binding acceptance criteria, records the live evidence, and raises the conflict as a decision for Etienne in Risks and in the stage report. Etienne chose `comments:>0 -review:approved` on 2026-10-13; intent and plan now say so.
- The AND-only constraint is not established, since GitHub documents `OR` for issue search; rerun the query before enforcing `test_no_filter_uses_or` → dismissed: the live GraphQL `search(type: ISSUE)` probe on 2026-10-13 returned 4 for `is:pr is:open org:nedap review-requested:@me` and 0 for the same with `OR draft:true`, so classic search does not honour `OR`; that result is recorded under Risks.
- The full-suite loop with `|| break` exits 0 after a failed test → fixed (step 8 now runs the loop in a `set -e` subshell)
- The `C` keybinding criterion has no runtime proof; the manual step never presses `C` → fixed (step 6 presses `C` on a PR and checks the herdr pane runs the Octo command; the Proof line names that check)
- The live check covers counts and three examples only, not team requests, the post-review exclusion, dependabot, or approved PRs → fixed (step 7 lists a named check per criterion, with the review-request and review fields recorded)
- `gh auth status` reports an invalid token, so live checks would block → fixed (step 5 adds an auth preflight that stops and reports; in the plan author's shell `gh auth status` shows a valid `eirvandelden` login, so the critic's failure comes from its read-only sandbox)
