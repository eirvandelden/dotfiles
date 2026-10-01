# Review: agreed-alias

## Round 1 — 2026-10-01T09:09Z — 5bb51cdf

No `REVIEW.md` or `REVIEW.local.md` at the repository root; used the default policy from `claude/.claude/skills/new-repo-setup/references/REVIEW.md`.

State at review: `test/approval_word_test.rb` (5 runs) and `test/herdr_worker_scripts_test.rb` (61 runs, 0 skips) green; `rubocop` on both test files clean; `shellcheck -x -S warning` on `hand-off-plan.sh` clean. No uncommitted changes.

Bugs: none found. Security: none found (prose and a quoted prompt string only; no new input handling).

Compliance: every acceptance criterion has a proving test; every test named in `## Proof` exists; no existing test was changed or removed; `docs/changes/ai-native-workflow/` is unchanged against `origin/main`. No other approval-word sites outside the planned files (grep over the repository, change folders excluded).

- intent worker waits for "accepted" or "agreed" → `test_the_intent_spec_and_plan_workers_are_told_accepted_or_agreed`
- spec worker waits for "accepted" or "agreed" → `test_the_intent_spec_and_plan_workers_are_told_accepted_or_agreed`
- plan worker waits for "accepted" or "agreed" → `test_the_intent_spec_and_plan_workers_are_told_accepted_or_agreed`, `test_the_plan_worker_is_told_to_touch_nothing_else_until_accepted_or_agreed`
- report written after the approval word → `test_the_worker_writes_its_report_after_acceptance_not_before`, `test_the_worker_writes_its_report_after_agreed_not_before`
- intent skill names "agreed"/"agree the intent", rejects "looks good"/"ok"/"sounds right" → `test_the_intent_skill_moves_on_when_agreed_or_agree_the_intent`, `test_the_intent_skill_does_not_move_on_for_looks_good_ok_or_sounds_right`
- spec skill flips to `accepted` on "agreed" → `test_the_spec_skill_flips_status_to_accepted_when_agreed`
- plan skill flips to `accepted` on "agreed" → `test_the_plan_skill_flips_status_to_accepted_when_agreed`
- `agents.md` rule 17 names "accepted" first, "agreed" as alternative → `test_the_playbook_names_accepted_first_and_agreed_as_the_alternative`
- `docs/changes/ai-native-workflow/` unchanged → verified with `git diff --quiet origin/main -- docs/changes/ai-native-workflow` (exit 0)

- [x] Nit: The red-flag line says only the literal word "accepted" or "agreed" flips the status, but `## 4. Accept` also accepts "accept the intent" and "agree the intent". The gap existed before; this change widens it to a fourth phrase. Consider "only the words listed in step 4 flip the status" — `claude/.claude/skills/intent/SKILL.md:72` → fixed (Point the intent red flag at the words in step 4)
- [x] Nit: New rule 17 bullet says a stage moves on only on "the literal word" "accepted" or "agreed", while the intent skill also accepts the phrases "accept the intent" / "agree the intent". A reader of the playbook alone gets a narrower rule than the skill applies — `agents.md:147` → fixed (Name the intent phrases in rule 17)
- [x] Nit: If `"accepted"` ever disappears from rule 17, `rule.index("\"accepted\"")` is `nil` and `assert_operator` raises `NoMethodError` instead of a readable failure; the `"agreed"` side already has a `|| flunk(...)` guard, the `"accepted"` side does not — `test/approval_word_test.rb:40` → fixed (Fail with a message when rule 17 loses "accepted")
- [x] Nit: `test_the_worker_writes_its_report_after_agreed_not_before` checks only the spec prompt. For the plan prompt the same check would pass trivially, because `role_instruction` already names "agreed" before the acceptance sentence; intent is not checked. Acceptable as is, but the test name claims more than the spec stage — `test/herdr_worker_scripts_test.rb:214` → fixed (Name the "agreed" report-order test after the spec stage it checks)

Counts: Important 0, Nit 4.
