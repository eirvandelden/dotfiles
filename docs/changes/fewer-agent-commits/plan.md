# Plan: Fewer agent commits

From `intent.md` (2026-10-15). Status: accepted.

## Context

Today the change flow commits per stage and per review round:

- `intent` commits `intent.md` alone and pushes (`claude/.claude/skills/intent/SKILL.md` step 4; `herdr/.config/herdr/scripts/hand-off-plan.sh` intent prompt).
- `plan` commits `plan.md` alone (`claude/.claude/skills/plan/SKILL.md` step 7 and Auto mode step 5).
- The `reviewer` agent commits and pushes `review.md` after every round (`claude/.claude/agents/reviewer.md` steps 7–8; `start-review.sh` prompt). The autonomous coordinator commits each transcribed Codex or Claude CLI round alone (`review/SKILL.md` Auto mode; `intent/SKILL.md` Autonomous delivery step 5). `code-review` commits finding closures with a fix or alone.
- `deliver` removes `docs/changes/<slug>/` in the commit `Remove change artifacts for <slug>`. Nothing brings the folder back.

This repository is the dotfiles repository (personal, `eirvandelden/dotfiles`). Tests are Minitest files under `test/`, run one file at a time with `ruby -Itest test/<name>_test.rb`. Linters: RuboCop (`rubocop/.rubocop.yml`, run by lefthook), markdownlint, shellcheck where lefthook runs it.

## Design decisions

1. **One script commits review.md: `review/scripts/commit-review`.** It reads `<folder>/review.md`. When the file has a round and no open finding, it stages that file alone and commits it as `Review for <slug>`, then exits 0. When a finding is open, it prints each open finding to stderr, leaves the file uncommitted and exits 1. When the file is clean and already committed, it prints that there is nothing to commit and exits 0. It never pushes: the caller pushes on exit 0. A script, not prose, so "three rounds give one commit" has a behavioural test, and the reviewer, the coordinator and `code-review` share one rule.
2. **"Open finding" has one definition.** Extract `deliver`'s `Review` class into `claude/.claude/skills/review/scripts/review_file.rb`. `deliver` and `commit-review` both `require_relative` it. `auto-accept` keeps its own copy: its critique format differs, and it is out of scope.
3. **Agreement means no open finding.** A finding closes as today: `fixed (<commit subject>)` or `dismissed: <reason>` after its last `→`. A round with findings is open by construction, since the reviewer leaves the slot empty. So the review converges only after a further round that finds nothing new and every earlier finding is closed. This is the existing stop rule; only the commit moves.
4. **Rounds and closures stay uncommitted until convergence.** The reviewer writes its round to the working tree. `code-review` writes closures to the working tree and stages fix paths by name, never `review.md`, never `git commit -a`. `review-report-fresh` already ignores uncommitted paths inside the change folder, and `worktree-sweep` already skips a dirty worktree, so neither changes.
5. **Autonomous order: Codex round first, then Claude round, then `commit-review`.** If the Claude `reviewer` agent ran first and its round was clean, its `commit-review` would commit before the Codex round, and a Codex finding would force a second commit. With the Codex round transcribed first, the reviewer's own `commit-review` sees both rounds. A Codex coordinator transcribes both rounds and runs `commit-review` itself. Running it twice is harmless: the second run has nothing to commit.
6. **The reviewer still runs `deliver --check` after `commit-review`.** With `review.md` uncommitted, `deliver --check` exits 1 on the dirty tree and the open findings, so `Review ready:` stays the right signal. A converged, committed review gives exit 0 and `Review clean:`, as today.
7. **One script commits the stage documents: `plan/scripts/commit-plan`.** It refuses unless `plan.md` says `Status: accepted` and `intent.md` is accepted. It stages `intent.md` and `plan.md` and commits only those two paths. The subject is `docs: intent and plan for <slug>` when `intent.md` has uncommitted changes, else `docs: plan for <slug>` (a branch from the old flow, like this one, or a plan revised after a committed intent). It never pushes. Plan step 7 and Auto mode step 5 call it.
8. **The intent stage no longer commits or pushes.** On "accepted" it flips the status and leaves `intent.md` in the worktree. The plan stage runs in the same `.worktrees/<slug>` (`worktree-create` reuses a worktree already on that branch), so it sees the file. The intent pane record (`intent-pane-<slug>`) is unchanged.
9. **Restore is a script plus a pushed-by-hand step: `deliver/scripts/restore`.** It refuses on a dirty tree and on a detached HEAD or `main`. It refuses unless the branch has an open pull request: `gh pr list --head <branch> --state open --json number`, pinned to origin's repository the way `review-report-fresh` does. A change request only exists on an open PR, and this one check also refuses merged branches, squash-merged ones included (out of scope). A `gh` error refuses too. It fetches the branch and the base (`git fetch origin <branch> <base>`, base resolved as `start-review.sh` does) and fast-forwards to the remote branch (`git merge --ff-only`); a diverged branch is refused. It finds the one commit in `<merge-base>..HEAD` with the subject `Remove change artifacts for <slug>`. It refuses unless there is exactly one, every change in it is a deletion under `docs/changes/<slug>/`, the folder is absent after it, and its parent holds `intent.md`, `plan.md` and `review.md` there. It runs `git rebase --onto <removal>^ <removal>`; on a conflict it runs `git rebase --abort` and refuses. It ends by printing the push command, `git push --force-with-lease -u origin HEAD`. The agent runs that push itself, so the consent guard sees the force push and judges it. The lease is current because the script just fetched.
10. **After a restore, the change request edits the restored documents in place.** No new folder, no new files. Edits to `intent.md` and `plan.md` land through `commit-plan`; new review rounds through `commit-review`. `deliver` runs again and edits the open PR body (it already handles an existing PR). Until then the consent guard refuses `gh pr merge`, because the folder is back.
11. **Playbook rule 5 names the restore path.** One sentence: a change request after `deliver` restores the folder with `deliver`'s `restore` script; never recreate the documents by hand. `core-values.yml` does not mirror rule 5, so it does not change.

