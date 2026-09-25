# Intent: Take the employer's details back out of the public dotfiles

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix.

## Problem

`eirvandelden/dotfiles` is a public repository. `codex/.codex/rules/default.rules` carries 17 recorded approval rules naming private repositories, an internal issue number, the bug's test filename, the work 1Password account host, and the path to the private work dotfiles repository. Codex appends to this file every time an approval is recorded, so the rules accumulate whatever a session happened to run.

This was already cleaned once — `16cc81dd` on 2026-09-08, "chore: stop naming the employer in the public dotfiles". The rules file reintroduced it on 2026-09-16, eight days before this was noticed.

## Proposed outcome

None of it is in the public repository's working tree.

## Affected users and systems

The public dotfiles repository, and Codex's approval prompts: a removed rule means Codex asks again for that command.

## Constraints

Removal only. Every one of these is a recorded one-shot from a past session, so nothing legitimate depends on them.

History is not rewritten here. That is a separate decision with different costs, and the 2026-09-08 cleanup set the precedent of scrubbing forward.

## Open questions

Whether to rewrite history, and how to stop the file re-accumulating. Both deliberately out of scope.
