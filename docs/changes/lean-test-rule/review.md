# Review: lean-test-rule

## Round 1 — 2026-10-20T13:19:11Z — 6c0c694f (codex)

Nothing found. `codex review --base origin/main` reported no actionable defects. It ran with a scratch `CODEX_HOME`, because the user config in the main checkout has a stash conflict.

## Round 2 (claude) — 2026-10-20T13:21:52Z — 6c0c694f

- [ ] Nit: Broken sentence in step 2: "Fix the verified findings Follow the playbook test rule:" lacks a stop or colon between the two clauses — `agents/.agents/skills/code-review/SKILL.md:13` → fixed (Fix the broken sentence in the code-review test rule step)

Acceptance criteria all map to a test in `test/test_rule_mirror_test.rb`; every Proof test exists and passes (mirror 9 runs, hotwire 28 runs, codex agent generation 5 runs, all green). No legacy phrase remains outside `docs/`. No existing test was skipped; the replaced mobile-exception tests are superseded as the plan states.

## Round 3 (codex) — 2026-10-20T13:29:10Z — 66948e8a

- [ ] Important: A configuration-only plan has contradictory instructions: step 1 is "always" a failing acceptance test, but a `→ check:` line is allowed — `agents/.agents/skills/plan/SKILL.md:82` → fixed (Let a configuration-only plan start with its check; Run a configuration-only check after the change)
- [ ] Important: Single and split mode demand a failing acceptance test and a red suite per criterion, which a `→ check:` criterion cannot give — `agents/.agents/skills/implement/SKILL.md:59` → fixed (Skip the test loop for check-only Proof lines)

## Round 4 (codex) — 2026-10-20T13:37:06Z — fd313c6b

- [ ] Important: A configuration-only plan schedules its only check before the change, which cannot prove it — `agents/.agents/skills/plan/SKILL.md:89` → fixed (Run a configuration-only check after the change)
- [ ] Important: Single and split mode still require an acceptance test for a `→ check:` criterion — `agents/.agents/skills/implement/SKILL.md:59` → fixed (Skip the test loop for check-only Proof lines)

## Round 5 (codex) — 2026-10-20T13:46:59Z — d80ee322

Nothing found. `codex review --base origin/main` reported no actionable defects. Both round 4 closures hold.

## Round 6 (claude) — 2026-10-20T14:16:39Z — d80ee322

Nothing found. Round 2, 3 and 4 closures hold: the code-review sentence is fixed; plan skill starts a check-only plan with the change and runs the check after it; implement skill limits the outer loop to Proof lines that name a test and skips the test-writer step for check-only plans. Mirror (9 runs), hotwire (28) and codex agent generation (5) tests green. All four rule lines match across mirrors. The fetch from origin failed (SSH agent refused), so the comparison used the local origin/main.
