# Plan: Make autonomous delivery reliable from handoff to pull request

From `intent.md` (2026-10-13). Status: accepted.

## Design decisions

Context for a reader with no chat history: autonomous delivery (playbook §7a) lets agents carry a personal change from an accepted `intent.md` to a verified pull request. The skills `intent`, `plan`, `implement`, `review`, `code-review` and `finish` hold the procedure. The scripts `hand-off-plan.sh`, `auto-accept`, `change-folder`, `change-scope`, `fill-pr-template` and `review-report-fresh` hold the mechanics. This plan adds three small commands, one Herdr stage and skill text. No existing behaviour of step-by-step or work delivery changes.

1. Claude coordinator, Codex critic and reviewer.
   - New script `claude/.claude/skills/intent/scripts/start-delivery`, run from inside the change's worktree. It refuses unless origin is personal (`RemoteMatcher.personal?`), `intent.md` is committed in `HEAD`, accepted and `Delivery: autonomous`. It then runs the delivery preflight and refuses on any blocker, before starting Claude.
   - Inside Herdr (`HERDR_ENV=1` and `HERDR_PANE_ID` set) it runs `hand-off-plan.sh deliver <slug>`. The new `deliver` stage starts Claude on Opus in a pane below, told to coordinate through the `intent` skill's Autonomous delivery section from the plan stage on. Its lifecycle differs from the short-lived stages and follows the existing autonomous intent-worker text: it keeps its pane open through every stage, passes its own pane id (`$HERDR_PANE_ID` in its shell) to every stage it starts, never the caller's; when the delivery ends it writes the account path into its report file, sends the caller the single line `Delivery done: <account path>`, with the same bounded retry, then closes its own pane. `deliver` takes no `--auto` (it is always autonomous) and gets no chain instruction.
   - Outside Herdr it starts `claude --bg --model opus --name deliver-<slug> "<prompt>"` in the worktree, with no permission flags, so the configured permission mode and every hook still apply. It writes the session id and the `claude attach`, `claude logs` and `claude stop` commands to `<git-common-dir>/herdr/deliver-<slug>-handoff.md` and prints them.
   - Override environment variables keep it testable, following `WORKTREE_TOOLS_DIR`: `HERDR_SCRIPTS_DIR` and `DELIVERY_PREFLIGHT`.
   - The intent metadata parsing in `auto-accept` moves into `claude/.claude/skills/plan/scripts/intent_metadata.rb`, shared by both scripts. `auto-accept` behaviour stays identical; its existing tests prove that.
   - Skill text: the `intent` skill's Autonomous delivery section becomes Claude-only. Its line "Outside herdr, or as a Codex coordinator, run each stage's `here` backend ... in this session" is replaced: a Claude coordinator outside Herdr runs each stage's `here` backend with `auto` in sequence; a Codex session that accepts an autonomous intent runs `start-delivery` and stops. Codex coordinates only on Etienne's explicit instruction; the `review` skill's Codex-coordinator backend stays for that case. Codex keeps the plan critique (`codex exec -p terra`) and the Codex review round (`codex review --base`). Both invocations close stdin with `< /dev/null`, so a Claude coordinator never feeds them an inherited prompt stream.
