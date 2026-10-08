# Plan: Only /finish creates pull requests

From `intent.md` (2026-10-08). Status: accepted.

## Design decisions

- The consent guard (`claude/.claude/hooks/consent-guard.rb`) gets two new refusals. Both are "never allowed": the `I_HAVE_USER_CONSENT=1` marker does not unlock them. Etienne can still run either command in his own terminal; the guard governs agents only.
- `gh pr create` is refused when a change folder exists in the working tree of a command directory. The command directories are the hook's `cwd` plus every `cd <path>` target in the command. A `cd` target loses a glued shell operator first (`cd .worktrees/x; gh pr create` gives `.worktrees/x`), with the guard's existing `SHELL_OPERATOR` split. So `cd .worktrees/<slug> && gh pr create` from the main checkout is caught.
- The PR checks also read inside a nested shell: the argument after `-c` of `sh`, `bash` or `zsh` is split into words again and added to the words the PR checks read. The other guard checks keep their current words, so their behaviour does not change. `eval`, script files and aliases stay invisible: the guard reads words, not shell (its header says so), and no skill asks for those forms.
- The guard finds the change folder by running `claude/.claude/skills/plan/scripts/change-folder` in a command directory, through a path relative to `__dir__` (Ruby resolves the stow symlink, so Claude and Codex both reach the dotfiles copy). It runs `git ls-files` for that folder from `git rev-parse --show-toplevel`: tracked files count, so an untracked leftover does not. The folder counts when it is in the index or in `HEAD`, so a staged removal still refuses. With `--head <branch>`, it also reads that branch's own `docs/changes/<slug>` tree, locally or on `origin/<branch>`. A non-zero exit or a missing directory (main, detached HEAD, no commits, not a repository) means "no folder", so the command runs.
- A command counts as `gh pr create` when a `gh` word (bare, or glued to a path or a shell operator: the rule the guard already uses for `git`) is followed by the words `pr` and `create`. Quoted prose stays one word and does not match. Unquoted prose such as `echo gh pr create` does match and is refused while a change folder exists; that false refusal costs a rephrase.
- `gh pr merge` is refused when the PR's head commit has its own `docs/changes/<slug>` tree, where `<slug>` comes from the PR's `headRefName`. Etienne chose the own folder over any `docs/changes/` entry, so a leftover folder of another slug never blocks a merge that `/finish` cannot clear. The guard reads that commit's tree, not the PR diff, and no file-count limit applies. Two `gh` calls in the last command directory (the last `cd` target, else `cwd`), where `gh` runs in a `cd <dir> && gh pr merge` command: `gh pr view <selector> [--repo <repo>] --json headRefOid,headRefName,headRepository,headRepositoryOwner --jq '[.headRepositoryOwner.login, .headRepository.name, .headRefOid, .headRefName] | @tsv'`, then `gh api graphql` with `repository(owner, name) { object(expression: "<oid>:docs/changes/<slug>") { __typename } }` and `--jq '.data.repository.object.__typename // "absent"'`. `Tree` refuses. Checked with gh 2.102.0: PR #186 (folder present) prints `Tree`, PR #185 (folder removed) prints `absent`, both with exit 0.
- The merge selector is the first positional word after `merge`. The value flags of `gh pr merge` (`-A`, `--author-email`, `-b`, `--body`, `-F`, `--body-file`, `-t`, `--subject`, `--match-head-commit`, `-R`, `--repo`) and their values are skipped. `-R`/`--repo`/`--repo=` is passed on to `gh pr view`.
- "Where it can tell" for merge: a non-zero exit from either `gh` call (no network, no PR, not authenticated) lets the merge through. The merge itself fails in most of those cases anyway.
- The open-PR lookup pins `--repo` to the `origin` remote's GitHub path, so an `upstream` remote cannot make `gh` ask the wrong repository.
- The pre-push skip is opt-in: `review-report-fresh` gets a `--skip-without-pr` flag, and only `lefthook.yml`'s `pre-push` command passes it. Without the flag the script stays strict. This keeps the `finish` precondition (§1 step 2, which runs the script with the folder present and no PR yet) strict; a skip by default would make that gate pass every time.
- With `--skip-without-pr`, the script exits 0 when the change folder is in `HEAD` and `gh pr list --head <branch> --state open --json number --jq length` prints `0`. Any other result (an open PR, or a `gh` failure) applies the strict check. On a `gh` failure the script prints one line that says it could not tell, then applies the strict check. `gh` runs only after the folder check, so a branch without a change folder never reaches the network.
- The fourth acceptance criterion ("no `docs/changes/` and a stale review is refused, as today") does not match today's behaviour. Today `review-report-fresh` exits 0 when the change folder is not in `HEAD` (`test_a_branch_with_no_change_folder_passes`). `finish`'s final push relies on that, and the intent puts that push's freshness rule out of scope. Without the folder there is also no `review.md` to call stale. This plan reads the criterion as "the strict check still applies wherever it applies today": a change folder with an open PR, a change folder when `gh` cannot tell, and `finish`'s own run without the flag. A branch without a change folder keeps passing. Etienne confirmed this reading, and `intent.md` now states the criterion that way.
- The old stowed `review-report-fresh` ignores its arguments. A `lefthook.yml` that passes the new flag to an old script therefore stays strict instead of failing.
- `implement` pushes at its end with `git push -u origin HEAD`, in skill text and in the `hand-off-plan.sh` prompt (both the normal and the `--auto` prompt). The new pre-push skip makes that work-in-progress push succeed. A refused push goes into the report; the worker never uses `--no-verify`.
- `review` pushes after each committed round. The `reviewer` agent definition (the single source for both backends) adds the push as its last step and allows `git push -u origin HEAD` under its Bash rules. `start-review.sh` tells the pane reviewer to push. The coordinator pushes after it commits a transcribed Codex round (`review` skill auto mode, `intent` skill "Autonomous delivery" step 5).
- `codex/.codex/rules/default.rules` keeps its `allow` rule for `gh pr create`, and `test/guard_parity_test.rb`'s `GUARDED_COMMANDS` stays unchanged. That list holds commands that always need consent. The new refusals depend on repository state, and `finish` must still run `gh pr create` in Codex. Codex runs the same `consent-guard.rb` from its `[hooks]` table, so the hook covers Codex.
- Text that tells an agent to open a PR other than through `finish` is rewritten: playbook rules 5, 16 and 25 and §7a in `agents.md`; `worktree-first`'s list of commands that run in the worktree; the two `no-push-to-main` messages in `lefthook.yml` ("Create a feature branch and open a PR."). `core-values.yml` stays unchanged: its rule-5 mirror ("never open a PR against upstream") is still true.

