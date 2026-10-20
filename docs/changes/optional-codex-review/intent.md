# Intent: Make the Codex review optional in autonomous delivery

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: step-by-step.

## Problem

Autonomous delivery always runs two reviewers, the Claude `reviewer` agent and `codex review --base`.
The second reviewer costs extra tokens on every change, and Etienne cannot opt out.

## Proposed outcome

Autonomous review runs the Claude reviewer only.
Etienne can choose to add Codex as an extra reviewer, per change.

## Affected users and systems

Etienne, as the user of autonomous delivery on personal repositories.
The `intent`, `review` and `deliver` skills, playbook §7a, and the contract tests that pin their text.

## Constraints

- The choice is asked during the intent interview, in the Delivery mode step, and defaults to no.
- The answer is recorded in `intent.md` as `Codex review: yes` or `Codex review: no`.
- No new dependencies, no permissions needed.

## In scope

- Ask "Also review with Codex?" when autonomous delivery is chosen, and record the answer.
- Auto mode in the `review` skill runs the Codex round only when `Codex review: yes`.
- The intent skill's Autonomous delivery steps 5 and 6 require a clean round from each enabled reviewer.
- Update playbook §7a and the contract tests to match.

## Out of scope

- Non-autonomous review.
- The plan critique (`codex exec -p terra`) and the other §7a gates.
- A Codex coordinator still runs the Claude round through the read-only `claude -p` backend.

## Acceptance criteria

- With autonomous delivery and no Codex opt-in, review runs the Claude reviewer only and never calls `codex review`.
- With `Codex review: yes`, review runs the Codex round first, then the Claude round, as today.
- The intent interview offers the Codex choice only when autonomous delivery is chosen, with "no" as the default.
- Delivery proceeds once every enabled reviewer leaves no open finding.

## Open questions

None.
