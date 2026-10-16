# Intent: The no-fixme hook skips vendored skill references

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-16). Type: bugfix. Delivery: autonomous.

## Problem

PR #208 moved the vendored skills to `agents/.agents/skills/`. Two vendored reference documents contain the fix-me marker as upstream prose: `37signals-style/references/development-philosophy.md:89` and `rails-guides/references/command_line.md:1077`. After a rebase onto `main`, these files are in a branch's push range, so lefthook's pre-push `no-fixme` check refuses the push. PR #209 (glow-solunized-style) cannot push its rebase for this reason.

## Proposed outcome

The `no-fixme` checks in `lefthook.yml` (pre-commit and pre-push) skip files under `agents/.agents/skills/*/references/`. The vendored upstream text stays verbatim. A fix-me marker anywhere else is still refused.

## Affected users and systems

- Every branch of the dotfiles repository that rebases onto `main` after #208.
- `lefthook.yml` in the dotfiles repository; macOS (BSD grep) for local hooks.

## Constraints

- No `--no-verify`, no edit to the vendored documents.
- The exclusion must work with the grep that lefthook runs on macOS.
- No new dependencies. No other permissions are needed.
- The change's own files must not spell the marker literally, or the hook refuses them; tests build it from parts.

## In scope

- An exclude for `agents/.agents/skills/*/references/` in both `no-fixme` checks in `lefthook.yml`.
- A test that proves the exclusion and proves a fix-me marker elsewhere is still refused.
- The change artifacts.

## Out of scope

- The `no-nocommit` checks and every other hook.
- Changes to vendored skill files.
- Rebasing PR #209; that follows after this change merges.

## Acceptance criteria

- A pushed branch that contains `rails-guides/references/command_line.md` with its fix-me marker passes the `no-fixme` check.
- A pushed or committed file outside the vendored references that contains the fix-me marker is still refused.
- The pull request's `Dotfiles tests` CI run is green.

## Open questions

None.
