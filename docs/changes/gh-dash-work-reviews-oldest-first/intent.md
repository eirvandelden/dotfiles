# Intent: Sort gh-dash Work reviews oldest update first

Author: Etienne van Delden. Status: accepted (2026-10-20). Type: chore.

## Problem

The `Work reviews` board in gh-dash lists the most recently updated PRs first, so review requests that have waited longest sink to the bottom.

## Proposed outcome

The `Work reviews` board lists the PR that changed longest ago first.

## Affected users and systems

Etienne, in gh-dash. The config lives in the `github` stow package: `github/.config/gh-dash/config.yml`.

## Constraints

gh-dash has no sort setting. The section `filters` string takes GitHub search qualifiers, so the sort goes there as `sort:updated-asc`.

## In scope

- The `Work reviews` section filter.
- The matching test expectation.

## Out of scope

- Every other gh-dash section.
- Stowing the config into `~/.config`.

## Acceptance criteria

- The `Work reviews` filters contain `sort:updated-asc` and keep every existing token.
- Every other section keeps its filters.

## Decisions

- Sort by `updated-asc`, not `created-asc` — "oldest changed comes first" means last activity, not creation date.

## Open questions

None.