## Integration points

- Consent guard (`claude/.claude/hooks/consent-guard.rb`): allows `git push --force-with-lease …`, refuses plain `--force`, refuses `gh pr create`/`merge` while the folder exists. No code change; a new acceptance test pins the restore push.
- Pre-push freshness check (`git/.config/git/worktree-tools/review-report-fresh`): no change. Before a PR it skips; with a PR open it needs the latest `review.md` commit to cover the latest code commit. A converged `commit-review` commit comes after the last fix, so it passes.
- `deliver` script: uses the extracted `Review` class; behaviour unchanged.
- Codex adapter: `codex/.codex/agents/reviewer.toml` is generated from `claude/.claude/agents/reviewer.md` by `bin/generate-codex-agents`; regenerate it.
- Codex skills reach the same files through `agents/.agents/skills` symlinks; no separate edit.
- Stow: the dotfiles link skill files one by one. The three new scripts and `review_file.rb` appear under `~/.claude/skills` only after Etienne restows (`install.sh`). Agents never run `stow` (rule 12).

## Files that change

- `claude/.claude/skills/review/scripts/review_file.rb` — new. The `Review` class moved from `deliver` (rounds?, open_findings).
- `claude/.claude/skills/review/scripts/commit-review` — new, executable. Decision 1.
- `claude/.claude/skills/deliver/scripts/deliver` — require `review_file.rb` instead of defining `Review`.
- `claude/.claude/skills/plan/scripts/commit-plan` — new, executable. Decision 7.
- `claude/.claude/skills/deliver/scripts/restore` — new, executable. Decision 9.
- `claude/.claude/agents/reviewer.md` — steps 6–8 and Rules: write the round uncommitted, ignore the change folder's own `review.md` in the diff, run `commit-review`, push only when it exits 0, then `deliver --check`. Description front matter: "commits it only when the review converges".
- `codex/.codex/agents/reviewer.toml` — regenerated.
- `herdr/.config/herdr/scripts/start-review.sh` — reviewer prompt and header comment: same contract as the agent.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` — intent stage: accept, leave `intent.md` uncommitted, no push. Plan stage (normal and `--auto`): "once the skill has committed `intent.md` and `plan.md`". Header comment.
- `claude/.claude/skills/intent/SKILL.md` — Pane backend paragraph and step 4: no commit, no push; the plan stage commits it. Autonomous delivery step 5: Codex round first, then the Claude round, then `commit-review`; push when it commits.
- `claude/.claude/skills/plan/SKILL.md` — Pane backend paragraph, step 7, Auto mode step 5: run `commit-plan`, then push.
- `claude/.claude/skills/review/SKILL.md` — intro, Pane backend paragraph, `code-review` paragraph, Auto mode (order, transcribe, `commit-review`), Read-only Claude CLI backend (transcribe, `commit-review`).
- `claude/.claude/skills/code-review/SKILL.md` — closures go in the working tree, never in a commit; stage fix paths by name.
- `claude/.claude/skills/deliver/SKILL.md` — new section "Change requests after delivery": run `restore`, push with `git push --force-with-lease -u origin HEAD`, edit the restored documents, review, run `deliver` again. Note that pushes before the new review converges are refused while the PR is open.
- `claude/.claude/skills/implement/SKILL.md` — "Like `intent` and `plan`, the implement pane pushes" becomes "Like `plan`".
- `agents.md` — rule 5: one sentence on `restore` (decision 11).
- `SKILLS-INDEX.md` — only if a line there describes per-round commits; check, else no change.
- Tests: see Proof.

## Order of work

1. Write `test/commit_review_test.rb` `test_three_rounds_to_agreement_add_one_review_commit`. Run it; watch it fail (no script).
2. Extract `Review` into `review_file.rb`; make `deliver` require it. Run `test/deliver_test.rb`; it stays green. Commit.
3. Write `commit-review` until the acceptance test and its unit tests pass. Commit.
4. Write `test/commit_plan_test.rb` `test_intent_and_plan_land_in_one_commit`; watch it fail. Write `commit-plan` and its unit tests. Commit.
5. Write `test/restore_test.rb` `test_a_change_request_gets_the_deleted_documents_back`; watch it fail. Write `restore` and its unit tests. Commit.
6. Add the consent guard acceptance test for the restore push command. It should pass at once against the existing guard; confirm that by also asserting that the plain `--force` variant is refused, so the test exercises the guard. Commit.
7. Write the text tests for the agent and pane contracts (`test/pull_request_flow_test.rb`, `test/herdr_worker_scripts_test.rb`, `test/autonomy_contract_test.rb`); watch the new ones fail.
8. Update `reviewer.md`, regenerate `reviewer.toml`, update `start-review.sh`. Commit.
9. Update `hand-off-plan.sh`, `intent/SKILL.md`, `plan/SKILL.md`, `implement/SKILL.md`. Commit.
10. Update `review/SKILL.md`, `code-review/SKILL.md`, `deliver/SKILL.md`, `agents.md` rule 5. Commit.
11. Run every test file, RuboCop on the Ruby files touched, markdownlint on the Markdown touched, shellcheck on the two shell scripts. Grep the repository, outside `docs/changes/`, for stale wording and fix every hit: "commit that file alone" (any case), "committing each transcribed round alone", "intent.md` alone", "commits it alone", "Review round".

