# Plan: Delivery ends with a draft PR; /finish ships it

From `intent.md` (2026-10-09). Status: accepted.

## Design decisions

- Delivery becomes a new `deliver` skill, backed by one Ruby script, `claude/.claude/skills/deliver/scripts/deliver`. The script does steps 1–7 from `intent.md` with no questions, so "without a further command" holds and every step is testable with stubs. The skill text says when to run it and what to tell Etienne.
- `deliver` frontmatter: `disable-model-invocation: true`; `agents/openai.yaml`: `allow_implicit_invocation: false`. Other skills reach it by path (`~/.claude/skills/deliver/SKILL.md`), the same way the intent skill reaches `finish` today. Etienne can still type `/deliver` (Codex: `$deliver`).
- `deliver --check` runs only the step 1 preconditions and exits 0 when delivery may run, 1 with the reasons otherwise. It is the one machine-readable "review closed" signal.
- `start-review.sh` changes its reviewer prompt: after committing its round, the reviewer runs `deliver --check`. Exit 0: it sends `Review clean: <path>` instead of `Review ready: <path>`. The `here` backend runs the same check itself after the forked reviewer returns.
- The trigger lives in the `review` skill's "After either backend" section: outside auto mode, on `Review clean:` (or `deliver --check` exit 0 in the `here` backend), run `deliver` without asking. `Review ready:` keeps today's behaviour: summarise and stop. A clean re-review is always the last action of a fix loop, because `code-review` step 6 re-reviews after every fix or dismissal. `code-review` gets one sentence that points at this and says it never pushes or opens the PR itself.
- In auto mode the coordinator runs `deliver` only after a round of each reviewer is clean (intent skill, Autonomous delivery step 6). Then it follows `finish` in its auto mode, which runs `finish/scripts/ship --no-merge`. The personal-scope and `Delivery: autonomous` checks stay in that one section. The coordinator checks `Delivery: autonomous` before `deliver`, because `deliver` removes `intent.md`.
- `fill-pr-template` and `change-scope` stay in `claude/.claude/skills/finish/scripts/`. Moving them changes paths in the intent skill and two tests for no gain. `deliver` calls them there.
- A finding is a line under `review.md` of the form `- [ ] Important: …` or `- [ ] Nit: …`. It is closed only when the text after its last `→` is `fixed (<commit subject>)` or `dismissed: <reason>` with a reason that is not empty. Any other text, or none, leaves it open. `auto-accept` applies the same rule to plan critiques. The script parses this instead of an agent reading it. No `review.md`, or a `review.md` with no round, also refuses.
- PR lookup uses `gh pr list --head <branch> --state open --json number,url,isDraft`. An empty list is the only "no PR" answer. Any non-zero exit stops `deliver` and `ship` with gh's stderr, and never leads to `gh pr create`.
- The PR body and title are written to `<git-common-dir>/deliver/<slug>.body.md` and `<slug>.title`, not to a `mktemp` file. A delivery that fails after the folder removal (for example a push failure) can then resume: when the folder is gone from `HEAD`, the last commit subject is `Remove change artifacts for <slug>`, and both files exist, `deliver` skips steps 1–4. The files are deleted once the PR exists.
- Delivery closes this change's idle or done stage panes without asking (today `/finish` asks). `hand-off-plan.sh` and `start-review.sh` append `<pane_id> <terminal_id>` for each stage pane they open to `<git-common-dir>/herdr/stage-panes-<slug>`. `deliver` closes a pane only when that list holds it, its terminal id still matches, and its `agent_status` is `idle` or `done`. Pane ids are reused, so the terminal id guards against a later pane with the same id. It never closes its own `$HERDR_PANE_ID` or the recorded intent pane. Then it deletes the list. Pane closing is best effort: the PR exists by then, so a herdr failure only warns. An empty `HERDR_WORKSPACE_ID` drops the `--workspace` flag from `pane list`.
- The intent pane is recorded, not guessed. On "accepted", inside herdr, the intent skill writes its own pane id and terminal id (`herdr pane current`, fields `pane_id` and `terminal_id`) to `<git-common-dir>/herdr/intent-pane-<slug>`, one per line. Terminal ids are unique per terminal, so they tell a live pane A apart from a recycled id. When a stage pane wrote the intent and then closed itself, the fallback applies, which matches the acceptance criterion literally.
- herdr 0.9.3 `pane split` only takes `right` or `down`. "Directly left of pane A" is done as: `herdr pane split <A> --direction right --cwd <toplevel> --no-focus`, then `herdr pane swap --source-pane <new> --target-pane <A>`. A is checked first with `herdr pane get <A>`; a failure, or a `terminal_id` that differs from the recorded one, means A is gone, and the anchor becomes `$HERDR_PANE_ID`.
- gh-dash gets a per-change config file, `<git-common-dir>/deliver/<slug>.gh-dash.yml`, with `defaults.view: prs` and one `prSections` entry (`title: <slug>`, `filters: repo:<owner>/<repo> head:<branch>`), and runs as `gh dash --config <file>` through `herdr pane run`. `head:` is GitHub search syntax and needs no PR number. Owner and repo come from `gh repo view --json nameWithOwner`. Confirmed keys: the installed gh-dash v4.26.0 binary carries `prSections`, `defaults` and `view`; the gh-dash docs (gh-dash.dev, configuration: PR section, defaults) define `prSections[].title`, `prSections[].filters` in GitHub search syntax with `is:pr` added automatically, and `defaults.view` as `notifications`, `prs` or `issues`.
- The pane step is its own script, `herdr/.config/herdr/scripts/open-pr-dash.sh <slug> <pr-url>`, next to `hand-off-plan.sh` and `start-review.sh`. `deliver` calls it from `${HERDR_SCRIPTS_DIR:-$HOME/.config/herdr/scripts}`. Outside herdr (`HERDR_ENV` not `1`) it prints the PR URL, says no pane opened, makes no `herdr` call, and exits 0.
- `/finish` personal and the auto-mode ship step share one script, `claude/.claude/skills/finish/scripts/ship [--no-merge]`:
  1. Look the PR up as above. Empty list: exit 1, "No pull request for this branch: the delivery step has not run."
  2. Draft: `gh pr ready <number>`.
  3. Wait for checks: `gh pr checks <number> --watch --fail-fast`. "No checks reported" is retried every 10 s for at most `SHIP_CHECKS_GRACE` seconds (default 120). Still none: stop unmerged, "no CI checks reported; merge by hand if that is expected." A watch that fails for another reason (auth, network) does not count as green; step 4 decides, and keeps gh's reason.
  4. Then read `gh pr checks <number> --json name,bucket,link`. Only `pass` and `skipping` count as green. Any other check stops `ship` unmerged with exit 1. A `fail` or `cancel` check comes first: "CI failed; PR left unmerged.", then `<name>: <link>` per failed check, then the still-pending checks under their own note. `--fail-fast` stops at the first failure, so sibling checks are often still pending. With no failed check, `ship` says CI has not finished, adds gh's reason when the watch failed, and names the pending checks. A checks list that cannot be read also stops unmerged, with gh's reason.
  5. `--no-merge`: print "CI green; PR left unmerged." and exit 0.
  6. `gh pr merge <number> --merge` (no `--delete-branch`: it checks out the base branch locally, which fails in a worktree). Then poll `gh pr view <number> --json state,autoMergeRequest` every 10 s until it reads `MERGED`, for at most `SHIP_MERGE_WAIT` seconds (default 900). This also covers a repository with a merge queue, where `gh pr merge` only queues the PR. A merge command that exits non-zero stops `ship` at once with gh's stderr, unless the PR already reads `MERGED` or has auto-merge set. Not merged in time: stop, report the state, and keep the remote branch. Merged: `git push origin --delete <branch>`; a remote branch already gone is not an error.
