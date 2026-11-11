# Plan: Restow on main pull

From `intent.md` (2026-11-11). Status: accepted.

## Design

Not affected: configuration only, no objects.

## Design decisions

Reuse `install/tasks/50_stow_all.sh` for its `stow --restow -t "$HOME"` handling. Unset `GIT_DIR` as the other hooks do.

## Integration points

`lefthook-local.yml` merges with the shared `lefthook.yml`; existing `post-merge` and `post-rewrite` commands stay.

## Files that change

`lefthook-local.yml` — add a `restow` command under `post-merge` and `post-rewrite`.

## Order of work

1. Add the two commands.
2. Run the checks below.

## Risks

A restow conflict fails the hook after the pull; the pull itself is already done.

## Proof

- A pull on `main` restows, other branches do not → check: `yamllint lefthook-local.yml`, then `lefthook run post-merge` on `main` and on a feature branch.

Domain skills applied: None.