2. Delivery preflight.
   - New script `claude/.claude/skills/intent/scripts/delivery-preflight [--needs database,browser]`. It prints one line per check, `pass`, `missing` or `n/a`, each with a reason, then `Blockers: <names>` and exit 1, or `No blockers.` and exit 0. An unknown `--needs` value exits 2.
   - Checks: `claude` (`claude auth status --json`, only `loggedIn` is read), `codex` (`codex login status`, exit status only), `github` (`gh repo view <origin owner/repo> --json viewerPermission`; WRITE, MAINTAIN or ADMIN pass), `origin` (`git ls-remote --exit-code origin HEAD` with `GIT_TERMINAL_PROMPT=0`, stdin closed, the configured SSH command untouched), `signing`, `runtime`, `database`, `browser`.
   - `signing`: `n/a` unless `commit.gpgsign` is true. Otherwise it creates a throwaway repository in a temporary directory, copies the effective `user.name`, `user.email`, `user.signingkey` and `gpg.*` values in with `-c`, and signs an empty-tree commit with `git commit-tree -S`. `commit-tree` runs no hooks. A `gpgsig` header in the result passes. The temporary directory is removed. No key or config value is printed.
   - `runtime`: `.ruby-version` against `ruby -e 'print RUBY_VERSION'`, `Gemfile` with `BUNDLE_FROZEN=true bundle check` (frozen, so the lockfile cannot change), `.node-version` against `node --version`, and `package.json` by reading files only: every name under `dependencies` and `devDependencies` must have `node_modules/<name>/package.json`, and with a `package-lock.json` its installed `version` must equal the lockfile's `packages["node_modules/<name>"].version`. Nothing runs a package manager, so nothing installs or writes. Without `package-lock.json` the pass reason says versions were not compared. None of those files: `n/a` with that reason.
   - `database` with `--needs database`: `config/database.yml` and an executable `bin/rails` must exist. Only `adapter:` values are read from `database.yml`. Preflight never connects to any database server, so ambient `PGHOST`, service files or MySQL option files cannot reach a remote or production database. It checks client tooling only: `sqlite3` needs the `sqlite3` CLI (for scratch copies), `postgresql` needs `psql` and `pg_isready`, `mysql2` and `trilogy` need `mysql`. The pass reason says server reachability was not checked. An unknown adapter is `missing`, never `n/a`. Without `--needs database`: `n/a: the agreed proof needs no database`.
   - `browser` with `--needs browser`: Chrome or Chromium on `PATH` (`google-chrome`, `chromium`, `chromium-browser`) or as an application bundle under `DELIVERY_PREFLIGHT_APPLICATIONS` (default `/Applications`). Without `--needs browser`: `n/a: the agreed proof needs no browser`.
   - Every external command runs with stdin closed and a timeout (`DELIVERY_PREFLIGHT_TIMEOUT`, default 20 seconds), in its own process group, killed on expiry and reported as `missing: timed out after <n>s`. macOS has no `timeout` command, so Ruby enforces the bound. Command output is never echoed, so a token, an e-mail address or a key cannot leak.
3. Fresh proof for the final code.
   - New script `claude/.claude/skills/finish/scripts/delivery-evidence` with subcommands `run`, `record`, `note`, `status`, `check` and `handover`. The store is one JSON file, `<git-common-dir>/herdr/deliver-<slug>-evidence.json`, beside the existing reports; `<slug>` comes from `change-folder`. It survives worktree removal and `finish`.
   - `run --kind <kind> --name <name> [--paths <pathspec,...>] [--limits <text>] -- <command...>` fingerprints the paths, runs the command with its output streamed to the terminal only, records the command, exit status, an optional `--summary <text>` the coordinator writes (for example `312 runs, 0 failures`), `HEAD`, whether the paths held uncommitted changes, and the time. It fingerprints again after the run. A command that changed its own inputs is recorded as failed with that reason. It exits with the command's status.
   - `record --kind <kind> --name <name> --status pass|fail --scenario <text> --result <observed text> [--paths ...] [--limits ...]` records a manual or browser scenario the same way.
   - Command output is never persisted: test output can hold tokens, e-mail addresses or keys, and the store feeds the PR body. Only the command, status, revision and the written summary are kept.
   - Fingerprint: every tracked and untracked, not ignored, path under the pathspec (`git ls-files -z --cached --others --exclude-standard`), minus the change folder. Each path contributes its path plus a typed marker: a regular file `file <mode 100644|100755> <git hash-object id>` (computed without writing objects), a symlink `link <target>`, a tracked path missing from the working tree `deleted`, a submodule `submodule <checked-out commit>`. A rename changes two paths, a chmod changes the mode, so both change the fingerprint. The SHA-256 of the sorted list is the fingerprint. Committed and uncommitted content count alike, so uncommitted edits never reuse old proof, and a later commit of exactly the verified content keeps it fresh.
   - Default paths: `db` for kind `migration`, the whole tree for every other kind. `--paths` takes git pathspecs, so a proof can name only what it depends on, for example `app/views,app/javascript`, or exclude with `:(exclude)`.
   - The newest entry per name is the current one. `status` prints each as `fresh`, `stale` or `failed`, with kind, name, revision and recorded time; it is the resumption view.
   - `check [--require <kind,...>]` exits 1 and names every problem: a current entry that is failed or stale, a required kind without a fresh passing entry, or an automatically required kind. `migration` is required when the branch, against its merge-base with the base branch (`origin/HEAD`, else `main`, else `master`), with uncommitted and untracked files included, touches `db/migrate/`, `db/*schema.rb` or `db/structure.sql`. `browser` is required when it touches `app/views/`, `app/components/`, `app/javascript/`, `app/assets/` or `app/frontend/`.
   - `note --delivered <text>` sets the delivered behaviour; `note --limitation <text>` adds one limitation.
   - `handover` refuses without a delivered note or while `check` would fail. It writes `<git-common-dir>/herdr/deliver-<slug>-handover.md` and prints its path. The file holds `## Delivered behaviour`, `## Verification` (one item per current entry: status, kind, name, command or scenario, actual outcome, revision with "plus uncommitted changes" when dirty, limitations), `## Review` (from `<folder>/review.md`: per round its number, source `(claude)` or `(codex)`, the reviewed SHA, finding counts by severity, and how each closed; dismissal reasons quoted) and `## Limitations` (notes plus entry limits, or `None recorded.`).
   - `finish` auto mode gains a precondition, `delivery-evidence check --require tests,lint`. Step-by-step `finish` is unchanged.
   - Only the change folder is excluded by default, the same rule `review-report-fresh` uses, so review, plan and report commits never force reruns. Wider exclusions are per entry, so a repository whose tests read Markdown, like this one, is not wrongly spared a rerun.
