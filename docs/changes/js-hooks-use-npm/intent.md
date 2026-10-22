# Intent: Run browserslist through npx --no in the shared lefthook hooks

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-21). Type: chore. Delivery: autonomous. Codex review: no

## Problem

The shared `lefthook.yml` runs the browserslist job as `npx browserslist`, in pre-commit and in pre-push. Without `--no`, npx can download browserslist from the registry when the repo has no local copy. The hook then checks `.browserslistrc` with an unpinned version, not the one in the repo's `package.json`. PR #216 already moved stylelint and eslint to `npx --no`; browserslist is the one Node job left behind.

## Proposed outcome

The browserslist job in pre-commit and pre-push runs `npx --no browserslist`. It uses only the repo's installed browserslist and never downloads one. All three Node linter jobs in the shared hooks behave the same way.

## Affected users and systems

- Etienne and agents committing or pushing in any repo that loads the shared `lefthook.yml` (personal and work repos).
- The dotfiles `lefthook.yml` and its tests in `test/lefthook_local_hooks_test.rb`.

## Constraints

- No permissions approved or needed: no dependency, system tool, migration, deploy file or CI workflow changes. Any such need becomes a stop-and-ask.
- No skipped tests and no linter disable comments (rule 14, §7a).
- Dotfiles is public: no work references in the diff.

## In scope

- `lefthook.yml`: the pre-commit and pre-push browserslist jobs run `npx --no browserslist`.
- Tests that prove both jobs run through `npx --no`, following the existing stylelint and eslint `npx --no` tests.

## Out of scope

- The `client-dependencies` yarn fallback for `yarn.lock` repos (work repos keep yarn).
- The `yarn lefthook` / `pnpm lefthook` fallbacks in the generated global git hook shims.
- The worktree-first skill text that mentions `yarn`.
- Any other hook job, and any package or Node version change.

## Acceptance criteria

- Staging a changed `.browserslistrc` and committing runs `npx --no browserslist`.
- Pushing a changed `.browserslistrc` runs `npx --no browserslist`.
- A repo without browserslist installed fails the browserslist job instead of downloading browserslist, the same way stylelint and eslint fail.
- The lefthook tests and the repo linters pass.

## Decisions

- Chore, not bugfix — a consistency follow-up to PR #216.
- A missing browserslist fails the job, like eslint — same behaviour as stylelint and eslint since PR #216.
- Autonomous delivery, no Codex review — small, clear change.

## Open questions

None.
