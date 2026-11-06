# Intent: Consolidate the live Rex init.lua into the repo

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

`install.sh` cannot stow the `rex` package. The file `~/.config/rex/init.lua` exists as a plain file, so stow refuses to link `rex/.config/rex/init.lua` over it. The live file and the repo file have drifted apart.

## Proposed outcome

The repo file is the only Rex `init.lua`. `install.sh` stows `rex` without conflicts. The live file's settings that still matter are in the repo file.

## Affected users and systems

Etienne's Rex setup, the `rex` stow package, `install.sh`.

## Constraints

- Herdr owns `ctrl+s` as its prefix, so Rex must not bind `ctrl+s` chords.
- The live file is outside the repo. Claude moves it to the trash with `trash`, never `rm`, after the repo file is final.
- No dependency, deploy file or database change is needed.

## In scope

- Comment out the six `ctrl+s` chords and the `ctrl+s>o`, `ctrl+s>f`, `ctrl+s>shift+f`, `ctrl+s>g` and `ctrl+s>shift+g` binds in `rex/.config/rex/init.lua`, with a note that herdr owns `ctrl+s`.
- Keep the `require` lines and every non-`ctrl+s` bind from the repo file.
- Add `ctrl+up` and `ctrl+down` binds (`client.prompt.previous` and `client.prompt.next`) from the live file.
- Trash `~/.config/rex/init.lua`, then check that `stow -n -v rex -t "$HOME"` reports no conflict.

## Out of scope

- Rebinding the switcher, project, viewer and lazygit actions to other keys.
- The other files in `rex/.config/rex/`.
- Running `stow` or `install.sh` for real: Etienne does that.

## Acceptance criteria

- `stow -n -v rex -t "$HOME"` reports no conflict for `.config/rex/init.lua`.
- The repo `init.lua` has no active `ctrl+s` bind.
- Pressing `ctrl+up` in Rex moves to the previous prompt, and `ctrl+down` to the next.
- Pressing `ctrl+s` reaches herdr unchanged.

## Decisions

- Comment out the `ctrl+s` chords and keep the rest of the repo file — herdr must keep `ctrl+s`; the repo file's other binds stay.
- Claude trashes the live file — Etienne chose this over doing it by hand.

## Open questions

None.