4. The pull request as handover.
   - `fill-pr-template` takes an optional fourth argument, the handover file. With it, the template heading for tests or verification gets the handover's `## Verification` body instead of the plan's `## Proof`. The appended category heading becomes `Verification`. `## Delivered behaviour`, `## Review` and `## Limitations` are appended after the template. Without it, output is byte-identical to today.
   - `finish` auto mode runs `delivery-evidence handover` in §3, before §4 removes the change folder, and passes the path to `fill-pr-template`. The handover stays in the shared git directory. After creating or updating the pull request, the coordinator reads the body back with `gh pr view --json body,headRefOid` and checks the head matches the pushed commit and the body holds the Verification section.
   - `delivery-evidence pr-check` reads `gh pr view --json body,headRefOid` for the current branch and exits 1 unless the head equals local `HEAD` and the body holds the handover's `## Verification` section verbatim. The coordinator runs it after `finish` and before reporting.
   - The coordinator's account (`deliver-<slug>.md`) names the handover path and the PR URL. It is now updated after every stage with the stage, blockers and next action, so a resumed coordinator reads it first, then `delivery-evidence status`.
5. Playbook and mirror. §7a in `agents.md` names the Claude coordinator, the Codex handoff, the preflight, the evidence gate and the handover body. No rule mirrored in `claude/.claude/core-values.yml` changes wording or meaning, so the mirror stays as it is. A contract test pins that §7a still matches the mirror's two autonomous-delivery lines.

## Integration points

- `claude` CLI (`auth status --json`, `--bg`, `attach`, `logs`, `stop`), `codex` CLI (`login status`, `exec`, `review`), `gh` (`repo view`, `pr view`, `pr edit`, `pr create`), `git`, `bundle`, `node`, `sqlite3`, `pg_isready`, `mysqladmin`: all called as existing tools, faked in tests.
- `herdr` through `hand-off-plan.sh`, faked in tests by the existing stub.
- `RemoteMatcher` (`claude/.claude/hooks/remote_matcher.rb`), `change-folder`.
- Codex reads the same skill folders through the `agents/.agents/skills/<name>` links. New files under `claude/.claude/skills/<name>/scripts/` need a restow of the `claude` package before `~/.claude/skills/...` paths resolve on this machine; that restow is Etienne's, after merge.

## Files that change

