# Intent: Herdr panes form one row per change

Author: Etienne van Delden. Status: accepted (2026-10-25). Type: feature. Delivery: autonomous. Codex review: no.

## Problem

Agent panes open below and to the right in no fixed pattern. With several changes in flight, Etienne cannot tell which pane belongs to which change, or which stage it runs.

## Proposed outcome

One row of panes is one change. One column is one stage of that change. The first hand-off from a question pane opens a new row, below. Every later pane of that change opens to the right of the row, in process order.

## Affected users and systems

Etienne, with herdr. The scripts `hand-off-plan.sh`, `start-review.sh` and `open-pr-dash.sh`, their tests, the herdr README, and the `intent` and `review` skill text that names pane positions.

## Constraints

- Plan and implement run in autonomous delivery from the intent pane as coordinator. Columns must still come out in process order.
- No new dependency. No new permission needed.

## In scope

- `hand-off-plan.sh`: the `intent` stage splits down from the caller. `plan` and `implement` split right.
- A "right" split anchors on the rightmost live pane of the change, found through `stage-panes-<slug>`, not on the caller pane.
- `start-review.sh`: the reviewer pane becomes the next column of the row.
- `open-pr-dash.sh`: gh-dash becomes the last column, right of the rightmost pane of the row, instead of left of the intent pane.
- Tests, README and skill text updated to match.

## Out of scope

- Closing behaviour of stage panes (they still close after handing on).
- `worktree-pane` and `worktree-viewer` placement.
- Any herdr configuration or keybinding.

## Acceptance criteria

- Handing off `intent` from a question pane opens one pane below it.
- Handing off `plan` from the intent pane opens one pane right of the intent pane.
- Handing off `implement` while the plan pane exists opens a pane right of the plan pane.
- In autonomous delivery, the intent pane starts plan then implement: the row reads intent, plan, implement from left to right.
- Starting a review opens a pane right of the last stage pane of the change.
- Opening the PR dashboard opens a pane right of the last pane of the change.
- When the recorded rightmost pane is gone, the split falls back to the caller pane.

## Flagged concerns

Autonomous delivery has one coordinator starting every stage, so "right of the caller" would reverse the columns. Chosen side: anchor on the last live pane of the change.

## Decisions

- Direction is decided by stage: intent down, plan and implement right — simplest rule that matches the chain.
- Anchor on the last live pane of the row, not the caller — keeps process order under autonomous delivery.
- Review joins the row as the next column — one column per process step.
- gh-dash becomes the next column instead of sitting left of intent — no reason given.
- Autonomous delivery, no Codex review — chosen by Etienne.

## Open questions

None.
