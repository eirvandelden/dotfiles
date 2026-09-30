# Intent: "agreed" as an alternative approval word

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

To move a change from one stage to the next (intent, spec, plan, implement), Etienne must type the literal word "accepted". Etienne does not like that word. Any other reply leaves the stage where it is.

## Proposed outcome

Etienne can type "agreed" wherever "accepted" works today, and the stage moves on the same way. "Agree the intent" works next to "accept the intent". "Accepted" keeps working. The status line in each document stays `Status: accepted`, and the documentation keeps "accepted" as the main word, with "agreed" named as the alternative.

## Affected users and systems

- Etienne, in every Claude and Codex session that runs the `intent`, `spec` and `plan` skills.
- The herdr stage panes: `hand-off-plan.sh` tells each pane which word to wait for.

## Constraints

- Vague replies ("looks good", "ok", "sounds right") still do not move a stage on.
- No change to the `Status:` value, so tools and tests that read `Status: accepted` stay unchanged.
- Past change folders (`docs/changes/ai-native-workflow/`) stay as they are.

## Open questions

None.
