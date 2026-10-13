# Review: autonomous-delivery-reliability

## Round 1 — 2026-10-13T13:37:00Z — b8438c79

Checks run: `test/delivery_evidence_test.rb` (32 runs), `test/delivery_preflight_test.rb` (32), `test/start_delivery_test.rb` (9), `test/autonomy_contract_test.rb` (38), `test/fill_pr_template_test.rb` (30), `test/auto_accept_test.rb` (58): all green. RuboCop on the 17 new and touched Ruby files: no offenses. shellcheck on `hand-off-plan.sh`: clean. The full suite was not rerun here; the coordinator's background run is in progress.

- [ ] Important: `start_claude` reads the `claude --bg` output through a pipe until EOF, with no time bound. If the background session or its supervisor inherits the write end, `start-delivery` hangs and never writes the handoff file. `delivery-preflight` names this exact hazard in its comment (lines 81-82) and captures to a file for that reason. No smoke start of a real `claude --bg` is recorded to show the pipe closes. — `claude/.claude/skills/intent/scripts/start-delivery:87` →
- [ ] Important: Plan step 12 requires a human exercise of each command, including one real `claude --bg` smoke start, each recorded with `delivery-evidence`. The plan also requires a pressure-scenario summary in the evidence store. No store exists at `<git-common-dir>/herdr/deliver-autonomous-delivery-reliability-evidence.json`. The only record is `pressure-scenarios.md`, and `finish` deletes it. — `docs/changes/autonomous-delivery-reliability/plan.md:156` →
- [ ] Nit: The preflight reads `.ruby-version`, `Gemfile`, `.node-version`, `package.json` and `config/database.yml` relative to the current directory, not the repository root. `start-delivery` runs it in the caller's directory. From a subdirectory, `runtime` reports `n/a` (a silent skip, which the intent forbids) and `--needs database` reports a missing config. — `claude/.claude/skills/intent/scripts/delivery-preflight:186` →
- [ ] Nit: Inside herdr, `start-delivery` checks the intent in the current worktree, but `hand-off-plan.sh deliver` calls `worktree-create <slug>`. That reuses only `.worktrees/<slug>` on branch `<slug>`. For a prefixed branch such as `ai/fix-login`, which `change-folder` accepts, the coordinator pane starts in a new worktree off origin's default branch without the accepted intent. Outside herdr the current toplevel is used, so the two routes can differ. — `claude/.claude/skills/intent/scripts/start-delivery:129` →
- [ ] Nit: `run` stores the command line verbatim, and the handover publishes it in the PR body. A secret on the command line, such as an `env TOKEN=...` prefix or a `--token` argument, is persisted and published, although the store promises it never holds secrets. — `claude/.claude/skills/finish/scripts/delivery-evidence:43` →
- [ ] Nit: When `base_branch` resolves to nothing (no `origin/HEAD` and no local `main` or `master`), `branch_paths` returns an empty list. The automatic `migration` and `browser` requirements then drop away without a message. — `claude/.claude/skills/finish/scripts/delivery_evidence/repo.rb:54` →
- [ ] Nit: An uninitialized submodule gets the fixed marker `submodule uninitialized`, which ignores the recorded gitlink commit. A pointer bump in that submodule therefore keeps the evidence fresh. — `claude/.claude/skills/finish/scripts/delivery_evidence/fingerprint.rb:51` →

5 more nits not listed.

### Compliance

- A Codex session outside Herdr hands off to a background Claude coordinator, and the command prints how to attach → `test_outside_herdr_starts_a_background_claude_coordinator_in_the_worktree`, `test_outside_herdr_reports_how_to_attach_and_where_the_report_lands` (stub `claude` only; see the Important finding on the real start).
- Inside Herdr, a coordinator pane opens below → `test_inside_herdr_hands_the_deliver_stage_to_a_pane`, `test_the_deliver_stage_starts_claude_on_opus_in_a_pane_below`.
- Refuses a non-accepted, non-autonomous or work intent without starting Claude → `test_refuses_an_intent_that_is_not_accepted`, `test_refuses_a_step_by_step_intent`, `test_refuses_a_work_origin`.
- Codex keeps the plan critique and the review → `test_codex_stays_the_plan_critic_and_reviewer_with_stdin_closed`.
- Logged-out Claude and working signing are reported together with one blockers summary → `test_reports_every_check_together_and_summarises_blockers`.
- Database and browser are `n/a` without needs, and a needed absent browser is missing → `test_database_and_browser_are_not_applicable_without_needs`, `test_a_needed_browser_that_is_absent_is_missing`.
- No secrets printed, no writes, no database contact → `test_never_prints_a_token_email_or_key`, `test_leaves_the_repository_untouched`, `test_database_checks_never_contact_a_server_from_the_environment`.
- A change-folder commit stays fresh; a committed or uncommitted code edit goes stale → `test_a_change_folder_commit_keeps_evidence_fresh`, `test_an_uncommitted_code_edit_makes_evidence_stale`, `test_a_committed_code_edit_makes_evidence_stale` (plus deletion, chmod, rename, submodule and untracked tests).
- A changed migration or view stales its proof → `test_a_changed_migration_makes_the_replay_stale`, `test_a_changed_view_makes_the_browser_check_stale`.
- `finish` auto refuses on missing, failed or stale evidence and names it → `test_check_names_a_missing_required_kind`, `test_check_names_a_failed_entry`, `test_check_names_a_stale_entry`, `test_finish_auto_mode_gates_on_fresh_evidence`.
- The PR body lists actual checks and review rounds → `test_handover_lists_recorded_checks_with_outcome_revision_and_limits`, `test_handover_summarises_each_review_round_by_source_and_closure`, `test_a_handover_replaces_the_plans_proof_in_the_test_heading`.
- The handover and evidence survive the folder's removal → `test_handover_and_evidence_survive_removing_the_change_folder`.

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted: the only removed lines are the old `run_fill` helper in `test/fill_pr_template_test.rb`, which was replaced to accept the optional handover argument. The `fill-pr-template` output without a handover, step-by-step `finish` and the non-deliver stage prompts of `hand-off-plan.sh` stay as they were.
