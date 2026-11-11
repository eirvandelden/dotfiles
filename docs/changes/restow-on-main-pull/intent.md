# Intent: Restow on main pull

Author: Etienne van Delden. Status: accepted. Type: chore.

## Problem

After `git pull` on `main` in the dotfiles repo, the stow links can be stale. Etienne restows by hand.

## Proposed outcome

A pull on `main` in this repo restows every configured package, with no manual step.

## Constraints

Only this repo gets the hook. The shared `lefthook.yml` stays untouched.

## In scope

`post-merge` (plain pull) and `post-rewrite` (`pull --rebase`) commands in `lefthook-local.yml`, active only on `main`.

## Out of scope

Hooks for other branches. Changes to the shared `lefthook.yml`. Changes to the stow scripts.

## Acceptance criteria

- A pull on `main` runs `install/tasks/50_stow_all.sh`.
- A pull on any other branch does not.

## Decisions

Place the hook in `lefthook-local.yml`. Cover `pull --rebase` too. Accepted by "agreed".
