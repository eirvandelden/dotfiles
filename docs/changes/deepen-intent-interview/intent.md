# Intent: Deepen the intent interview

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-19). Type: feature. Delivery: autonomous.

## Problem

The `intent` interview asks too few questions. It reads only the GitHub issue, then walks a fixed list of seven topics. It does not read the repository first, probe edge cases or failure modes, check whether the request is several changes in one, or confirm the draft with the user before asking for "accepted". Ambiguity survives into `plan`.

## Proposed outcome

The interview builds a clearer picture before the intent is accepted. It reads what the repository already answers, asks only what it cannot, probes for edge cases, and records the user's decisions so later stages can check them. The depth scales with the change type, so a clear bug fix still takes 1–3 questions.

## Affected users and systems

- Etienne, in every `intent` session.
- `agents/.agents/skills/intent/SKILL.md`, shared with Codex through its `Codex` section.
- `agents/.agents/skills/plan/SKILL.md`, which consumes `intent.md`.
- `claude/.claude/core-values.yml`, which a hook reinjects every session.
- `claude/.claude/PLAYBOOK.md` §7, rule 17.

## Constraints

- Keep the problem-before-solution rule: intent never proposes a solution.
- Keep the short interview for clear bug fixes (1–3 questions, default the rest).
- Keep the literal "accepted" gate unchanged.
- Editing a rule mirrored in `core-values.yml` means editing both (playbook §7).
- Markdown prose uses one line per paragraph and list item.
- No new dependencies, migrations or deploy files. No extra permissions needed.

## In scope

- Explore context first: read relevant code, docs, recent commits and current behaviour before the first question. Ask only what the repository cannot answer.
- A scope check up front: flag a request that bundles several independent changes and split it before refining details.
- A probing checklist beyond the seven topics: edge cases, failure modes, current behaviour, existing patterns, "what happens when X".
- Depth scaled by `Type`: `bugfix` and `chore` keep 1–3 questions; `feature` and `refactor` probe fully.
- Read-back: confirm the draft section by section before asking for "accepted".
- Self-review before acceptance: placeholder, contradiction, scope and ambiguity scan.
- A `## Decisions` section in the `intent.md` template: each explicit user decision, verbatim or near-verbatim, with a one-line rationale.
- Teach the `plan` skill to check its steps against `## Decisions` for fidelity.
- Refresh the vendored-from comment in the intent skill.
- Mirror the new rules in `core-values.yml` and add a note to playbook §7 rule 17.

## Out of scope

- Proposing 2–3 solution approaches (that stays in `plan`).
- The visual companion and the hand-off to `writing-plans`.
- The pane backend, delivery-mode flow and autonomous delivery logic in intent.
- Changes to `implement`, `review` or `deliver`.
- A reviewer subagent for the intent.

## Acceptance criteria

- Starting an interview on a feature, the skill reads relevant repository files before its first question.
- A request that bundles two independent changes is flagged and split before details are refined.
- A feature interview asks about edge cases and failure modes, not only the seven topics.
- A clear bug fix still ends after 1–3 questions.
- Before asking for "accepted", the skill reads the draft back section by section and corrects it.
- A written `intent.md` has a `## Decisions` section listing each explicit decision with its rationale.
- The `plan` skill reports any plan step that contradicts a recorded decision.
- The "accepted" gate still refuses an intent with open questions, empty criteria or an unresolved concern.
- `core-values.yml` and playbook rule 17 name the deeper interview, and no mirrored rule contradicts the skill.

## Flagged concerns

Deeper probing conflicts with the short interview for clear bug fixes. Chosen side: depth scales by `Type`, so bug fixes and chores stay short and features and refactors probe fully.

## Open questions

None.