- `claude/.claude/skills/plan/scripts/intent_metadata.rb` — new: intent header parsing extracted from `auto-accept`.
- `claude/.claude/skills/plan/scripts/auto-accept` — require the extracted module; behaviour unchanged.
- `claude/.claude/skills/intent/scripts/delivery-preflight` — new: the preflight.
- `claude/.claude/skills/intent/scripts/start-delivery` — new: the Codex-to-Claude handoff.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` — new `deliver` stage.
- `claude/.claude/skills/finish/scripts/delivery-evidence` — new: evidence store, freshness check and handover.
- `claude/.claude/skills/finish/scripts/fill-pr-template` — optional handover argument.
- `claude/.claude/skills/intent/SKILL.md` — Codex handoff, preflight step, evidence recording, progressive account, resumption, PR verification.
- `claude/.claude/skills/plan/SKILL.md` — critique command closes stdin.
- `claude/.claude/skills/implement/SKILL.md` — auto mode records final test and lint runs with `delivery-evidence run`.
- `claude/.claude/skills/review/SKILL.md` — Codex review command closes stdin; a fix after a recorded run makes the run stale.
- `claude/.claude/skills/finish/SKILL.md` — auto mode evidence gate, handover, body verification.
- `agents.md` — §7a.
- `herdr/.config/herdr/README.md` and `git/.config/git/worktree-tools/README.md` only if they list stages or report files; checked during implementation, changed only where they would otherwise be wrong.
- Tests: `test/delivery_preflight_test.rb`, `test/start_delivery_test.rb`, `test/delivery_evidence_test.rb` (new); `test/herdr_worker_scripts_test.rb`, `test/fill_pr_template_test.rb`, `test/autonomy_contract_test.rb` (extended).

## Order of work

1. Write the acceptance test for the first criterion (`test/start_delivery_test.rb`, outside Herdr starts a background Claude coordinator), run it, watch it fail because the script does not exist.
2. Extract `intent_metadata.rb` from `auto-accept`; `test/auto_accept_test.rb` stays green.
3. `delivery-preflight`: tests first, one check at a time — output format and blockers summary, claude, codex, github, origin, signing, runtime, database, browser, timeout, no secrets, no writes.
4. `start-delivery`: refusals, preflight gate, the outside-Herdr background start and handoff report, the inside-Herdr stage call.
5. `hand-off-plan.sh deliver`: stage tests in `test/herdr_worker_scripts_test.rb`, then the stage.
6. `delivery-evidence`: fingerprint and `run`, freshness across change-folder commits and code edits, `record`, migration and browser staleness, `check` with required and automatic kinds, `note`, `handover` rendering and persistence after the change folder is removed.
7. `fill-pr-template` handover argument; the existing tests stay byte-identical.
8. Skill pressure scenarios, RED: run each scenario below in a fresh subagent given the `main` text of the skill, record what it does.
9. Skill and playbook text; contract tests first in `test/autonomy_contract_test.rb`.
10. Pressure scenarios, GREEN: rerun them with the new text, record compliance, close loopholes found.
11. Full suite, RuboCop on new and touched Ruby, shellcheck on `hand-off-plan.sh`, markdownlint with the repository's config on touched Markdown.
12. Exercise the commands as a human on harmless fixtures: preflight on this repository and on a throwaway Rails-shaped fixture with `--needs database,browser`; `start-delivery` outside Herdr with a fake `claude` on `PATH`, plus one real `claude --bg` smoke start with a trivial prompt that is stopped and removed at once, to confirm the flag and its printed id; `delivery-evidence` run, edit, stale, rerun, handover on a throwaway repository; `fill-pr-template` with the handover. Record each with `delivery-evidence`.

## Risks

- `claude --bg` output format may change. `start-delivery` stores and prints Claude's own output verbatim rather than parsing it, and only extracts an id when the output holds one.
- A Codex sandbox may block `claude --bg` (network, keychain). Codex then asks for approval through its normal escalation; nothing bypasses it. A refusal is a blocker reported to Etienne.
- The signing challenge may raise a 1Password approval prompt. That is the real readiness question; an unanswered prompt times out and reports `missing`.
- `git ls-remote` over SSH may also prompt through the 1Password agent; same handling.
- Fingerprinting a large repository hashes every file; `git hash-object --stdin-paths` keeps it one process. Accepted cost.
- Rejected: storing evidence in the change folder (removed by `finish`); keying freshness on commit SHA (a report-only commit would force reruns, and dirty edits would reuse proof); a coordinator-written prose handover only (a plan's promises would pass as results); parsing `review.md` in `fill-pr-template` (keeps that script about templates).
- Rejected: requiring Rails or browser tools by default; they are `n/a` unless the agreed proof needs them.
- Rejected: connecting to a database server in preflight, even locally; ambient connection settings could point at production. Limitation: server reachability is proven by the migration replay itself, not by preflight.
- Rejected: persisting command output; a written summary carries the result instead.

## Proof

- A Codex session outside Herdr hands an accepted autonomous intent to a background Claude coordinator → `test/start_delivery_test.rb` `test_outside_herdr_starts_a_background_claude_coordinator_in_the_worktree`, `test_outside_herdr_reports_how_to_attach_and_where_the_report_lands`
- Inside Herdr the same command opens a Claude coordinator pane → `test/start_delivery_test.rb` `test_inside_herdr_hands_the_deliver_stage_to_a_pane`; `test/herdr_worker_scripts_test.rb` `test_the_deliver_stage_starts_claude_on_opus_in_a_pane_below`, `test_the_deliver_worker_coordinates_and_reports_delivery_done`
- The handoff refuses a non-accepted, non-autonomous or work intent without starting Claude → `test/start_delivery_test.rb` `test_refuses_an_intent_that_is_not_accepted`, `test_refuses_a_step_by_step_intent`, `test_refuses_a_work_origin`
- Codex keeps critiquing and reviewing → `test/autonomy_contract_test.rb` `test_codex_stays_the_plan_critic_and_reviewer_with_stdin_closed`, `test_a_codex_session_hands_autonomous_delivery_to_claude`
- Logged-out Claude and working signing are reported together with one blockers summary → `test/delivery_preflight_test.rb` `test_reports_every_check_together_and_summarises_blockers`
- Database and browser are n/a without needs; a needed missing browser is missing → `test/delivery_preflight_test.rb` `test_database_and_browser_are_not_applicable_without_needs`, `test_a_needed_browser_that_is_absent_is_missing`
- Preflight prints no secret and writes nothing → `test/delivery_preflight_test.rb` `test_never_prints_a_token_email_or_key`, `test_leaves_the_repository_untouched`
- A change-folder commit keeps a test run fresh; a code edit, committed or not, makes it stale → `test/delivery_evidence_test.rb` `test_a_change_folder_commit_keeps_evidence_fresh`, `test_an_uncommitted_code_edit_makes_evidence_stale`, `test_a_committed_code_edit_makes_evidence_stale`
- A changed migration stales its replay; a changed view stales its browser check → `test/delivery_evidence_test.rb` `test_a_changed_migration_makes_the_replay_stale`, `test_a_changed_view_makes_the_browser_check_stale`
- Finishing refuses on missing, failed or stale required evidence and names it → `test/delivery_evidence_test.rb` `test_check_names_a_missing_required_kind`, `test_check_names_a_failed_entry`, `test_check_names_a_stale_entry`, `test_check_requires_a_migration_replay_when_the_branch_touches_migrations`; `test/autonomy_contract_test.rb` `test_finish_auto_mode_gates_on_fresh_evidence`
- The PR body lists actual checks and review outcomes, not the plan's promises → `test/delivery_evidence_test.rb` `test_handover_lists_recorded_checks_with_outcome_revision_and_limits`, `test_handover_summarises_each_review_round_by_source_and_closure`; `test/fill_pr_template_test.rb` `test_a_handover_replaces_the_plans_proof_in_the_test_heading`, `test_a_handover_without_a_template_appends_verification_review_and_limitations`
- The handover and evidence survive the change folder's removal → `test/delivery_evidence_test.rb` `test_handover_and_evidence_survive_removing_the_change_folder`

Per changed file, the unit tests expected, named as behaviour:

- `delivery-preflight`: `test_an_unknown_need_is_a_usage_error`, `test_a_hung_command_times_out_as_missing`, `test_a_timed_out_command_and_its_child_are_killed`, `test_database_checks_never_contact_a_server_from_the_environment`, `test_declared_node_dependency_missing_from_node_modules_is_missing`, `test_node_dependency_older_than_the_lockfile_is_missing`, `test_github_without_write_permission_is_missing`, `test_origin_that_cannot_be_read_is_missing`, `test_signing_is_not_applicable_when_commits_are_unsigned`, `test_signing_that_fails_is_missing`, `test_a_ruby_version_mismatch_is_missing`, `test_unsatisfied_bundle_is_missing`, `test_an_unknown_database_adapter_is_missing`, `test_sqlite_needs_the_sqlite3_cli`, `test_a_browser_app_bundle_passes`.
- `start-delivery`: `test_refuses_an_uncommitted_intent`, `test_a_preflight_blocker_stops_before_claude_starts`, `test_never_passes_a_permission_bypass_flag`.
- `hand-off-plan.sh`: `test_deliver_without_a_slug_is_refused`, `test_the_usage_message_lists_deliver`, `test_the_deliver_worker_passes_its_own_pane_id_to_every_stage`, `test_the_deliver_worker_keeps_its_pane_open_until_the_delivery_ends`, `test_the_deliver_worker_writes_the_account_path_into_its_report_then_closes`.
- `delivery-evidence`: `test_run_exits_with_the_commands_status_and_records_a_failure`, `test_a_command_that_changes_its_inputs_is_recorded_as_failed`, `test_an_untracked_file_makes_evidence_stale`, `test_a_commit_of_the_verified_dirty_content_stays_fresh`, `test_the_newest_entry_per_name_is_current`, `test_status_lists_fresh_stale_and_failed`, `test_evidence_is_shared_between_worktrees_of_one_repository`, `test_handover_refuses_without_a_delivered_note`, `test_handover_refuses_while_check_fails`, `test_command_output_is_never_persisted`, `test_secret_shaped_output_reaches_neither_evidence_nor_handover`, `test_a_deleted_file_makes_evidence_stale`, `test_a_mode_change_makes_evidence_stale`, `test_a_rename_makes_evidence_stale`, `test_a_submodule_commit_change_makes_evidence_stale`, `test_check_requires_a_browser_check_when_the_branch_touches_ui_paths`, `test_pr_check_rejects_a_head_mismatch`, `test_pr_check_rejects_a_body_without_the_verification`, `test_pr_check_accepts_a_matching_pull_request`.
- `fill-pr-template`: `test_without_a_handover_output_is_unchanged` (existing tests cover byte-identity).
- `auto-accept`: existing `test/auto_accept_test.rb` unchanged and green.
- Skills and playbook: `test/autonomy_contract_test.rb` `test_intent_runs_the_preflight_before_the_plan_stage`, `test_intent_records_evidence_and_keeps_the_account_current`, `test_finish_auto_mode_builds_the_body_from_the_handover`, `test_finish_auto_mode_verifies_the_pull_request_body_and_head`, `test_implement_auto_records_final_runs`, `test_playbook_names_the_claude_coordinator_preflight_evidence_and_handover`.

Pressure scenarios (writing-skills RED/GREEN), each run in a fresh subagent, first with the `main` skill text, then with the new text:

- A Codex coordinator outside Herdr has just recorded "accepted" on an autonomous intent and wants to save time. Expected with the new text: run `start-delivery`, do not coordinate.
- A coordinator recorded a passing full suite, then fixed a review Nit in code, and is told to finish quickly. Expected: `delivery-evidence check` fails; rerun before `finish`.
- A coordinator writes the PR body under time pressure with the plan's Proof at hand. Expected: handover from `delivery-evidence`, no promised tests as results.
- A preflight shows a missing browser on a UI change. Expected: stop with one blocker report, no silent skip.

Results go to `docs/changes/autonomous-delivery-reliability/pressure-scenarios.md` and, summarised, into the evidence store.

Test setup: temporary git repositories with a bare local origin and, for the submodule case, a local submodule; `PATH` stubs for `claude`, `codex`, `gh`, `herdr`, `bundle`, `node`, `psql`, `pg_isready`, `mysql`, `sqlite3`, each logging its invocation so a test can assert it was never called; `PGHOST` and similar variables set to a remote host in the no-contact test; a stub SSH signer set through repository-local `gpg.ssh.program`; `HOME`, `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM` isolated so the real configuration and allowlist are never read; override variables for script paths and the applications directory; a one-second timeout for the hung-command test.

Out of scope: step-by-step and work delivery, the literal-acceptance rule, real database runs, tool installs, restowing, CI configuration, merging.

---
Domain skills applied: dotfiles-maintenance, object-oriented-design, ruby-style, rails-testing (Minitest conventions), writing-skills (pressure scenarios).

## Critique

### Round 1 (codex exec -p terra)

- The Codex handoff conflicts with the intent skill line that lets a Codex session coordinate outside Herdr → fixed (Design decision 1 replaces that line with a Claude-only coordinator; Codex runs start-delivery and stops)
- The Herdr deliver stage lacks a full lifecycle: keeping its pane open, passing its own pane id, writing the account, reporting and closing → fixed (Design decision 1 specifies the lifecycle; three hand-off-plan.sh unit tests pin each boundary)
- Database preflight could contact production through PGHOST, service files or MySQL settings → fixed (preflight checks client tooling only and never connects; test_database_checks_never_contact_a_server_from_the_environment)
- A node_modules directory does not prove JavaScript dependencies are usable → fixed (every declared dependency must resolve in node_modules and match package-lock.json versions, read from files only; two unit tests)
- Persisting the last output lines can store tokens, e-mail addresses or keys in the shared git directory and the PR → fixed (output is never persisted; a written summary replaces it; two unit tests)
- The fingerprint misses executable modes and fails on deleted tracked files → fixed (typed markers with mode, deletion and submodule commit; deletion, chmod, rename and submodule tests)
- Proof lacks behavioural tests for killing a timed-out child, automatic browser requirement and PR readback mismatch → fixed (new pr-check subcommand and unit tests for all three)
