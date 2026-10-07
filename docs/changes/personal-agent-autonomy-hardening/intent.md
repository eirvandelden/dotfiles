# Intent: Harden autonomous delivery for personal projects

Author: Etienne van Delden. Status: accepted (2026-10-01). Type: feature.

## Problem

PR #182 implements the accepted personal-autonomy workflow. Final review finds gaps in metadata acceptance, independent review and finishing. Those gaps can grant unintended autonomy or add another human gate.

## Proposed outcome

Autonomy requires an accepted intent with an explicit delivery choice in its metadata. Examples in the document never grant that choice. Step-by-step personal changes retain their approval gates.

A Codex coordinator obtains separate Claude and Codex reviews. Personal autonomous delivery captures the PR body without another approval. Etienne retains the final merge decision.

This follow-up closes final-review findings within the original accepted outcome. It produces a verified PR with regression evidence. It does not introduce another product feature.

## Affected users and systems

Etienne's public personal workflow guidance for Claude Code and Codex. The affected parts are intent metadata, review routing and finish eligibility.

## Constraints

- Preserve the accepted personal-only scope and every existing permission boundary.
- Keep work projects and step-by-step approval rules.
- Keep meaningful tests, linting and independent review. Resolve findings without weakening checks.
- Run AI through local CLIs. Do not add GitHub-side agents, dependencies, deployment or system changes.
- Keep the user’s final merge decision. Do not merge or post GitHub comments.
- Do not activate dotfiles or run Stow.
- The `journal_administration` trial follows merge and activation; it is outside this follow-up.

## Acceptance criteria

- Only accepted intent metadata can grant autonomous plan acceptance; quoted or body examples cannot.
- Codex coordination outside herdr obtains a read-only Claude round and a separate Codex round.
- Finish auto mode requires an accepted personal autonomous intent and skips its actual body-confirmation step.
- Step-by-step and work changes retain their gates; the user retains every merge decision.
- The published title, implementation and proof describe only this follow-up.

## Open questions

None.
