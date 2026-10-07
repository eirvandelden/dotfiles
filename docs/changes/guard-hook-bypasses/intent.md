# Intent: Consent guard asks before any way of skipping the git hooks

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix. Delivery: autonomous.

## Problem

The git hooks are what keep commits and pushes off `main`. The consent guard asks for Etienne's consent before an agent skips them with `--no-verify`. Every other way of skipping them goes through without a question. Each route below defeated the main guard in a scratch repository on 2026-10-07:

- `git commit -n`, the short form of `--no-verify`.
- `LEFTHOOK=false`, and `LEFTHOOK=0` inline or exported. The global shims check only for `0`; lefthook itself treats `false` as off too.
- `LEFTHOOK_EXCLUDE=<tag or command>`, for example `LEFTHOOK_EXCLUDE=no-push-to-main`.
- `git -c core.hooksPath=…` and `GIT_CONFIG_PARAMETERS` that set `core.hooksPath`.

Three more routes skip or disarm the hooks without running them at all:

- `git config core.hooksPath …` or `--unset core.hooksPath`, which change the hooks path for every later command.
- `git commit-tree` with `git update-ref`, which build a commit and move a branch with no hook involved.
- `lefthook install` and `lefthook uninstall`, which replace or remove the global shims. On 2026-10-06 lefthook wrote its stock shims over four global hooks, and the main guard silently disappeared for repositories without their own lefthook config.

## Proposed outcome

An agent that takes any of these routes is stopped until Etienne agrees, the same way `--no-verify` is today. With consent, it re-runs the command with `I_HAVE_USER_CONSENT=1` and it goes through. Codex asks for the same routes, through the shared hook and, where a prefix rule can express the route, through `default.rules` as a second layer.

## Affected users and systems

- Agents in Claude Code and Codex, in every repository on this machine.
- `claude/.claude/hooks/consent-guard.rb`, used by Claude's PreToolUse hook and Codex's `[hooks]` table.
- `codex/.codex/rules/default.rules`.
- The guard parity test and the consent guard tests.

## Constraints

- The guard stays word-based, as its header comment intends: it checks which words are present, not what a shell will do. Every check errs towards asking.
- Quoted text is one word, so prose that mentions a route does not trigger a question.
- The hook runs on whichever Ruby is on PATH, with no gems beyond the standard library.
- Claude and Codex stay in step; the guard parity test enforces it.
- Approved permissions for autonomous delivery: none. Needing a gem, package, system tool, migration or deploy file is a stop-and-ask.

## In scope

- `git commit -n`.
- The lefthook switches `LEFTHOOK` (any value that turns lefthook off) and `LEFTHOOK_EXCLUDE`, inline or exported.
- Every way to set or unset `core.hooksPath`: `git -c`, `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_<n>`, and `git config` in any scope.
- The plumbing commands `git commit-tree` and `git update-ref`.
- `lefthook install` and `lefthook uninstall`.
- Codex `default.rules` entries for each route a prefix rule can express.

## Out of scope

- Routes hidden from the command line: script files, `sh -c "…"` or `eval` strings, edits or `chmod` of the hook files themselves.
- lefthook's own auto-sync during `lefthook run` (the uncovered case in PR #168).
- The main guard's first-commit hole on an unborn branch.
- The guard's other checks (plain `--force`, GitHub posts, deploys, the remote allowlist) keep their behaviour.
- The work repositories' lefthook setup (change `work-repos-branch-guard` in dotfiles-work).

## Acceptance criteria

- An agent's `git commit -n -m "x"` waits for Etienne's consent.
- `git push -n origin feature`, a dry run, goes through without a question.
- `LEFTHOOK=0 git commit -m "x"`, `LEFTHOOK=false git commit -m "x"` and `export LEFTHOOK=0; git commit -m "x"` each wait for consent.
- `LEFTHOOK_EXCLUDE=no-push-to-main git commit -m "x"` waits for consent.
- `git -c core.hooksPath=/dev/null commit -m "x"` waits for consent.
- A commit with `core.hooksPath` set through `GIT_CONFIG_PARAMETERS` or `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_0` waits for consent.
- `git config core.hooksPath /dev/null` and `git config --global --unset core.hooksPath` wait for consent.
- `git config --get core.hooksPath` goes through without a question.
- `git commit-tree HEAD^{tree} -p HEAD -m "x"` and `git update-ref refs/heads/main <sha>` each wait for consent.
- `lefthook install` and `lefthook uninstall` wait for consent; `lefthook dump` goes through.
- After consent, `I_HAVE_USER_CONSENT=1 git commit -n -m "x"` goes through.
- `git commit -m "explain why LEFTHOOK=0 is refused"` goes through without a question.
- Codex prompts for each new route that a prefix rule can express, and the guard parity test passes.

## Flagged concerns

- Coverage versus interruptions: plumbing and `core.hooksPath` writes have harmless uses, and each now costs a question. Chosen side: ask, as the guard's header says a false question costs a moment and a missed one costs much more.

## Open questions

None.
