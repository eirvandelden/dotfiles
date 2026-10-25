# Intent: Unlock personal, work or both secrets

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature. Delivery: step-by-step.

## Problem

`unlock` always reads every secret from both 1Password accounts, personal and work. Etienne rarely needs both in one shell. Each unlock costs extra 1Password reads and puts unneeded credentials in the environment.

## Proposed outcome

`unlock` and `secrets` load only the scope Etienne picks: personal, work or both. A bare call on a terminal shows a menu with the options cancel, personal, work and both, in that order. `unlock personal` and `unlock work` skip the menu.

## Affected users and systems

- Etienne, in interactive zsh shells.
- `zsh/.config/zsh/functions/secrets.zsh`: `secrets()` and `unlock()`.
- `test/secrets_loader_test.rb`.
- Scripts or docs that call bare `unlock` or `secrets` (to be found in the plan).

## Constraints

- The menu text goes to stderr, so `eval "$(secrets)"` still receives only export lines.
- The repository names no employer: the work account still comes from `SECRETS_WORK_OP_ACCOUNT`.
- A failed unlock still changes neither the environment nor PATH.
- The codex shim and `UNLOCKED_BIN` handling stay as they are.

## In scope

- Scope argument `personal`, `work` or `both` on `unlock` and `secrets`.
- Menu on a bare call with a terminal on stdin, for both functions.
- Usage error on a bare call without a terminal.
- Tests, and updating the usage comments in the file.

## Out of scope

- Short aliases such as `unlockp`.
- Changes to the mapping files, the 1Password accounts or the codex shim.
- Per-secret selection.

## Acceptance criteria

- `unlock personal` exports the personal secrets, reads nothing from the work account and does not show the menu.
- `unlock work` exports the work secrets, reads nothing from the personal account and does not show the menu.
- `unlock both` exports both sets, as bare `unlock` did before.
- `unlock` on a terminal lists "cancel, personal, work, both" in that order and loads the chosen scope.
- Choosing cancel changes neither the environment nor PATH.
- `unlock` without a terminal prints a usage line naming personal, work and both, and applies nothing.
- `eval "$(secrets)"` on a terminal shows the menu on stderr and evals only exports.
- `unlock work` with `SECRETS_WORK_OP_ACCOUNT` unset fails with a message that names the variable.
- `unlock bogus` fails with the usage line and applies nothing.

## Decisions

- Aliases are not needed; `unlock personal` and `unlock work` are enough — Etienne's words.
- The menu order is cancel, personal, work, both — Etienne's request.
- Bare `unlock` without a terminal fails with usage — chosen over loading both; no reason given.
- Bare `secrets` shows the same menu as `unlock` — chosen over loading both; no reason given.

## Open questions

None.