## Integration points

- Claude Code `PreToolUse` hook (`claude/.claude/settings.json`, timeout 10 s) and the Codex `[hooks.PreToolUse]` table (`codex/.codex/config.toml`, timeout 10 s) both run `consent-guard.rb`. The merge check adds two `gh` network calls, only for `gh pr merge`.
- The global git `pre-push` hook (`git/.config/git/hooks/pre-push`) runs lefthook with this repository's `lefthook.yml` in every repository without its own lefthook config. Its `review-report-fresh` command calls the stowed `~/.config/git/worktree-tools/review-report-fresh`.
- `finish` §1 step 2 calls `review-report-fresh` without the flag.
- GitHub through the `gh` CLI (2.102.0 on this machine): `gh pr list --head`, `gh pr view --json headRefOid,headRepository,headRepositoryOwner`, `gh api graphql`.
- herdr: `hand-off-plan.sh` and `start-review.sh` prompts.
- Codex agent adapter: `bin/generate-codex-agents` compiles `claude/.claude/agents/reviewer.md` into `codex/.codex/agents/reviewer.toml`; `test/codex_agent_generation_test.rb` fails when the two drift.
- Stow: every changed file already exists and is linked file by file, so no restow is needed after the merge. The new test files are not stowed.

## Files that change

- `claude/.claude/hooks/consent-guard.rb` — the `gh pr create` and `gh pr merge` refusals, the command directories, the nested-shell words; the header comment names them.
- `test/consent_guard_test.rb` — tests for both refusals; a stub `gh` on `PATH`.
- `git/.config/git/worktree-tools/review-report-fresh` — the `--skip-without-pr` flag and the open-PR lookup; the header comment names them.
- `test/review_report_check_test.rb` — tests for the flag with a stub `gh`; a test that `lefthook.yml` passes the flag.
- `test/review_push_hook_test.rb` (new) — a real `git push` to a bare origin through the global `pre-push` hook and lefthook, modelled on `test/lefthook_global_hooks_sync_test.rb`; skips when no lefthook binary is found, as that test does.
- `lefthook.yml` — `pre-push` `review-report-fresh` runs `~/.config/git/worktree-tools/review-report-fresh --skip-without-pr`; its `fail_text` says the check applies once a PR is open; both `no-push-to-main` messages say `/finish` opens the PR.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` — the implement `acceptance_instruction` tells the worker to push when done.
- `herdr/.config/herdr/scripts/start-review.sh` — the reviewer prompt tells it to push after the commit; the header comment says so.
- `test/herdr_worker_scripts_test.rb` — replace `test_the_implement_worker_is_told_not_to_push` with its opposite; add the auto-implement and reviewer push tests.
- `claude/.claude/agents/reviewer.md` — step 8 pushes; the Bash rule allows that push; the description says so.
- `codex/.codex/agents/reviewer.toml` — regenerated with `bin/generate-codex-agents`.
- `claude/.claude/skills/implement/SKILL.md` — "When the worker finishes" says the pane pushes; the `here` backend's "Done" ends with the push.
- `claude/.claude/skills/review/SKILL.md` — the opening contract, the pane backend paragraph and auto mode step 2 say the round is pushed.
- `claude/.claude/skills/intent/SKILL.md` — "Autonomous delivery" step 5: commit the Codex round alone, then push.
- `claude/.claude/skills/finish/SKILL.md` — the intro says `finish` is the only step that opens a PR; §5 step 2 says the consent guard refuses `gh pr create` until §4 removed the folder.
- `claude/.claude/skills/worktree-first/SKILL.md` — line 57 lists `/finish` instead of `gh pr create`.
- `agents.md` — rule 5 (only `finish` opens a PR), rule 16 (the pre-push check applies once a PR is open; `finish` checks before it opens one), rule 25 (`/finish` opens the CI-fix PR), §7a (the coordinator opens the PR through `finish`).
- `test/pull_request_flow_test.rb` (new) — text contract tests: only `finish` runs `gh pr create`, the playbook and `lefthook.yml` say so, `implement` and the reviewer push, `finish` runs the strict check.

## Order of work

Commit after each green step, one logical change per commit.

1. Write `test_creating_a_pull_request_while_the_change_folder_exists_is_refused_naming_finish` in `test/consent_guard_test.rb`. Run `ruby -Itest test/consent_guard_test.rb -n /change_folder_exists/`. Watch it fail: the guard exits 0.
2. Add the `gh pr create` refusal to `consent-guard.rb`. Make the step-1 test green, then add the remaining create unit tests one at a time (red, green). Commit the tests and the guard together.
3. Write `test_merging_a_pull_request_whose_head_has_docs_changes_is_refused` with a stub `gh` that answers `Tree`. Watch it fail. Add the merge refusal, then the remaining merge unit tests. Commit.
4. Write `test_skip_without_pr_lets_a_stale_review_through_while_no_pull_request_is_open` in `test/review_report_check_test.rb`. Watch it fail (the script refuses). Add the flag and the open-PR lookup. Add the strict-path tests (open PR, `gh` failure, no flag). Commit.
5. Write `test_the_pre_push_hook_runs_the_check_with_skip_without_pr` and the two pushes in `test/review_push_hook_test.rb`. Watch them fail. Change the `review-report-fresh` command in `lefthook.yml`. Run `yamllint lefthook.yml`. Commit.
6. Replace `test_the_implement_worker_is_told_not_to_push` with `test_the_implement_worker_is_told_to_push_when_done`, and add `test_an_auto_implement_worker_is_told_to_push_when_done`. Watch both fail. Change `hand-off-plan.sh`. Write `test_implement_pushes_the_branch_when_done` in `test/pull_request_flow_test.rb`, watch it fail, change `implement/SKILL.md`. Commit.
7. Write `test_the_reviewer_is_told_to_push_its_round` (herdr test), `test_the_reviewer_agent_pushes_its_round` and `test_the_coordinator_pushes_the_codex_round` (flow test). Watch them fail. Change `start-review.sh`, `reviewer.md`, `review/SKILL.md` and `intent/SKILL.md`. Run `bin/generate-codex-agents claude/.claude/agents codex/.codex/agents` and confirm `test/codex_agent_generation_test.rb` is green. Commit.
8. Write `test_only_the_finish_skill_runs_gh_pr_create`, `test_the_playbook_lets_only_finish_open_a_pull_request`, `test_lefthook_messages_send_pull_requests_through_finish`, `test_finish_checks_freshness_without_the_skip` and `test_finish_removes_the_change_folder_before_it_creates_the_pull_request`. Watch the new-behaviour tests fail. Change `finish/SKILL.md`, `worktree-first/SKILL.md`, `agents.md` and the two `no-push-to-main` messages in `lefthook.yml`. Commit.
9. Run the full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. Run `rubocop` on every changed `.rb` file and on `review-report-fresh`, `shellcheck -x -S warning` on both herdr scripts, `yamllint lefthook.yml`, and the no-hardwrap `markdownlint` on every changed `.md` file. Re-read the full diff against `main`.
10. Verify by hand, as a human would, and record the output in the implement report. Pipe a `gh pr create` hook payload into `claude/.claude/hooks/consent-guard.rb` with `cwd` set to this worktree: exit 2, message names `/finish`. Repeat in a scratch clone on a branch without the folder: exit 0. Pipe a `gh pr merge 186` payload: exit 2 (PR #186 carries the folder). Run `git/.config/git/worktree-tools/review-report-fresh --skip-without-pr` in a scratch repository with a stale change folder and no PR on its remote: exit 0; without the flag: exit 1.

## Risks

- `test_the_implement_worker_is_told_not_to_push` is replaced, not weakened: the accepted intent reverses that behaviour. The replacement asserts the opposite in the same commit as the change. The reviewer must not read this as a deleted test.
- The implement and review push criteria are proven as wording (prompt and skill text), plus the tested pre-push skip that lets the push succeed. Whether an agent obeys the wording shows in the first delivery after the merge. This is the repository's convention for agent behaviour (`test/autonomy_contract_test.rb` says so in its header).
- Heredoc text is split into words, so a heredoc commit message that says `gh pr create` is refused while a change folder exists, and no marker unlocks it. Workaround: a quoted `-m` message or `git commit -F <file>`. Accepted, because the alternative (consentable) would let an agent open a PR early after one approval.
- A newline-separated `cd <dir>` followed by `gh pr create` on the next line is still caught: Shellwords turns the newline into a word break, and the `cd` target is read as usual.
- `gh pr revert`, `gh api repos/.../pulls`, `hub` and the GitHub UI can still open a PR, and the UI can merge one. The intent names `gh pr create`; these routes are out of scope (below). `gh pr revert` is the closest gap: it opens a revert PR from GitHub's side, without a local branch.
- A `gh` failure in the pre-push hook makes a work-in-progress push fail the strict check. The printed line says why. Chosen over the reverse, which would skip review whenever `gh` is down.
- Git runs hooks with `GIT_DIR` set. `gh` reads the remote through git, so it should resolve the right repository; `test/review_push_hook_test.rb` exercises exactly that path. If it fails, unset `GIT_DIR` before `gh`, as `bundle-audit` does in `lefthook.yml`.
- The merge check costs two network calls inside a 10 s hook timeout. A timed-out hook does not block (the guard's header says a hook that cannot run blocks nothing), so a slow network lets the merge through, as "where it can tell" allows.
- The Codex reviewer runs in the `workspace-write` sandbox, which may block network access. Its push then escalates to the automatic reviewer (`approvals_reviewer = "auto_review"`). The round is committed either way; the next push carries it.
- Rejected: changing `review-report-fresh`'s default to skip. It would make `finish`'s freshness gate pass vacuously.
- Rejected: a merge check on the PR diff (`gh pr view --json files`). It misses a folder inherited from the base branch and stops at 100 files.
- Rejected: adding `gh pr create`/`gh pr merge` to `GUARDED_COMMANDS` in `test/guard_parity_test.rb`. It would force a prompt rule in Codex for every `gh pr create`, including the one `finish` runs.
- Rejected: a new core value line. The guard enforces the rule mechanically; rule 5's mirrored line stays true.
- PR #186 is already open on this branch with the change folder in it. In this delivery `finish` takes the "Exists" branch (`gh pr edit`). The new merge guard refuses `gh pr merge` on #186 until `finish` removed the folder.

## Out of scope

- A GitHub Actions or other CI check; merges or PRs from the GitHub UI.
- The freshness rule for `finish`'s final push (after the folder is gone the check still exits 0).
- Per-repository lefthook files outside dotfiles.
- `gh pr revert`, `gh api` and `hub` routes to create or merge a PR.
- `codex/.codex/rules/default.rules` and `core-values.yml`.
- Closing or changing PR #186.

## Proof

- Running `gh pr create` on a branch that still has `docs/changes/pr-only-via-finish/` is refused with a message naming `/finish` → `test/consent_guard_test.rb` `test_creating_a_pull_request_while_the_change_folder_exists_is_refused_naming_finish`
- After `/finish` removes the folder, its `gh pr create` succeeds → `test/consent_guard_test.rb` `test_creating_a_pull_request_once_finish_removed_the_change_folder_is_allowed`
- Pushing a branch with `docs/changes/` and no PR succeeds without a fresh review → `test/review_push_hook_test.rb` `test_a_push_with_a_change_folder_and_no_pull_request_succeeds_without_a_fresh_review`; `test/review_report_check_test.rb` `test_skip_without_pr_lets_a_stale_review_through_while_no_pull_request_is_open` and `test_the_pre_push_hook_runs_the_check_with_skip_without_pr`
- Pushing a branch that has an open PR, or whose PR state `gh` cannot tell, keeps the strict review-freshness check, as today → `test/review_push_hook_test.rb` `test_a_push_with_a_change_folder_and_an_open_pull_request_needs_a_fresh_review`; `test/review_report_check_test.rb` `test_skip_without_pr_still_refuses_a_stale_review_once_a_pull_request_is_open`, `test_skip_without_pr_refuses_a_stale_review_when_gh_cannot_tell`, existing `test_a_code_commit_after_the_review_fails` (no flag, as `finish` runs it) and existing `test_a_branch_with_no_change_folder_passes` (unchanged). The reading of this criterion is under "Design decisions".
- When `implement` ends, the branch and its commits are on `origin` → `test/herdr_worker_scripts_test.rb` `test_the_implement_worker_is_told_to_push_when_done` and `test/pull_request_flow_test.rb` `test_implement_pushes_the_branch_when_done`
- When `review` ends, its `review.md` round is on `origin` → `test/herdr_worker_scripts_test.rb` `test_the_reviewer_is_told_to_push_its_round`, `test/pull_request_flow_test.rb` `test_the_reviewer_agent_pushes_its_round` and `test_the_coordinator_pushes_the_codex_round`
- `gh pr merge` on a branch whose tree still has `docs/changes/` is refused → `test/consent_guard_test.rb` `test_merging_a_pull_request_whose_head_has_docs_changes_is_refused`

Per changed file, the unit tests expected, named as behaviour:

- `claude/.claude/hooks/consent-guard.rb`: `test_creating_a_pull_request_on_main_is_allowed`, `test_a_change_folder_in_a_cd_target_is_found`, `test_a_cd_target_glued_to_a_semicolon_is_found`, `test_a_cd_target_on_the_line_before_is_found`, `test_creating_a_pull_request_inside_bash_dash_c_is_refused`, `test_consent_does_not_unlock_creating_a_pull_request_with_a_change_folder`, `test_a_quoted_message_naming_gh_pr_create_is_allowed`, `test_a_codex_payload_creating_a_pull_request_with_a_change_folder_is_refused`, `test_merging_a_pull_request_whose_head_has_no_docs_changes_is_allowed`, `test_merging_is_allowed_when_gh_cannot_tell`, `test_merging_asks_gh_about_the_named_pull_request_and_repository`. Existing `test_a_push_followed_by_another_command_is_allowed` stays green (its repository is on `main`).
- `git/.config/git/worktree-tools/review-report-fresh`: `test_skip_without_pr_never_calls_gh_without_a_change_folder`, `test_without_the_flag_gh_is_never_called`, `test_skip_without_pr_refuses_a_stale_review_when_gh_cannot_tell`. All existing tests stay unchanged and green: they run without the flag.
- `lefthook.yml`: `test_the_pre_push_hook_runs_the_check_with_skip_without_pr` (in `test/review_report_check_test.rb`), `test_lefthook_messages_send_pull_requests_through_finish` (in `test/pull_request_flow_test.rb`).
- `herdr/.config/herdr/scripts/hand-off-plan.sh`: `test_an_auto_implement_worker_is_told_to_push_when_done`.
- `claude/.claude/skills/finish/SKILL.md`, `worktree-first/SKILL.md`, `agents.md`: `test_only_the_finish_skill_runs_gh_pr_create` (scans `claude/.claude/skills`, `claude/.claude/agents`, `herdr/.config/herdr/scripts`, `lefthook.yml` and `agents.md`), `test_the_playbook_lets_only_finish_open_a_pull_request`, `test_finish_checks_freshness_without_the_skip`, `test_finish_removes_the_change_folder_before_it_creates_the_pull_request`.

Test setup: each guard and freshness test builds a throwaway git repository in `Dir.mktmpdir`, as the existing tests do, on a branch such as `pr-only-via-finish` with `docs/changes/pr-only-via-finish/intent.md` committed. A stub `gh` script in a temporary `bin` directory goes first on `PATH`; it logs its arguments to a file and answers from environment variables (open-PR count, the `pr view` TSV line, `Tree` or `absent`, or exit 1). The guard tests already pass `HOME`; they also pass that `PATH`. `test/review_push_hook_test.rb` copies `setup` from `test/lefthook_global_hooks_sync_test.rb` (temporary `HOME`, the global hooks linked under `~/.config/git/hooks`, `lefthook.yml` under `~/Developer/dotfiles`, a bare origin) and links `~/.config/git/worktree-tools` to this repository's `git/.config/git/worktree-tools`, so the real script and its `change-folder` lookup run; its `PATH` also holds the running Ruby's `bin` directory. Text contract tests read files from the repository, as `test/autonomy_contract_test.rb` does.

---
Domain skills applied: dotfiles-maintenance (playbook mirror in `core-values.yml`, stow, global git hooks).

## Critique

### Round 1 (codex exec -p terra)

- The plan knowingly misses acceptance criterion 4 and defers confirmation to "before merge" → fixed (the reading stays, but Design decisions now marks it as an open decision for the coordinator to settle before the implement stage, and the plan report raises it as a `Decision needed:` line)
- The merge guard checks the PR diff, not the head tree, so an inherited folder passes, and `gh pr view --json files` stops at 100 files → fixed (the merge check now reads the head commit's tree through a `gh api graphql` object lookup of `<oid>:docs/changes`, verified on PR #186 and PR #185; the diff approach moved to Risks as rejected)
- `gh pr revert` is a PR-creation path the plan does not address → fixed (Out of scope and Risks now name `gh pr revert` explicitly, next to `gh api` and `hub`; the intent's guard bullet names `gh pr create` only)
- `cd` detection fails on `cd dir;` glued operators and on `sh -c '...'` → fixed (cd targets lose a glued shell operator; the PR checks re-split the `-c` argument of `sh`, `bash` and `zsh`; tests added for `;`, newline and `bash -c`)
    - The suggestion to fail closed on every unsupported shell construct is not taken: the guard reads words by design, and `eval` or script files are named as invisible in Design decisions.
- The pre-push behaviour is not tested through its real path (hook, lefthook, stowed script, `gh`) → fixed (new `test/review_push_hook_test.rb` pushes to a bare origin through the global hook and lefthook with a stub `gh`, for both the skip and the strict case)
- The implement and review push criteria are proven only as instructions, not outcomes → dismissed: an agent's obedience to a prompt cannot run in a unit test without a live herdr session and a model; the repository proves agent behaviour as wording by convention, and the push's success is covered by the integration test above; Risks states the limit
- `lefthook.yml` lines 68 and 251 still tell the reader to "open a PR", and the scanner skips `lefthook.yml` → fixed (both messages now name `/finish`, the scanner covers `lefthook.yml`, and `test_lefthook_messages_send_pull_requests_through_finish` pins them)
