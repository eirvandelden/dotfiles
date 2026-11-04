# Intent: Autonomous-delivery account lives in the change folder

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: step-by-step.

## Problem

The autonomous-delivery coordinator writes its account to `<git-common-dir>/herdr/deliver-<slug>.md`, inside `.git/`. Git never records it, so nobody can read back in the repository history what a change delivered.

## Proposed outcome

The account is a file in `docs/changes/<slug>/`, committed before `deliver` runs. `deliver` then removes the folder in its own commit, as for every other change artifact, and the account stays readable in git history.

## Affected users and systems

- Etienne, who reads the account after an autonomous delivery.
- The `intent` skill, "Autonomous delivery" step 7 and the paragraph below it.
- `hand-off-plan.sh`, which tells a stage pane to write and send the account path.
- Tests that pin the `Delivery done:` wording: `test/herdr_worker_scripts_test.rb`, `test/autonomy_contract_test.rb`.

## Constraints

- `deliver` needs a clean working tree and a fresh `review.md`, so the account is committed before `deliver` runs.
- The account cannot hold the PR URL or the CI result, which exist only after `deliver` and `finish`. The final message to Etienne carries them.
- One line per paragraph in markdown (playbook rule 26).
- No permissions needed: no dependency, system tool, destructive migration or deploy file.

## In scope

- Move the account's path to `docs/changes/<slug>/deliver.md`.
- Order the steps: write and commit the account, then `deliver`, then `finish`, then the final message with PR URL and CI result.
- Update the `intent` skill, `hand-off-plan.sh` wording and the tests that pin it.

## Out of scope

- Other files in `.git/herdr/` (`intent-pane-<slug>`, `stage-panes-<slug>`, review transcripts).
- `deliver`, `finish` and the consent guard behaviour.
- Non-autonomous delivery, which writes no account.

## Acceptance criteria

- An autonomous delivery commits `docs/changes/<slug>/deliver.md` before the pull request opens.
- After `deliver`, `git log -- docs/changes/<slug>/deliver.md` shows the account in the history.
- The `Delivery done:` line names the account's path inside the repository.
- The coordinator's final message to Etienne carries the PR URL and the CI result.
- No skill, script or test mentions `<git-common-dir>/herdr/deliver-<slug>.md`.

## Decisions

- The account goes in `docs/changes/<slug>/`, written before `deliver` — Etienne wants to see in git what was made.
- The account omits the PR URL and the CI result — they exist only after `deliver`; no reason given beyond keeping the account in git history.

## Open questions

None.
