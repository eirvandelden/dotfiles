# Plan: Make the Codex review optional in autonomous delivery

From `intent.md` (2026-10-19). Status: accepted.

## Design decisions

- The choice lives in `intent.md` as a header field `Codex review: yes|no`. The intent interview asks it only when autonomous delivery is chosen. The default is `no`. A missing field means `no`.
- Auto mode in the `review` skill runs the Codex round only when the field is `yes`. The Claude round always runs.
- Delivery waits for a clean round from every enabled reviewer.
- `auto-accept` parses the intent header with fixed field names. An unknown inline field such as `Delivery: autonomous. Codex review: yes.` would turn the Delivery value into `autonomous. Codex review: yes` and refuse the plan. So `Codex review` joins the field list in `auto-accept` (three regexes). The script ignores the new field's value.
- No change to the plan critique (`codex exec -p terra`) or to non-autonomous review.

## Integration points

- `agents/.agents/skills/plan/scripts/auto-accept`: header parser.
- `agents/.agents/skills/review/SKILL.md`, `agents/.agents/skills/intent/SKILL.md`: skill text the coordinator follows.
- `agents.md` (§7a; `claude/.claude/PLAYBOOK.md` is a symlink to it).

## Files that change

- `agents/.agents/skills/plan/scripts/auto-accept` — add `Codex review` to `INTENT_FIELD`, `INTENT_SEPARATOR` and the `intent_header` `take_while`.
- `agents/.agents/skills/intent/SKILL.md` — add a Delivery-mode question 3: "Also review with Codex? (default: no)". Add `Codex review: yes|no` to the header fields. Rewrite Autonomous delivery steps 5 and 6 for "each enabled reviewer".
- `agents/.agents/skills/review/SKILL.md` — Auto mode: Claude round always; Codex round only on `Codex review: yes`. Update the intro, the repeat-until-clean sentence, the `(claude)` backend paragraph ("both model families") and the `## Codex` section line.
- `agents/.agents/skills/deliver/SKILL.md` — line 16: "a round of each reviewer" becomes "each enabled reviewer".
- `agents.md` — §7a "Independent review" line: the Claude reviewer always; the Codex CLI only on `Codex review: yes`.
- `test/autonomy_contract_test.rb` — update `test_review_auto_mode_runs_claude_and_codex_reviewers`; add the new contract tests.
- `test/auto_accept_test.rb` — add the header-field test.

## Order of work

1. Write the acceptance test for criterion 1 in `test/autonomy_contract_test.rb`. It asserts that the review Auto mode gates `codex review --base` on `Codex review: yes`. Run it and watch it fail.
2. Write the remaining contract tests and the `auto-accept` test. Watch them fail.
3. Edit `auto-accept`. Run `test/auto_accept_test.rb`.
4. Edit the `review` skill. Edit the `intent` skill. Edit the `deliver` skill. Edit `agents.md`.
5. Run the full test suite. Run the markdown and Ruby linters on the touched files.
6. Re-read the diff and revert any hunk the task does not need.

## Risks

- Contract tests prove the text exists, not that an agent obeys it (same limit as today).
- A missing `Codex review` field defaults to `no`. An old autonomous intent therefore loses its Codex round. This is the requested default.
- Rejected: a separate flag file or environment variable. Rejected because `intent.md` is already the one record of the delivery choice.
- Rejected: dropping Codex entirely. Etienne wants the option kept.

## Proof

- With autonomous delivery and no Codex opt-in, review runs the Claude reviewer only → `test/autonomy_contract_test.rb` `test_review_auto_mode_skips_codex_unless_the_intent_opts_in`
- With `Codex review: yes`, review runs the Codex round first, then the Claude round → `test/autonomy_contract_test.rb` `test_review_auto_mode_runs_codex_first_when_the_intent_opts_in`
- The interview offers the Codex choice only with autonomous delivery, default no → `test/autonomy_contract_test.rb` `test_intent_offers_codex_review_only_for_autonomous_delivery_defaulting_to_no`
- Delivery proceeds once every enabled reviewer is clean → `test/autonomy_contract_test.rb` `test_autonomous_delivery_waits_for_each_enabled_reviewer`

Per changed file:
- `auto-accept`: `accepts_an_intent_that_records_codex_review_inline`, `accepts_an_intent_with_codex_review_on_its_own_line`.
- `agents.md`: `test_playbook_names_codex_as_an_opt_in_reviewer`.

Test setup: contract tests read skill text. The `auto-accept` tests reuse the existing `write_intent` helper in `test/auto_accept_test.rb`. No fakes needed.

---
Domain skills applied: None.