- `/finish` work: the skill looks the PR up first, the same way, and refuses with the same "delivery step has not run" text. The ADR question stays, but the ADR is distilled from `gh pr view --json title,body`, since the folder is gone. The ADR commit is pushed. Then `after-push` runs, then reviewers, as today.
- `dotfiles-work` `after-push` gains the board step. It reads a private file `~/.claude/finish/review-board`: line 1 the project owner, line 2 the project number. It then runs `gh project item-add <number> --owner <owner> --url <pr-url> --format json` for the item id, reads the project id and the `Status` field's option ids with `gh project view` and `gh project field-list`, and sets "Needs Review" with `gh project item-edit`. Before any mutation, `after-push` checks `gh auth status` for the `project` scope. Missing: exit non-zero with "run gh auth refresh -s project", before `gh pr ready`, so nothing changes half-way. The board step runs after `gh pr ready` and before Edge opens. Any `gh project` failure exits non-zero, so `/finish` stops before reviewers. A missing or empty `review-board` file also stops the script before any mutation, with a setup message, so a required status change is never skipped silently.
- `/finish` keeps `--dry-run`: it prints the ship steps for the scope and stops.
- Installation: `~/.claude/skills/<name>/` holds per-file stow links, so the new `deliver` folder, `deliver`, `ship` and `open-pr-dash.sh` reach `~` only after a restow of the `claude`, `agents` and `herdr` packages. Playbook rule 12 forbids agents to run stow, so the PR body names that step for Etienne after merge. Until then the installed skills keep the old flow, and this change itself is delivered through the old `finish` auto mode.
- Branches with change work from before this ships: `ship` and the work path refuse them, since they have no PR. No migration path.

