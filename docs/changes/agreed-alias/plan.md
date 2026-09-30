# Plan: "agreed" as an alternative approval word

From `intent.md` and `spec.md` (2026-09-30). Status: accepted.

## Context

To move a change to its next stage (intent, spec, plan), Etienne must type the literal word "accepted". Etienne wants "agreed" to work the same way. "Accepted" keeps working, stays the main word in the documentation, and the `Status: accepted` line in every artifact stays as it is. Vague replies ("looks good", "ok", "sounds right") still do not move a stage on.

## Files that change

- `herdr/.config/herdr/scripts/hand-off-plan.sh` — `accepted_then_push` (used by the intent, spec and plan workers) and the plan `role_instruction` say `the literal word "accepted" or "agreed"`. The comments at lines 7 and 146 stay: they describe the status, not the word.
- `test/herdr_worker_scripts_test.rb` — new assertions that the intent, spec and plan prompts name `"accepted" or "agreed"`, and that the report is written after the approval word. Existing assertions stay unchanged and must still pass.
- `claude/.claude/skills/intent/SKILL.md` — pane backend paragraph (line 38: `says "accepted" or "agreed"`), red-flag line (line 72: `only the literal word "accepted" or "agreed" flips the status`), `## 4. Accept` (line 110: `On the words "accepted", "agreed", "accept the intent" or "agree the intent" (not "looks good", not "ok")`).
- `claude/.claude/skills/spec/SKILL.md` — pane backend paragraph (line 28) and `### 4. Accept` (line 78: `on the user's literal word "accepted" or "agreed", flip it`).
- `claude/.claude/skills/plan/SKILL.md` — pane backend paragraphs (lines 23 and 27) and step 7 (line 72: `` `Status: accepted` only on the user's literal word "accepted" or "agreed" — never on "looks fine" or "ok". On that word, ...``).
- `agents.md` rule 17 — one new bullet: `A stage moves on only when Etienne types the literal word "accepted" (or the alternative, "agreed"); vague replies such as "looks good" or "ok" do not.` `CLAUDE.md`, `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md` are symlinks to `agents.md` and are not edited. `AGENTS.md` is the same file on this case-insensitive file system.
- `test/approval_word_test.rb` (new) — reads the three skills and `agents.md` and asserts the wording from the acceptance criteria. Style follows `test/markdown_rule_mirror_test.rb` (plain Minitest, `REPO_ROOT`, `File.read`).

Codex reads the same skills through symlinks in `agents/.agents/skills/`, so no Codex copy changes.

## Order of work

1. Write the acceptance test: in `test/herdr_worker_scripts_test.rb`, `test_the_intent_spec_and_plan_workers_are_told_accepted_or_agreed`. Run `ruby -Itest test/herdr_worker_scripts_test.rb -n /accepted_or_agreed/`, watch it fail because the prompt has no `"agreed"`.
2. Change `accepted_then_push` in `hand-off-plan.sh`. Run the test, green.
3. Add `test_the_plan_worker_is_told_to_touch_nothing_else_until_accepted_or_agreed`; watch it fail; change the plan `role_instruction`; green.
4. `test_the_worker_writes_its_report_after_agreed_not_before` (index of `"agreed"` < index of `write what spec.md decided`) is written in step 1 with the acceptance test, so it fails there too (no `"agreed"` in the prompt) and turns green in step 2.
5. Commit: script and prompt tests.
6. Write `test/approval_word_test.rb` with the intent-skill tests; watch them fail; edit `intent/SKILL.md`; green. Commit.
7. Same for the spec skill. Commit.
8. Same for the plan skill. Commit.
9. Same for `agents.md` rule 17. Commit.
10. Run the full herdr test file and every file in `test/` the way CI does (`for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`), `shellcheck -x -S warning herdr/.config/herdr/scripts/hand-off-plan.sh`, `rubocop` on the two test files, `cspell` on every changed file.
11. Verify requirement 7: `git diff --quiet main -- docs/changes/ai-native-workflow` exits 0.
12. Re-read the full diff against `main`; revert any hunk the task did not ask for.

## Risks

- `assert_told_accepted_then_committed_then_pushed` finds the first `/accepted/i`. Keeping `"accepted"` before `"agreed"` keeps that order check valid. Putting `"agreed"` first would not break it, but the spec fixes the order.
- The plan skill's step 7 and the spec skill's Accept section say "On that word" after naming the word. With two words it must read "On either word", or a reader may take only the first. Wording to use: `On either word`.
- A word test that only checks `"agreed"` somewhere in a skill passes on the pane backend paragraph alone, and misses the Accept section. The skill tests therefore check the Accept section text (the paragraph that flips the status), found by its heading.
- Rejected: a shared approval-word variable or list read by the skills. Skills are prose read by agents; one extra quoted word in each place is simpler.
- Rejected: changing `Status: accepted` or the `Accept` headings. Tools and tests read them (spec design decision).

## Out of scope

- The `implement` skill (no approval word).
- `claude/.claude/core-values.yml` (does not mention the word).
- `docs/changes/ai-native-workflow/` and other past change folders.
- The comments in `hand-off-plan.sh` that say "once accepted" and "no accepted status line": they describe the status.

## Proof

- The intent worker's prompt tells it to wait for "accepted" or "agreed" before it commits and pushes → `test/herdr_worker_scripts_test.rb` `test_the_intent_spec_and_plan_workers_are_told_accepted_or_agreed`
- The spec worker's prompt tells it to wait for "accepted" or "agreed" before it commits and pushes → `test/herdr_worker_scripts_test.rb` `test_the_intent_spec_and_plan_workers_are_told_accepted_or_agreed`
- The plan worker's prompt tells it to wait for "accepted" or "agreed" before it writes its report and pushes → `test/herdr_worker_scripts_test.rb` `test_the_intent_spec_and_plan_workers_are_told_accepted_or_agreed`, `test_the_plan_worker_is_told_to_touch_nothing_else_until_accepted_or_agreed`
- The worker's report is still written after the approval word → `test/herdr_worker_scripts_test.rb` `test_the_worker_writes_its_report_after_acceptance_not_before` (existing), `test_the_worker_writes_its_report_after_agreed_not_before`
- The `intent` skill says "agreed" and "agree the intent" move the stage on, and "looks good", "ok" and "sounds right" do not → `test/approval_word_test.rb` `test_the_intent_skill_moves_on_when_agreed_or_agree_the_intent`, `test_the_intent_skill_does_not_move_on_for_looks_good_ok_or_sounds_right`
- The `spec` skill says "agreed" moves the stage on, and the `Status:` line becomes `accepted` → `test/approval_word_test.rb` `test_the_spec_skill_flips_status_to_accepted_when_agreed`
- The `plan` skill says "agreed" moves the stage on, and the `Status:` line becomes `accepted` → `test/approval_word_test.rb` `test_the_plan_skill_flips_status_to_accepted_when_agreed`
- `agents.md` rule 17 names "accepted" as the main word and "agreed" as the alternative → `test/approval_word_test.rb` `test_the_playbook_names_accepted_first_and_agreed_as_the_alternative`
- `docs/changes/ai-native-workflow/` has no changes → verification command `git diff --quiet main -- docs/changes/ai-native-workflow` (step 11); not a unit test, because the answer depends on the branch, not the code.

Per changed file, the unit tests expected:
- `herdr/.config/herdr/scripts/hand-off-plan.sh`: intent, spec and plan prompts contain `"accepted" or "agreed"`; plan prompt says touch nothing else until `"accepted" or "agreed"`; `"agreed"` comes before the report instruction; existing order check (accepted, commit, push) still passes.
- `claude/.claude/skills/intent/SKILL.md`: Accept section names `"agreed"` and `"agree the intent"`; Accept section still says not `"looks good"`, not `"ok"`; red-flag line still names `"sounds right"` and now names `"agreed"`.
- `claude/.claude/skills/spec/SKILL.md`: Accept section names `"accepted" or "agreed"` and `` `accepted` `` as the status value.
- `claude/.claude/skills/plan/SKILL.md`: step 7 names `"accepted" or "agreed"` and `` `Status: accepted` ``.
- `agents.md`: rule 17 text (from `17. Plan before implementing:` up to `18.`) contains `"accepted"` before `"agreed"`.

Test setup: the herdr tests reuse the existing `worktree_creatable!`, `run_script(HAND_OFF_PLAN, ...)` and `worker_prompt(stage)` helpers. `test/approval_word_test.rb` needs no fixtures: it reads committed files from `REPO_ROOT` and slices sections by heading (`## 4. Accept`, `### 4. Accept`, the line starting `7. ` in the plan skill, `17. ` to `18. ` in `agents.md`).
