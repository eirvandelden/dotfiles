# Intent: Agent worktrees end up outside `.worktrees/`

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix.

## Problem

Agents create worktrees outside `<main checkout>/.worktrees/`. The rule (`WORKTREES.md`, playbook §7 rule 7) says every new task gets `.worktrees/<name>`. The merged-worktree sweep in `worktree-create` only looks in `.worktrees/`, so the stray worktrees are never cleaned up. Seen in a work repository: `.claude/worktrees/<name>` (source: `docs/handoffs/2026-10-01-worktrees-outside-dot-worktrees.md`).

Three causes:

- `worktree-first` skips whenever the session is inside any linked worktree. A new task started from inside another task's worktree gets no worktree of its own.
- `worktree-create` takes its root from the current worktree's toplevel. Run from inside a linked worktree, it would likely nest `.worktrees/` inside that worktree, not the main checkout (not yet verified).
- Nothing stops an agent from typing its own `git worktree add <any path>`. The agent did this twice in one session.

## Proposed outcome

- A new task started from inside any worktree (`.worktrees/foo`, `.claude/worktrees/foo`) gets `<main checkout>/.worktrees/<new-name>`.
- `worktree-first` invoked inside `.worktrees/<name>` for the task named `<name>` still skips.
- An agent's hand-typed `git worktree add` to a path outside `<main checkout>/.worktrees/` is blocked, in Claude Code and in Codex, with a message that names `worktree-first`. `worktree-create <name>` still works.
- The written rules say: never type `git worktree add` yourself; use `worktree-create`.

## Affected users and systems

- Etienne, in every repository where Claude Code or Codex agents write code.
- `claude/.claude/skills/worktree-first/SKILL.md` (shared with Codex through `agents/.agents/skills/worktree-first`).
- `git/.config/git/worktree-tools/worktree-create` and its tests.
- Claude Code `PreToolUse` hooks (`claude/.claude/hooks/`) and the Codex equivalent.
- `WORKTREES.md`, `core-values.yml` (mirrored rules).

## Constraints

- Claude/Codex parity: one shared rule, adapters only where formats differ.
- The guard must not block `worktree-create` itself.
- Bugfix: each cause gets a failing test before its fix.
- Out of scope: worktrees made by `claude --worktree` (always `.claude/worktrees/`); the sweep is not taught to clean those. The existing stray worktree in the work repository is removed by hand after its PR merges.

## Open questions

- Which Codex mechanism can block a shell command: `codex/.codex/rules/default.rules`, a Codex hook, or both? Settle in `spec`.