## Risks

- **Uncommitted documents live in one worktree.** `intent.md` between intent and plan, and `review.md` between rounds, exist only on disk. Another machine sees nothing. A deleted worktree loses them. `worktree-sweep` skips dirty worktrees, which covers the automatic path. Accepted by the intent ("stay uncommitted (not pushed)").
- **Fix commits with `review.md` dirty.** A `git commit -a` or `git add .` would sweep the round into a fix commit. Mitigation: `code-review` and the reviewer text say to stage by path; `commit-review` uses a pathspec commit. Not enforced by a hook (rejected: a pre-commit hook on `review.md` would also block `commit-review`).
- **Order in autonomous review.** If a coordinator runs the Claude reviewer before the Codex round, a clean Claude round commits early and a Codex finding forces a second commit. The order is stated in three places (intent step 5, review Auto mode, review Read-only Claude CLI backend) and pinned by a text test.
- **Restore with an open PR.** The pre-push check is strict while a PR is open. The restore push passes when no code commit follows the last `review.md` commit. A commit made after `deliver` outside the folder (a work ADR commit, a CI fix) makes the review stale, and the hook refuses the push. The restored branch then stays local until a new review converges; the documented answer is to run the review and push with `--force-with-lease`. Rejected: `--no-verify` (forbidden), and skipping the check for restores (weakens the check).
- **Rewriting a pushed branch.** Dropping the removal commit changes PR history that reviewers saw. Chosen in the intent. `--force-with-lease` after a fresh fetch stops an overwrite of someone else's push.
- **Old branches.** A branch whose `intent.md` was committed by the old flow gets `docs: plan for <slug>` from `commit-plan`; this branch is one. No migration needed.
- **Stow.** New script files need a restow by Etienne before agents can call them through `~/.claude/skills`. Until then the skills name scripts that are not linked. Delivery reports this; agents do not run `stow`.
- Rejected: committing rounds locally and squashing before push. It needs a history rewrite on every convergence and makes `git commit -a` mistakes harder to see. The intent asks for uncommitted rounds.
- Rejected: a `--rounds` flag or an `--auto` flag on `start-review.sh` to hold the Claude commit back. Ordering the rounds needs no new interface.

