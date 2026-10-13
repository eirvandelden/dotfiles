## Round 1 — 2026-10-13T11:48Z — cd9d1208

- [ ] Important: `ship` merges with pending checks after a failed watch. When `gh pr checks --watch --fail-fast` fails for any reason except "no checks reported" (auth, network blip during a long watch), `Checks#wait` returns as if the watch had finished. `failed` then selects only `fail`/`cancel` buckets, so `pending` counts as green and `merge` runs before CI ends. Treat only `pass`/`skipping` as green, or stop when the watch fails and no check has failed — `claude/.claude/skills/finish/scripts/ship:57` →
- [ ] Important: Stale "finish opens the PR" wording remains. Playbook rule 16 still says "`finish` checks it before it opens one", which contradicts rule 5 in the same file. The `review-report-fresh` header says "finish runs it that way before it opens the PR"; `deliver` runs it now — `agents.md:149`, `git/.config/git/worktree-tools/review-report-fresh:11` →
- [ ] Nit: `ship` drops the stderr of `gh pr merge`. A merge refused for a definite reason (conflict, branch protection) waits the full `SHIP_MERGE_WAIT` (900 s), then reports only "PR is OPEN, not merged in time", without gh's reason — `claude/.claude/skills/finish/scripts/ship:106` →
- [ ] Nit: A failed `herdr pane list` raises after the PR exists and the saved body is gone. `deliver` exits 1, and a rerun refuses because `review.md` is gone and the resume files are deleted. An unset `HERDR_WORKSPACE_ID` also passes `--workspace ""`; `worktree-pane` drops the flag in that case. Treat pane closing as best effort, like `open_dash` — `claude/.claude/skills/deliver/scripts/deliver:184` →
- [ ] Nit: `reviewer.md` Output now asks for the `deliver --check` result, but its Rules limit `Bash` to git, push and the project's test and lint commands. `deliver --check` is not in that list. The same mismatch is in the generated Codex `reviewer.toml` — `claude/.claude/agents/reviewer.md:36` →
- [ ] Nit: `deliver` anchors the gh-dash pane on the intent pane and then closes that pane when it is an idle stage pane in this worktree. After a `hand-off-plan.sh intent` start, the pane that acceptance criterion 2 names is gone at the end of delivery. The plan's departures note records the order, but not this result — `claude/.claude/skills/deliver/scripts/deliver:255` →
- [ ] Nit: The `finish` "Auto mode" section is no longer on the coordinator's path. Intent step 6 runs `ship --no-merge` directly and never follows `finish` auto mode. So that section's personal-scope and `Delivery: autonomous` checks are dead text. Point intent step 6 at it, or drop the duplicate — `claude/.claude/skills/finish/SKILL.md:59` →

1 further nit not listed.

Compliance:

- AC1 closed review → folder gone in own commit, branch on origin, draft PR with filled body: `test/deliver_test.rb` `test_a_closed_review_ends_in_a_draft_pr_without_the_change_folder`, `test/delivery_contract_test.rb` `test_review_runs_delivery_when_no_finding_is_open`.
- AC2 gh-dash pane directly left of intent pane A: `test/open_pr_dash_test.rb` `test_opens_gh_dash_directly_left_of_the_intent_pane`, `test/delivery_contract_test.rb` `test_intent_records_its_pane_on_accept`. The live check in Proof (`herdr pane layout` evidence) is not in the diff; the coordinator records it.
- AC3 pane A closed → left of own pane: `test/open_pr_dash_test.rb` `test_falls_back_to_the_own_pane_when_the_intent_pane_is_gone`.
- AC4 outside herdr → URL printed, no pane: `test/deliver_test.rb` `test_outside_herdr_prints_the_pr_url_and_opens_no_pane`, `test/open_pr_dash_test.rb` same name.
- AC5 autonomous: draft, ready, green CI, unmerged: `test/ship_test.rb` `test_no_merge_marks_ready_waits_for_green_and_leaves_the_pr_open`, `test/delivery_contract_test.rb` `test_the_coordinator_delivers_then_ships_without_merging`.
- AC6 personal `/finish` green → merge commit, remote branch deleted: `test/ship_test.rb` `test_ships_a_green_pr_with_a_merge_commit_and_deletes_the_remote_branch`.
- AC7 personal `/finish` failed check → unmerged, names check and link: `test/ship_test.rb` `test_a_failed_check_stops_unmerged_and_names_the_check_and_link`.
- AC8 work `/finish` → ready, board "Needs Review", reviewers, Edge: `test/delivery_contract_test.rb` `test_work_finish_runs_after_push_then_requests_reviewers`; the board test lives in `dotfiles-work` (`test_sets_the_board_status_to_needs_review`), outside this diff.
- AC9 no PR → "delivery step has not run": `test/ship_test.rb` `test_refuses_a_branch_without_a_pr`, `test/delivery_contract_test.rb` `test_work_finish_refuses_without_a_pr`.
- AC10 no work org, board or project name: check run on the full branch diff and the commit messages against the allowed-remotes owners, the board owner, the project number and the live board title. No match.
- AC11 Codex parity: `test/skill_parity_test.rb` (green, covers the `deliver` link), `test/delivery_contract_test.rb` `test_deliver_and_finish_name_their_codex_invocation`.
- Proof tests: every test named in `plan.md` `## Proof` exists in this repository. The per-file item "splits right then swaps to the left" is folded into `test_opens_gh_dash_directly_left_of_the_intent_pane`.
- Changed existing tests: `consent_guard_test.rb` and `pull_request_flow_test.rb` were renamed from finish to deliver with equal strength. `autonomy_contract_test.rb` replaces the old finish body-confirmation test with a deliver equivalent. No test was skipped or deleted without a replacement.

Checks: full suite green except `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, which also errors on main. RuboCop, shellcheck and markdownlint are clean on the changed files.