## Integration points

- `herdr` CLI 0.9.3: `pane list --workspace`, `pane get`, `pane split`, `pane swap`, `pane run`, `pane rename`, `pane close`.
- `gh` CLI: `pr view`, `pr create --draft`, `pr edit --body-file`, `pr ready`, `pr checks --watch --fail-fast --json`, `pr merge --merge`, `repo view`, and in `dotfiles-work` `project item-add|view|field-list|item-edit`.
- `gh dash` (installed as a `gh` extension) with `--config`.
- `~/.config/git/worktree-tools/review-report-fresh` (called by `deliver`; only its header comment changes).
- lefthook pre-push freshness check: passes once the folder is gone from `HEAD`.
- Consent guard (`claude/.claude/hooks/consent-guard.rb`): `gh pr create|ready|merge|edit` and `git push origin --delete` on an `eirvandelden` remote are not blocked. Only its refusal messages change: they name `deliver` instead of `/finish`.
- `dotfiles-work` repository: its own worktree, branch `implement-done-opens-draft-pr`, and PR. Its `claude` stow package supplies `~/.claude/finish/after-push` and the new `review-board`.

## Files that change

`dotfiles`:

- `claude/.claude/skills/deliver/SKILL.md` — new. When delivery runs, what the script does, what to report, auto-mode notes, Codex section.
- `claude/.claude/skills/deliver/agents/openai.yaml` — new. `allow_implicit_invocation: false`.
- `claude/.claude/skills/deliver/scripts/deliver` — new Ruby script, steps 1–7, resumable.
- `agents/.agents/skills/deliver` — new symlink to `../../../claude/.claude/skills/deliver`.
- `herdr/.config/herdr/scripts/open-pr-dash.sh` — new bash script for the gh-dash pane.
- `claude/.claude/skills/finish/scripts/ship` — new Ruby script for ready, CI wait, merge.
- `claude/.claude/skills/finish/SKILL.md` — rewrite as the ship step: preconditions (PR exists), personal via `ship`, work via ADR from PR body then `after-push` then reviewers, auto mode via `ship --no-merge`, contract §7 updated (board status now in `after-push`, `review-board` file). Remove the old §3 PR body, §4 folder removal and panes, §5 push.
- `claude/.claude/skills/finish/agents/openai.yaml` — existing file; its `short_description` becomes the ship step.
- `claude/.claude/skills/review/SKILL.md` — frontmatter `description`: the reviewer stays report-only, and a clean review hands over to delivery. "After either backend": `Review clean:` runs `deliver`. Auto mode: the coordinator delivers, not this skill.
- `claude/.claude/skills/review/agents/openai.yaml` — `short_description` matches the new frontmatter.
- `herdr/.config/herdr/scripts/start-review.sh` — reviewer prompt runs `deliver --check` and sends `Review clean:` or `Review ready:`. It records the review pane as `<pane_id> <terminal_id>` in `<git-common-dir>/herdr/stage-panes-<slug>`. It finds the skills through `CLAUDE_SKILLS_DIR` (default `~/.claude/skills`), so tests can point it at this repository.
- `claude/.claude/agents/reviewer.md` — Output: also report the `deliver --check` result, so the `here` backend gets the same signal. Rules: `Bash` may also run `deliver --check`, which changes nothing.
- `codex/.codex/agents/reviewer.toml` — regenerated from `reviewer.md`.
- `claude/.claude/skills/code-review/SKILL.md` — one sentence: a clean re-review hands over to delivery; never push or open the PR here.
- `claude/.claude/skills/implement/SKILL.md` — "leaves the push to `/review` and `/finish`" becomes "to `/review` and the delivery step".
- `claude/.claude/skills/intent/SKILL.md` — §4 Accept: record the intent pane id inside herdr. Autonomous delivery step 6: confirm `Delivery: autonomous`, run `deliver`, then follow `finish` in its auto mode, which runs `ship --no-merge`; step 7 account includes the CI result.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` — implement `acceptance_instruction`: "the review pane and the delivery step" instead of "/finish". Each stage pane it opens is appended as `<pane_id> <terminal_id>` to `<git-common-dir>/herdr/stage-panes-<slug>`.
- `claude/.claude/skills/finish/scripts/fill-pr-template` — header comment: `deliver` opens the PR.
- `git/.config/git/worktree-tools/review-report-fresh` — header comment: `deliver` runs it before it opens the PR.
- `claude/.claude/hooks/consent-guard.rb`, `lefthook.yml`, `claude/.claude/skills/worktree-first/SKILL.md` — messages and text name `deliver` as the step that opens the PR.
- `agents.md` — rule 5 last bullet: the delivery step removes `docs/changes/<slug>/`. §7a: the coordinator opens a draft PR, marks it ready and waits for green CI; Etienne's `/finish` is the merge approval.
- `claude/.claude/core-values.yml` — consent line: "In autonomous delivery, agents never merge a pull request; Etienne's /finish is the merge approval."
- `SKILLS-INDEX.md` — new `deliver` line; `finish` line rewritten as the ship step; `review` line says a clean review hands over to delivery.
- `test/herdr_worker_scripts_test.rb` — new tests for the reviewer prompt (below).
- `test/deliver_test.rb`, `test/open_pr_dash_test.rb`, `test/ship_test.rb`, `test/delivery_contract_test.rb`, `test/delivery_harness.rb` (shared stubs) — new.
- `test/consent_guard_test.rb`, `test/pull_request_flow_test.rb` — renamed from `finish` to `deliver` with equal strength.
- `test/autonomy_contract_test.rb` — `test_finish_auto_mode_is_personal_only` keeps passing; no edit expected. Edit only if the rewritten section moves its words, never to weaken it.

`dotfiles-work`:

- `claude/.claude/finish/after-push` — board status step.
- `test/finish_after_push_test.rb` — new tests; the `gh` stub learns `project` subcommands.
- `claude/.claude/finish/review-board` — new. Its two values are in the private, untracked file `<git-common-dir>/herdr/decisions-implement-done-opens-draft-pr.md`. Never copy them into this repository.

## Order of work

1. Write `test/deliver_test.rb` `test_a_closed_review_ends_in_a_draft_pr_without_the_change_folder`, run it, watch it fail (no script).
2. `deliver` preconditions: unit tests for refusals (open finding, stale review, dirty tree, unknown scope, no `review.md`), then code.
3. `deliver` body and title capture, folder removal commit, push, PR create or edit. Acceptance test from step 1 goes green.
4. `deliver` pane closing (herdr stub), then resume after a failed push.
5. `test/open_pr_dash_test.rb`: left-of-intent-pane, fallback, outside herdr. Then `open-pr-dash.sh`. Wire `deliver` to it; `test_outside_herdr_prints_the_pr_url_and_opens_no_pane` in `deliver_test.rb`.
6. `test/ship_test.rb`: no PR, green merge, red check, no-merge, no checks after grace, merge reported as failed but state `MERGED`. Then `ship`.
7. `test/delivery_contract_test.rb` for the skill text, then the skill and playbook edits: `deliver` skill, symlink, `openai.yaml` files, `finish`, `review`, `code-review`, `implement`, `intent`, `hand-off-plan.sh`, `agents.md`, `core-values.yml`, `SKILLS-INDEX.md`.
8. Full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. RuboCop on the new Ruby scripts and tests, shellcheck on `open-pr-dash.sh`, markdownlint on changed Markdown.
9. Work-name check (Proof below) on the full branch diff.
10. `dotfiles-work`: new worktree and branch, failing `after-push` tests, then the board step. Its own suite and linters. Its own PR.

## Risks

- gh-dash config keys (`prSections`, `filters`, `defaults.view`) are from memory. Verify them against `gh dash` docs or a real run before relying on them (rule 22).
- `herdr pane swap --source-pane/--target-pane` semantics are read from `--help`, not tried. Verify in a live herdr session that the new pane ends up directly left of A and A keeps its size class.
- Pane ids are recycled across herdr sessions. The recorded terminal id guards against anchoring beside an unrelated pane; verify in a live session that `terminal_id` survives a herdr client reattach but changes for a new terminal.
- `gh pr checks --watch` right after `gh pr ready` can see no checks yet. The grace loop covers that; a repo without CI stops unmerged instead of merging blind. Rejected: merging when no checks appear, because a slow CI start looks the same. Etienne confirmed stopping unmerged on 2026-10-13.
- `gh pr merge` inside a worktree can report failure after the merge landed. `ship` reads the PR state instead of trusting the exit code.
- Settled 2026-10-13: the stored `gh` token now has the `project` scope. A shell with `GH_TOKEN` set uses that token instead; `after-push` still preflights the scope and stops before any change when it is missing.
- Settled 2026-10-13: Etienne gave the board's owner and project number. They live only in the private decisions file named above, and the board was checked to have a "Needs Review" status option.
- The public repo must never name the work org, board or project. Plan, scripts and tests use "team review board" and the private `review-board` file only. The Proof check greps the diff.
- Rejected: putting delivery inside the `review` skill text only. A script makes "no further command" deterministic and testable; skill text alone is not.
- Rejected: moving `fill-pr-template` and `change-scope` to `deliver/scripts`. Path churn for no behaviour.
- Rejected: asking before closing stage panes. Delivery must run without a further command.

Out of scope: deployment, fixing red CI inside `/finish`, local worktree clean-up after merge, migrating branches from before this ships, any change to intent, plan or implement before the last review round.

## Proof

- The last review round leaves no open finding; without a further command the folder is gone in its own commit, the branch is on `origin`, and a draft PR with the filled body exists → `test/deliver_test.rb` `test_a_closed_review_ends_in_a_draft_pr_without_the_change_folder`, and `test/delivery_contract_test.rb` `test_review_runs_delivery_when_no_finding_is_open`
- A new pane sits directly left of the intent pane A, running gh-dash that shows only the new PR → `test/open_pr_dash_test.rb` `test_opens_gh_dash_directly_left_of_the_intent_pane`, and `test/delivery_contract_test.rb` `test_intent_records_its_pane_on_accept`
- Pane A was closed; the gh-dash pane opens directly left of the delivering agent's pane → `test/open_pr_dash_test.rb` `test_falls_back_to_the_own_pane_when_the_intent_pane_is_gone`
- Live check of the same criterion → check: inside herdr, run `open-pr-dash.sh` against a real draft PR of this branch; the new pane is directly left of the anchor and gh-dash lists only that PR. Paste `herdr pane layout` output and a description of the gh-dash screen.
- Delivery outside herdr opens the draft PR, prints its URL, and opens no pane → `test/deliver_test.rb` `test_outside_herdr_prints_the_pr_url_and_opens_no_pane`
- Autonomous delivery: draft PR, marked ready, green CI, account written, PR unmerged → `test/ship_test.rb` `test_no_merge_marks_ready_waits_for_green_and_leaves_the_pr_open`, and `test/delivery_contract_test.rb` `test_the_coordinator_delivers_then_ships_without_merging`
- `/finish` on a personal repo with a draft PR: ready, green CI, merge commit, remote branch deleted → `test/ship_test.rb` `test_ships_a_green_pr_with_a_merge_commit_and_deletes_the_remote_branch`
- `/finish` on a personal repo with a failed check: unmerged, names the check and its link → `test/ship_test.rb` `test_a_failed_check_stops_unmerged_and_names_the_check_and_link`
- `/finish` on a work repo with a draft PR: ready, board "Needs Review", reviewers requested, PR opens in Edge's work profile → `dotfiles-work` `test/finish_after_push_test.rb` `test_sets_the_board_status_to_needs_review` (with the existing ready and Edge tests), and `test/delivery_contract_test.rb` `test_work_finish_runs_after_push_then_requests_reviewers`
- `/finish` on a branch with no PR stops and says the delivery step has not run → `test/ship_test.rb` `test_refuses_a_branch_without_a_pr`, and `test/delivery_contract_test.rb` `test_work_finish_refuses_without_a_pr`
- The public diff names no work org, board or project → check: `! git diff origin/main...HEAD | grep -i -F -f <(grep -v -e '^#' -e '^$' ~/.claude/consent-guard-allowed-remotes.txt | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#'; sed -n 1p ~/.claude/finish/review-board; gh project view "$(sed -n 2p ~/.claude/finish/review-board)" --owner "$(sed -n 1p ~/.claude/finish/review-board)" --format json -q .title)` exits 0. The word list is built at run time from private files and the live board title, so no protected word enters the public repo
- Codex `$finish` and the Codex coordinator behave the same → `test/skill_parity_test.rb` (existing, now covers `deliver`), and `test/delivery_contract_test.rb` `test_deliver_and_finish_name_their_codex_invocation`

Per changed file, the unit tests expected:

- `claude/.claude/skills/deliver/scripts/deliver`: `refuses an open finding and lists it`, `a finding without a valid close marker is open`, `refuses a stale review`, `refuses a missing review.md`, `refuses a dirty tree`, `refuses an unknown scope`, `check mode changes nothing and exits by readiness`, `stops when the PR lookup fails instead of creating a PR`, `fills the body from the repository template`, `fills the body with no template`, `titles the PR from intent.md`, `removes the folder in a commit of its own`, `removes an emptied docs/changes`, `edits the body of an existing PR instead of creating one`, `closes the idle and done stage panes this change opened`, `leaves an unrelated idle agent in the worktree open`, `never closes the intent pane`, `leaves a recorded pane id that another terminal reuses`, `a failed pane list after the PR exists only warns`, `never closes its own pane or a working or agentless pane`, `resumes after a failed push without the folder`, `deletes the saved body once the PR exists`.
- `herdr/.config/herdr/scripts/open-pr-dash.sh`: `writes a config that filters on the branch`, `splits right then swaps to the left`, `runs gh dash with that config in the new pane`, `falls back when no intent pane was recorded`, `falls back when the recorded terminal id no longer matches`.
- `claude/.claude/skills/finish/scripts/ship`: `marks a draft ready`, `leaves a ready PR alone`, `retries while no checks are reported`, `stops unmerged when no checks appear in the grace period`, `trusts the merged state over the merge exit code`, `waits for a queued merge before deleting the branch`, `keeps the branch when the merge does not land in time`, `stops when the PR lookup fails`, `ignores a remote branch already deleted`, `a failed watch with pending checks stops unmerged`, `a refused merge stops at once with the reason from gh`, `a failed check beside a pending one reports the failure first`.
- `herdr/.config/herdr/scripts/start-review.sh` (in `test/herdr_worker_scripts_test.rb`): `the reviewer runs deliver --check after its round`, `a clean check reports Review clean`.
- `test/delivery_contract_test.rb` (skill text): `review on Review clean runs deliver`, `review on Review ready only summarises`, `review descriptions no longer promise report-only for the whole skill`, `finish no longer removes the change folder`, `finish personal runs ship`, `finish auto mode runs ship --no-merge`, `implement leaves the push to the delivery step`, `playbook rule 5 names the delivery step`, `core values name /finish as the merge approval`.
- `dotfiles-work` `after-push`: `stops before marking ready when the project scope is missing`, `sets the board status after marking ready and before opening Edge`, `stops non-zero when the board step fails`, `stops before marking ready without a review-board file`.

Test setup: temporary git repositories with a bare repository as `origin`, built per test like `test/change_scope_test.rb` and `test/herdr_worker_scripts_test.rb` do. Stub `gh`, `herdr` and `gh dash` on `PATH`; each stub records its arguments to a log and returns canned JSON. `HOME` points at a temporary directory so `change-scope` and the review-freshness tool read no real config. `WORKTREE_TOOLS_DIR` points at this repository's `git/.config/git/worktree-tools`, as `hand-off-plan.sh` already allows. `SHIP_CHECKS_GRACE=0`, `SHIP_MERGE_WAIT=0` and a 0 s interval keep `ship` tests fast. No network.

---
Domain skills applied: dotfiles-maintenance, object-oriented-design (one script per responsibility, no service layer), ruby-style.

## Departures during implementation

- `deliver` opens the gh-dash pane before it closes stage panes. The gh-dash pane is part of the outcome; pane closing is clean-up, so it runs last. The intent pane is never closed, so the order does not change the anchor.
- `deliver` looks up the PR before it removes the change folder.
- `deliver` pushes with a plain `git push -u origin <branch>`.
- The `finish` frontmatter says "private work hook" instead of naming `after-push`.
- Stage panes are recorded, not selected by `cwd`. `hand-off-plan.sh` and `start-review.sh` write `stage-panes-<slug>`, and `deliver` closes only listed panes with a matching terminal id. A `cwd` match also closed an unrelated agent in the same worktree (review round 2).
- `deliver` never closes the recorded intent pane. Otherwise the gh-dash anchor that acceptance criterion 2 names was gone after delivery (review round 1).
- Pane closing is best effort. A failed `herdr pane list` after the PR exists only warns, and an empty `HERDR_WORKSPACE_ID` drops `--workspace` (review round 1).
- `ship` counts only `pass` and `skipping` as green. A failed watch with pending or unreadable checks stops unmerged with gh's reason. Before, a network failure during the watch let `ship` merge with pending checks (review round 1).
- `ship` stops at once when gh refuses a merge and no auto-merge is set, with gh's reason. Before, it waited the full `SHIP_MERGE_WAIT` and dropped the reason (review round 1).
- `ship` reports a failed check before still-pending ones. `--fail-fast` exits while sibling checks run, so red CI read as unfinished CI (review round 3).
- The coordinator follows `finish` in its auto mode after `deliver`, instead of running `ship --no-merge` itself. That keeps the auto-mode checks in one place (review round 1).
- `reviewer.md` lets `Bash` run `deliver --check`, since its Output asks for that result (review round 1).
- `start-review.sh` reads `CLAUDE_SKILLS_DIR` to find `change-folder`, so its tests run against this repository.
- `deliver --check` closes a finding only on `fixed (<commit subject>)` or `dismissed: <reason>`. Before, any text after `→` closed it, so `→ still investigating` let delivery run (review round 4).

## Critique

### Round 1 (codex exec -p terra)

- A caller-side instruction does not reliably start delivery after a pane review; the reviewer only sends `Review ready` and closes → fixed (added `deliver --check`; `start-review.sh` and the `here` backend send or derive `Review clean:`; the review skill delivers on that signal; tests in `herdr_worker_scripts_test.rb` and `delivery_contract_test.rb`)
- A failed `gh pr view` lookup is treated as no PR and could lead to `gh pr create` → fixed (lookup through `gh pr list --head`; only an empty list means no PR; any error stops; unit tests in `deliver` and `ship`)
- A merge queue makes `gh pr merge` queue the PR, so an immediate `MERGED` check fails → fixed (`ship` polls for `MERGED` up to `SHIP_MERGE_WAIT`, keeps the branch when it does not land; unit tests added)
- gh-dash YAML keys and filter grammar are unverified and stubs cannot prove them → fixed (binary confirms `prSections`, `defaults` and `view`; `filters` and grammar must be confirmed before the script; added a live check line to Proof)
- The confidentiality check misses display labels and `grep` exits non-zero on no match → fixed (check negated with `!`; word list adds the live board title from private files at run time)
- Board status needs a write scope the token lacks; behaviour without it is undefined → fixed (`after-push` preflights the `project` scope and stops before any mutation; unit test added; the scope refresh is reported as Etienne's prerequisite)
- The inventory omits review metadata and the skills index, and calls an existing `openai.yaml` new → fixed (listed review frontmatter, review `openai.yaml`, `reviewer.md`, `start-review.sh`, `SKILLS-INDEX.md`; finish `openai.yaml` marked existing)

### Round 2 (codex exec -p terra)

- New scripts and the new skill folder reach `~` only through stow, so installed sessions cannot use them → fixed (added an Installation design decision: Etienne restows `claude`, `agents` and `herdr` after merge, named in the PR body; this change ships through the old flow)
- A missing private board config continues and skips the required status change → fixed (`after-push` stops before any mutation without the `review-board` file; unit test renamed to match)
- gh-dash filter key and grammar remain unverified → fixed (confirmed `prSections[].title`, `prSections[].filters` and `defaults.view` from the gh-dash docs and the installed binary; `is:pr` dropped from the filter since gh-dash adds it)
- A recycled pane id can anchor beside an unrelated pane → fixed (record and compare the terminal id as well; unit test added for a mismatched terminal id)
