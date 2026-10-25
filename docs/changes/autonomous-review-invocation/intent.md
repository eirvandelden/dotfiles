# Intent: Let the autonomous coordinator invoke the review skill

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-25). Type: bugfix. Delivery: autonomous. Codex review: no.

## Problem

In autonomous delivery the coordinator must run the `review` skill in auto mode (`intent/SKILL.md:192`). `review/SKILL.md` sets `disable-model-invocation: true`, so Claude refuses the Skill-tool call. Agents then stop and say only Etienne can run `/review`, and the autonomous flow stalls before delivery.

## Proposed outcome

A coordinator in autonomous delivery runs `/review` itself, with no human step. Only `/finish` stays a human command in the sense that no agent merges.

## Affected users and systems

- Claude coordinators and stage panes in personal autonomous delivery.
- `agents/.agents/skills/review`, its parity test, and any doc that mentions the flag.
- Codex coordinators, who read the skill file and are not blocked today.

## Constraints

- No permissions needed: no gems, system tools, destructive migrations or deploy files.
- `deliver` and `finish` keep their flags. `deliver` opens the draft PR; `finish` auto mode stops at `ship --no-merge`; agents never merge.
- `test/skill_parity_test.rb` requires the Claude flag and the Codex flag to agree, except for skills listed in `AGENT_INVOKED`.

## In scope

- Remove `disable-model-invocation: true` from `review/SKILL.md`.
- Keep `allow_implicit_invocation: false` in `review/agents/openai.yaml`, and add `review` to `AGENT_INVOKED` in the parity test, as `worktree-first` already does.
- Update any text that says the review skill is model-disabled.

## Out of scope

- `deliver` and `finish` flags and behaviour.
- The review skill's backends and auto-mode steps.
- Reviewer agent behaviour.

## Acceptance criteria

- A Claude coordinator in autonomous delivery invokes the `review` skill through the Skill tool without a refusal.
- The parity test passes with `review` model-invocable on Claude and denied implicit invocation on Codex.
- `deliver` and `finish` stay refused for the Skill tool.
- The merge stays a human step: no skill in autonomous mode runs a merge.

## Flagged concerns

With the flag gone, Claude may start `/review` on its own in step-by-step mode. Chosen side: accept it. The skill is report-only and its description already says when to use it.

## Decisions

- Drop the flag instead of rewording `intent/SKILL.md:192` — Etienne chose this over the recommended reword.
- Keep the Codex `allow_implicit_invocation: false` — default, same as `worktree-first`; Codex coordinators already follow the file explicitly.

## Open questions

None.