## Out of scope

- A cap on review rounds; squash-merge settings; moving change documents out of the branch; restoring documents on a merged branch (`restore` refuses it).
- `auto-accept`'s own finding parser.
- Changing the pre-push freshness rule or the consent guard.
- Running `stow` or `install.sh`.

## Proof

- A review that needs three rounds before agreement adds one `review.md` commit → `test/commit_review_test.rb` `test_three_rounds_to_agreement_add_one_review_commit`
- After a pull, a change request on a delivered branch gives back `intent.md`, `plan.md` and `review.md`, and the history no longer holds the deleting commit → `test/restore_test.rb` `test_a_change_request_gets_the_deleted_documents_back`
- After the restore rebase, the push uses `--force-with-lease` and the consent guard accepts it → `test/restore_test.rb` `test_restore_prints_a_force_with_lease_push` and `test/consent_guard_test.rb` `test_the_restore_push_is_allowed_and_its_plain_force_twin_is_not`
- `intent.md` and `plan.md` for a new change appear in a single commit → `test/commit_plan_test.rb` `test_intent_and_plan_land_in_one_commit`
- An open reviewer round leaves no pushed commit that only touches `review.md` → `test/commit_review_test.rb` `test_an_open_round_leaves_review_md_uncommitted`

Per changed file, the unit tests expected:

