# Intent: Put the QMK ARM compiler on PATH

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

`qmk compile` for the Keyboardio Model 100 fails with `arm-none-eabi-gcc: command not found`. Homebrew installs `arm-none-eabi-gcc@8` and `arm-none-eabi-binutils` keg-only, so they are not on PATH. Every build needs a manual `export PATH=...` first.

## Proposed outcome

Every zsh shell, including the non-interactive ones editors and agents use, finds the ARM compiler, so `qmk compile` works without extra steps.

## Affected users and systems

Me, building QMK firmware in `~/Developer/keyboardio-config`. `zsh/.config/zsh/paths.zsh` on macOS, sourced from `.zshenv`.

## Constraints

- PATH changes go in `paths.zsh` only, in step 2 ("Extra PATH entries"), before `rv`, which must come after every other tool.
- Machines without these Homebrew kegs, such as Linux or a fresh Mac, must not get directories that do not exist.
- No `brew link`.

## In scope

- `$HOMEBREW_PREFIX/opt/arm-none-eabi-gcc@8/bin` and `$HOMEBREW_PREFIX/opt/arm-none-eabi-binutils/bin` on PATH when they exist.

## Out of scope

- `avr-gcc@8`: the Model 100 is ARM.
- `dos2unix` and anything else `qmk doctor` flags beyond the ARM compiler.

## Acceptance criteria

- With both directories present under `HOMEBREW_PREFIX`, a shell that sources `paths.zsh` has both on PATH.
- With the directories absent, a shell that sources `paths.zsh` has neither on PATH.
- On this Mac, a new zsh finds `arm-none-eabi-gcc` with `command -v`, and `qmk compile -kb keyboardio/model100 -km eirvandelden` succeeds without an extra `export`.

## Decisions

- Only the ARM compiler, not `avr-gcc@8` — the Model 100 is ARM.
- No `brew link` — it lives outside the dotfiles and is lost on reinstall.

## Open questions

None.
