# Intent: Remove the cspell spell checker

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

The spell checker stops commits on words that are spelled correctly: tool names, config keys, gem names. In the last 6 months, 32 commits only taught it such words, and the project dictionary now holds 266 of them. No commit shows it found a real typo. Agents write most of the prose in these repositories now, and they rarely misspell. Etienne never reads the dictionaries.

## Proposed outcome

A commit in the dotfiles repository, or in any repository that uses the dotfiles fallback hooks, is never stopped by a spell check. A new machine no longer installs or links the spell checker. CI no longer installs or runs it. No file, test, skill or doc in the dotfiles repository still refers to it, except the change folders of other changes under `docs/changes/`, which their own `finish` step removes.

## Affected users and systems

- Etienne, on every commit in the dotfiles repository and in repositories without their own `lefthook.yml` (the fallback pre-commit hook uses `dotfiles/lefthook.yml`).
- The `cspell` stow package and the `~/.config/cspell` link it creates.
- The install lists in `packages.conf` (the npm package and the stow package).
- The dotfiles CI workflow and the pre-commit hook tests.
- The skill and doc text that tells agents to use cspell or add words to its dictionary.
- The globally installed `cspell` npm package on this machine.

## Constraints

- CI workflow edit approved by Etienne on 2026-09-30.
- The `~/.config/cspell` link must not be left broken: Claude runs `stow -D -t "$HOME" cspell` from the main checkout before the PR merges (approved).
- Claude runs `npm uninstall -g cspell` after the PR merges (approved).
- The other repositories that use cspell (appkit, happiness, clocky, ddicompendium, mvpa.css, sticker-app, my-rails-template) each get their own branch, PR and one-line change chain. They are not part of this change.
- Work repositories do not use cspell and are not touched.

## Open questions

None.