- `claude/.claude/skills/review/scripts/review_file.rb` (through `test/commit_review_test.rb` and the existing `test/deliver_test.rb`): `Review#rounds?` is false without a round heading; `Review#open_findings` lists an empty slot, keeps `fixed (<subject>)` and `dismissed: <reason>` closed, and treats `dismissed:` with no reason as open.
- `claude/.claude/skills/review/scripts/commit-review` (`test/commit_review_test.rb`): `test_an_open_round_leaves_review_md_uncommitted` (exit 1, open findings on stderr, no new commit, file still modified); `test_refuses_a_review_md_without_a_round`; `test_commits_only_review_md_when_other_files_are_staged`; `test_a_second_run_has_nothing_to_commit`; `test_the_commit_subject_names_the_slug`; `test_it_never_pushes` (the bare origin is unchanged).
- `claude/.claude/skills/deliver/scripts/deliver` (`test/deliver_test.rb`): existing tests stay green; no new test.
- `claude/.claude/skills/plan/scripts/commit-plan` (`test/commit_plan_test.rb`): `test_refuses_a_draft_plan`; `test_refuses_a_draft_intent`; `test_commits_plan_alone_when_intent_is_already_committed` (subject `docs: plan for <slug>`); `test_leaves_other_changes_uncommitted`; `test_commits_only_intent_and_plan_when_other_files_are_staged` (the unrelated path stays staged and is absent from the commit); `test_it_never_pushes`.
- `claude/.claude/skills/deliver/scripts/restore` (`test/restore_test.rb`): `test_restore_prints_a_force_with_lease_push`; `test_pulls_the_remote_branch_before_rebasing` (a commit only on origin is present after restore); `test_refuses_a_diverged_branch`; `test_refuses_a_dirty_tree`; `test_refuses_a_branch_without_a_removal_commit`; `test_refuses_a_removal_commit_that_touches_other_paths`; `test_refuses_a_removal_commit_that_deletes_only_part_of_the_folder`; `test_refuses_a_branch_without_an_open_pull_request` (covers merged and squash-merged); `test_refuses_when_gh_cannot_tell`; `test_keeps_commits_made_after_delivery`; `test_aborts_a_conflicting_rebase` (the branch is back at its old HEAD).
- `claude/.claude/hooks/consent-guard.rb` (`test/consent_guard_test.rb`): the acceptance test above only; no code change.
- `claude/.claude/agents/reviewer.md`, `herdr/.config/herdr/scripts/start-review.sh` (`test/herdr_worker_scripts_test.rb`, `test/pull_request_flow_test.rb`): `test_the_reviewer_commits_only_through_commit_review`; `test_the_reviewer_pushes_only_after_commit_review_exits_0`; `test_the_reviewer_runs_deliver_check_after_commit_review` (replaces the "commit that file alone" ordering assertion); `test_the_reviewer_agent_pushes_its_round` updated to the new wording.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` (`test/herdr_worker_scripts_test.rb`): `test_the_intent_worker_is_told_not_to_commit_or_push_intent_md` (replaces `assert_told_accepted_then_committed_then_pushed` for intent); `test_the_plan_worker_commits_intent_and_plan_then_pushes` for normal and `--auto`.
- `claude/.claude/skills/intent/SKILL.md`, `plan/SKILL.md`, `review/SKILL.md`, `code-review/SKILL.md`, `deliver/SKILL.md`, `agents.md` (`test/pull_request_flow_test.rb`, `test/autonomy_contract_test.rb`): `test_intent_accept_leaves_intent_md_uncommitted`; `test_plan_commits_through_commit_plan`; `test_auto_review_runs_the_codex_round_before_the_claude_round`; `test_the_coordinator_commits_rounds_through_commit_review` (replaces `test_the_coordinator_pushes_the_codex_round`); `test_code_review_never_commits_review_md`; `test_deliver_documents_restore_with_force_with_lease`; `test_the_playbook_names_restore_in_rule_5`. `test_claude_cli_review_replaces_the_reviewer_write_and_fetch_steps` keeps passing.

Test setup: each script test builds a temporary repository with a bare `origin`, like `test/delivery_harness.rb` (reuse `build_repo`, `commit_file`, `git` from it where they fit; `restore` tests also reuse `deliver` to make the real removal commit). The harness's origin URL is a GitHub URL with only the push URL on the bare repository, so a `restore` test adds `git config url.<bare>.insteadOf <origin url>`: fetch and push then both reach the bare repository while `origin` still reads as personal. It stubs `gh pr list` for the open-PR check. Set `HOME` to a temp directory and disable commit signing. `commit-plan` and `commit-review` run `change-folder` from the repository, so the branch name sets the slug. Only `restore` calls `gh`; `commit-plan` and `commit-review` never do. Text tests read the files as `test/pull_request_flow_test.rb` does.

---
Domain skills applied: object-oriented-design (one owner for the open-finding rule), ruby-style (scripts), dotfiles-maintenance (stow and Codex adapter), rails-testing (Minitest conventions).

## Critique

### Round 1 (codex exec -p terra)

- Restore refused merged branches by ancestry against `origin/main`, which misses squash merges, and fetched only the feature branch, so `origin/main` could be stale → fixed (decision 9 now requires an open pull request through `gh`, fetches the branch and the base, and adds `test_refuses_a_branch_without_an_open_pull_request` and `test_refuses_when_gh_cannot_tell`)
- Restore validation accepted a removal commit that deletes only part of the folder, which would bring back an incomplete folder → fixed (decision 9 requires every change to be a deletion under the folder, the folder absent after it, and `intent.md`, `plan.md` and `review.md` in its parent; added `test_refuses_a_removal_commit_that_deletes_only_part_of_the_folder`)
- The delivery harness fetches from a GitHub URL and pushes to the bare repository, so a restore fetch in a test would reach GitHub → fixed (Test setup adds a `url.<bare>.insteadOf` rule so fetch and push reach the bare repository)
- `commit-plan` had no test that already staged unrelated work stays out of its commit → fixed (added `test_commits_only_intent_and_plan_when_other_files_are_staged`)
