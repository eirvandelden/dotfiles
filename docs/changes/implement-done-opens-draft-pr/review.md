## Round 1 — 2026-10-13T11:48Z — cd9d1208

- [ ] Important: `ship` merges with pending checks after a failed watch. When `gh pr checks --watch --fail-fast` fails for any reason except "no checks reported" (auth, network blip during a long watch), `Checks#wait` returns as if the watch had finished. `failed` then selects only `fail`/`cancel` buckets, so `pending` counts as green and `merge` runs before CI ends. Treat only `pass`/`skipping` as green, or stop when the watch fails and no check has failed — `claude/.claude/skills/finish/scripts/ship:57` → fixed (Ship treats only passing or skipped checks as green)
- [ ] Important: Stale "finish opens the PR" wording remains. Playbook rule 16 still says "`finish` checks it before it opens one", which contradicts rule 5 in the same file. The `review-report-fresh` header says "finish runs it that way before it opens the PR"; `deliver` runs it now — `agents.md:149`, `git/.config/git/worktree-tools/review-report-fresh:11` → fixed (Name deliver, not finish, as the step that opens the PR)
- [ ] Nit: `ship` drops the stderr of `gh pr merge`. A merge refused for a definite reason (conflict, branch protection) waits the full `SHIP_MERGE_WAIT` (900 s), then reports only "PR is OPEN, not merged in time", without gh's reason — `claude/.claude/skills/finish/scripts/ship:106` → fixed (Ship stops at once with gh's reason when it refuses the merge)
- [ ] Nit: A failed `herdr pane list` raises after the PR exists and the saved body is gone. `deliver` exits 1, and a rerun refuses because `review.md` is gone and the resume files are deleted. An unset `HERDR_WORKSPACE_ID` also passes `--workspace ""`; `worktree-pane` drops the flag in that case. Treat pane closing as best effort, like `open_dash` — `claude/.claude/skills/deliver/scripts/deliver:184` → fixed (Deliver closes stage panes on a best-effort basis)
- [ ] Nit: `reviewer.md` Output now asks for the `deliver --check` result, but its Rules limit `Bash` to git, push and the project's test and lint commands. `deliver --check` is not in that list. The same mismatch is in the generated Codex `reviewer.toml` — `claude/.claude/agents/reviewer.md:36` → fixed (Let the reviewer run deliver --check)
- [ ] Nit: `deliver` anchors the gh-dash pane on the intent pane and then closes that pane when it is an idle stage pane in this worktree. After a `hand-off-plan.sh intent` start, the pane that acceptance criterion 2 names is gone at the end of delivery. The plan's departures note records the order, but not this result — `claude/.claude/skills/deliver/scripts/deliver:255` → fixed (Record the stage panes each change opens; Deliver closes only the stage panes this change opened)
- [ ] Nit: The `finish` "Auto mode" section is no longer on the coordinator's path. Intent step 6 runs `ship --no-merge` directly and never follows `finish` auto mode. So that section's personal-scope and `Delivery: autonomous` checks are dead text. Point intent step 6 at it, or drop the duplicate — `claude/.claude/skills/finish/SKILL.md:59` → fixed (Coordinator ships through finish's auto mode)

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

## Round 2 (Codex) — 2026-10-13T11:34Z — cd9d1208

- [ ] Important: `deliver` closes every idle or done agent pane whose `cwd` is this worktree. An unrelated agent sharing the worktree, and the recorded intent pane itself, match that filter, so delivery can close panes that are not this change's stage workers. Track the panes this change opened and close only those — `claude/.claude/skills/deliver/scripts/deliver:179` → fixed (Record the stage panes each change opens; Deliver closes only the stage panes this change opened)

Checks: Codex ran `deliver_test`, `ship_test`, `open_pr_dash_test` and `delivery_contract_test`; all green.

## Round 3 — 2026-10-13T12:58Z — 00d1c0d5

- [ ] Important: `plan.md` no longer describes the code. Design decision 17 still selects panes by `cwd` = worktree toplevel; the code closes only panes listed in `stage-panes-<slug>`, with a terminal-id match, and never the intent pane. Ship step 4 still reads "any `fail` or `cancel`"; only `pass`/`skipping` count as green now. Ship step 6 still polls "even when the merge command exits non-zero"; a refused merge without auto-merge now stops at once. Decision 12 and the `intent` line in "Files that change" still run `ship --no-merge` directly. The first departure gives a reason that no longer holds, because the intent pane is never closed. "Departures during implementation" records none of these changes. "Files that change" feeds the PR body and omits the stage-pane recording in `hand-off-plan.sh` and `start-review.sh`, plus the `reviewer.md` Bash allowance — `docs/changes/implement-done-opens-draft-pr/plan.md:136` → fixed (Bring plan.md in line with the reviewed implementation)
- [ ] Nit: Red CI is often reported as unfinished CI. `--fail-fast` exits on the first failure while sibling checks are still `pending`. So `unfinished_note` puts "CI has not finished; PR left unmerged." first, then the whole `--watch` output, then the pending checks and the failed one together. The AC7 data is present, but the failed check is not singled out. No test covers a fail plus a pending check — `claude/.claude/skills/finish/scripts/ship:94` → fixed (Report a failed check before the pending ones in ship)

Closed findings checked against the code:

- R1 Important 1 (pending counts as green): holds. `GREEN = pass, skipping`; a failed watch returns gh's reason; an unreadable checks list stops unmerged. Covered by four new `ship_test.rb` tests. Checked against gh 2.102.0: `gh pr checks --json` exits 0 with failed checks, so `listed` reads the list in the red case.
- R1 Important 2 (stale "finish opens the PR"): holds in rule 16, the `review-report-fresh` header and the `fill-pr-template` header. A `git grep` outside `docs/changes` and `test` finds no other "finish opens/creates the PR" wording.
- R1 Nit (merge stderr dropped): holds. A refused merge with `autoMergeRequest` null stops after one `pr view` with gh's stderr; MERGED and auto-merge still win.
- R1 Nit (pane list failure after the PR exists): holds. `Refusal` and `JSON::ParserError` only warn; `--workspace` is omitted when `HERDR_WORKSPACE_ID` is empty.
- R1 Nit (reviewer Bash rule): holds in `reviewer.md` and the regenerated `reviewer.toml`; contract test added.
- R1 Nit (intent pane closed after anchoring): holds. `kept` holds `$HERDR_PANE_ID` and the first line of `intent-pane-<slug>`.
- R1 Nit (finish auto mode dead text): holds. Intent step 6 checks `Delivery: autonomous` before `deliver`, then follows `finish` auto mode; only `finish` names `ship --no-merge`.
- R2 Important (unrelated panes closed): holds. `hand-off-plan.sh` and `start-review.sh` append `<pane_id> <terminal_id>`. Live herdr 0.9.3 confirms that `pane get` has `.result.pane.terminal_id` and `pane list` carries `terminal_id`. `deliver` closes only recorded pairs that are idle or done, and never its own or the intent pane.

Compliance: the acceptance-criteria mapping from round 1 still holds. Every test named in `plan.md` `## Proof` exists. Fix commits weakened, skipped or deleted no test. The removed `w1:pElsewhere` case is now outside the selection by construction, because unlisted panes are never closed.

Checks: full suite green except `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, which also errors on main. RuboCop, shellcheck and markdownlint (no-hardwrap) are clean on the changed files. The branch is 13 commits behind `origin/main` and rebases without conflicts.

## Round 4 (Codex) — 2026-10-13T13:05Z — 00d1c0d5

- [ ] Important: `deliver --check` treats any text after a finding's `→` as closed, so `→ still investigating` lets delivery proceed. The review skill allows only `fixed (<commit subject>)` or `dismissed: <reason>`; validate those markers instead of accepting any non-empty text — `claude/.claude/skills/deliver/scripts/deliver:57` → fixed (Close a finding only on a valid fixed or dismissed marker)

Checks: Codex ran the deliver, ship, pane and contract tests; all green. None covers an invalid close marker.

## Round 5 — 2026-10-13T13:44Z — dbbb13b8

Scope: `ce0ca5ae..HEAD` only.

- [ ] Nit: `CLOSED_SLOT` rejects a commit subject that contains `)`. The `fixed` branch is `fixed \(\s*[^)\s][^)]*\)` followed by `\s*\z`, so `→ fixed (Fix foo (bar))` counts as open, and `deliver --check` exits 1 on a correctly closed finding. It fails safe, but the only way out is to reword the subject. Match greedily up to the last `)` on the line — `claude/.claude/skills/deliver/scripts/deliver:42` → dismissed: fails safe (blocks delivery, never lets an open finding through), and it matches the rule plan/scripts/auto-accept already uses; reword the subject in the rare case it bites.

Closings checked: every `fixed (<subject>)` in this file names a subject that exists in `git log --format=%s origin/main..HEAD`. The two-commit closings write both subjects joined by `; `, and each one exists. `deliver --check` exits 0 on this file before this round.

Fixes checked: R3 Important (plan.md) and R3 Nit (failed before pending) hold; R4 Important (marker validation) holds, and `test_a_finding_without_a_valid_close_marker_is_open` covers the six invalid markers. No test was weakened, skipped or deleted in this range.

Checks: full suite not run (Etienne's call); narrow tests only. `test_a_finding_without_a_valid_close_marker_is_open` and `test_a_failed_check_beside_a_pending_one_reports_the_failure_first` pass. RuboCop is clean on `deliver`, `ship`, `deliver_test.rb` and `ship_test.rb`.

## Round 6 (Codex) — 2026-10-13T14:10Z — dbbb13b8

No findings. Codex reviewed the fixes since round 4 (close-marker validation, failed-before-pending reporting in `ship`, `plan.md` and `review.md` updates) and found no actionable regression.
