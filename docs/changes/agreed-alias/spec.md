# Spec: "agreed" as an alternative approval word

From `intent.md` (2026-09-30). Status: accepted.

## Flagged concerns

None. The skills, the herdr prompts and `agents.md` all name the literal word "accepted"; every one of them changes together, so no policy is left in conflict.

## Requirements

1. The `intent`, `spec` and `plan` skills move a stage on when Etienne types "agreed" as well as "accepted".
2. The `intent` skill also moves on when Etienne types "agree the intent", as it does for "accept the intent".
3. Vague replies ("looks good", "ok", "sounds right", "sounds fine") still do not move a stage on.
4. The `Status:` line in `intent.md`, `spec.md` and `plan.md` stays `Status: accepted`, whichever word Etienne typed.
5. `hand-off-plan.sh` tells the intent, spec and plan workers to wait for "accepted" or "agreed".
6. The documentation keeps "accepted" as the main word and names "agreed" as the alternative, once, in `agents.md` rule 17.
7. `docs/changes/ai-native-workflow/` and other past change folders stay unchanged.

## Design decisions

- Only the approval trigger changes. Skill names, the `Accept` section headings, the `Status: accepted` value and the phrase "accepted plan" stay, because tools and tests read them.
- In skills and worker prompts, write `"accepted"` first and `"agreed"` second (`the literal word "accepted" or "agreed"`), so the existing reading order and the test that looks for `"accepted"` in the prompt keep working.
- `agents.md` rule 17 carries the one documentation sentence. Its symlinked or copied forms (`CLAUDE.md`, `PLAYBOOK.md`) are not edited by hand. `core-values.yml` does not mention the word, so it stays.
- The `implement` skill has no approval word, so it does not change.

## Integration points

- `claude/.claude/skills/intent/SKILL.md` — pane backend paragraph, the "sounds right" pitfall line, and `## 4. Accept`.
- `claude/.claude/skills/spec/SKILL.md` — pane backend paragraph and `### 4. Accept`.
- `claude/.claude/skills/plan/SKILL.md` — pane backend paragraph and step 7.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` — `accepted_then_push` and the plan role instruction.
- `test/herdr_worker_scripts_test.rb` — prompt assertions for the intent, spec and plan workers.
- `agents.md` rule 17.

## Acceptance criteria

- The intent worker's prompt tells it to wait for the word "accepted" or "agreed" before it commits and pushes.
- The spec worker's prompt tells it to wait for the word "accepted" or "agreed" before it commits and pushes.
- The plan worker's prompt tells it to wait for the word "accepted" or "agreed" before it writes its report and pushes.
- The worker's report is still written after the approval word, not before it.
- The `intent` skill says "agreed" and "agree the intent" move the stage on, and that "looks good", "ok" and "sounds right" do not.
- The `spec` skill says "agreed" moves the stage on, and the `Status:` line becomes `accepted`.
- The `plan` skill says "agreed" moves the stage on, and the `Status:` line becomes `accepted`.
- `agents.md` rule 17 names "accepted" as the main word and "agreed" as the alternative.
- `docs/changes/ai-native-workflow/` has no changes in the diff.

---
Domain skills applied: None.
