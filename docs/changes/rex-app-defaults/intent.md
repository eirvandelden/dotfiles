# Intent: Rex app defaults in the install

Author: Etienne van Delden. Status: accepted (2026-11-05). Type: chore. Delivery: step-by-step.

## Problem

Rex shows herdr's pane background grey-white and darkens herdr's faint sidebar text, so it differs from Ghostty. Two Rex app defaults cause it. Etienne set both by hand. No dotfiles file records them, so a fresh machine loses them.

## Proposed outcome

Running `./install.sh` on macOS sets both Rex defaults, with no manual step.

## Affected users and systems

Etienne's macOS machines. The `com.superlogical.rex` defaults domain. `install.sh` and `install/tasks/`.

## Constraints

- A running Rex overwrites its defaults on exit, so the step must not write while Rex runs.
- The step is idempotent and macOS only, like `51_configure_glow_style.sh`.
- The PR targets `rex-agent-switcher`, not `main`.

## In scope

- `Workspace.interfaceStyle` = `useTheme`.
- `Workspace.terminalImproveTextContrast` = `false`.
- A new install task and its wiring in `install.sh`.

## Out of scope

- Darkening herdr's `overlay0` token.
- Other Rex settings. Rex's custom themes.

## Acceptance criteria

- On macOS, with Rex not running, the task writes both keys with the values above.
- A second run writes nothing.
- With Rex running, the task warns and writes nothing.
- Outside macOS, the task skips.
- `install.sh` runs the task after the glow step.

## Decisions

- The task lives in `install/tasks/`, not in the `rex` stow package and not in `install/macos.sh`, which `install.sh` never runs.
- Agreed in chat on 2026-11-05: "agreed" on the plan that held these terms.
