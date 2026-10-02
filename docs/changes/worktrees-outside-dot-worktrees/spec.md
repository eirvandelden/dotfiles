# Spec: Agent worktrees end up outside `.worktrees/`

From `intent.md` (2026-10-01). Status: accepted.

## Flagged concerns

- Cause 2 of the intent is not a bug. `worktree-create` takes the main checkout from the first entry of `git worktree list`, never from the current toplevel. `test_creates_the_worktree_under_the_main_checkouts_worktrees_even_from_inside_a_linked_worktree` already passes. This spec adds no change for it. The bugfix rule "each cause gets a failing test first" cannot apply to a cause that does not fail.
- The guard sees only commands the agent types. `worktree-create` runs `git worktree add` as its own subprocess, so the hook never sees it. "The guard must not block `worktree-create`" holds without a special case.
- Codex hooks need a one-time manual trust step (`/hooks` in the Codex CLI). Until Etienne trusts the new hook, the Codex guard does not run. A dotfiles change cannot do this step.
- A hook that cannot run blocks nothing (same as `consent-guard.rb`). The written rule is the fallback.

## Requirements

1. `worktree-first` skips only when the session is already in `<main checkout>/.worktrees/<name>` and `<name>` is the branch name for the current task. It no longer skips in any other linked worktree.
2. `worktree-first` run from inside any other worktree (`.worktrees/foo`, `.claude/worktrees/foo`, a worktree outside the repository) creates `<main checkout>/.worktrees/<new-name>` through `worktree-create`.
3. A `PreToolUse` hook blocks a hand-typed `git worktree add` whose target path is not inside `<main checkout>/.worktrees/`. The hook exits 2. Its message names `worktree-first` and `worktree-create`.
4. The same hook script serves Claude Code and Codex. Each tool has its own registration: `claude/.claude/settings.json` and `codex/.codex/config.toml`.
5. The hook allows every other command, and every `git worktree add` whose target is inside `<main checkout>/.worktrees/`.
6. The hook resolves the target path against the command's working directory, including `git -C <dir>` and relative paths such as `../x`. It also resolves the main checkout from a linked worktree.
7. The written rules say: never type `git worktree add` yourself; use `worktree-create`. Places: `WORKTREES.md` (Claude and Codex copies), `worktree-first` skill, playbook §7 rule 7, `core-values.yml`.

## Design decisions

- **Codex mechanism: a `PreToolUse` hook, not `default.rules`.** The Codex hook documentation says exec-policy rules do not apply to hooks, and `prefix_rule` can only match a fixed command prefix. It cannot test whether a path is inside `.worktrees/`. A hook can do both and can return a custom message.
- **One script, two registrations.** `claude/.claude/hooks/worktree-guard.rb`. The Claude and Codex payloads share the fields `tool_input.command` and `cwd`, and both treat exit 2 with stderr as a block. Codex registers it as `[[hooks.PreToolUse]]` in `codex/.codex/config.toml`, matcher `^Bash$`, command `"$HOME/.claude/hooks/worktree-guard.rb"`. A Codex-only machine needs the `claude` stow package. This is the same coupling that skills already have.
- **A separate script, not an extension of `consent-guard.rb`.** The consent guard asks for consent and accepts a marker to override. This guard has no override: a worktree outside `.worktrees/` is wrong, not risky. Different policy, different file.
- **Block only targets outside `.worktrees/`.** A hand-typed `git worktree add .worktrees/x` is allowed, as the intent says. The rule text still forbids it. The guard errs towards allowing: a false block stops legitimate work, and the written rule covers the rest.
- **Main checkout from `git worktree list --porcelain`.** First `worktree` line, as `worktree-create` does. A command whose `cwd` is not in a git repository passes (the guard has nothing to compare against).
- **Cause 1 fix is in the skill, not in a script.** The skip condition becomes: current toplevel equals `<main checkout>/.worktrees/<branch>` for the branch the skill computed. The skill's own shell snippet states this check. `worktree-create` already reuses an existing worktree on the right branch, so a mistaken skip costs nothing.
- **No sweep of stray worktrees.** Out of scope per the intent.

## Integration points

- `claude/.claude/skills/worktree-first/SKILL.md` (shared with Codex through `agents/.agents/skills/worktree-first`).
- `claude/.claude/hooks/worktree-guard.rb` (new), `claude/.claude/settings.json` (new `PreToolUse` entry, matcher `Bash`).
- `codex/.codex/config.toml` (new `[[hooks.PreToolUse]]` table). Etienne runs `/hooks` once to trust it.
- `claude/.claude/WORKTREES.md`, `codex/.codex/WORKTREES.md`, `claude/.claude/PLAYBOOK.md` rule 7, `claude/.claude/core-values.yml`. `test/core_values_test.rb` guards the mirror.
- `git/.config/git/worktree-tools/worktree-create`: unchanged.
- Tests: new `test/worktree_guard_test.rb`, in the style of `test/consent_guard_test.rb`.

## Acceptance criteria

- Starting a new task from inside `.worktrees/foo` creates the worktree at `<main checkout>/.worktrees/<new-name>`, not nested in `foo`.
- Starting a new task from inside `.claude/worktrees/foo` creates the worktree at `<main checkout>/.worktrees/<new-name>`.
- Calling `worktree-first` inside `.worktrees/bar` for the task named `bar` does nothing and reuses `bar`.
- `worktree-first` no longer tells the agent to skip in "any linked worktree".
- `git worktree add ../elsewhere -b x` from the main checkout is blocked, and the message names `worktree-first`.
- `git worktree add .claude/worktrees/x -b x` is blocked.
- `git -C /path/to/repo worktree add /tmp/x -b x` is blocked.
- `git worktree add ../../x -b x` run from inside `.worktrees/foo` is blocked, because it resolves to the main checkout's parent directory.
- `git worktree add ../bar -b bar` run from inside `.worktrees/foo` is allowed, because it resolves to `<main checkout>/.worktrees/bar`.
- `git worktree add .worktrees/baz -b baz` from the main checkout is allowed.
- `git worktree list` and `git status` are allowed.
- `git worktree add` run outside a git repository is allowed.
- The Claude Code hook registration and the Codex hook registration both name the same script.
- `WORKTREES.md` (both copies), the `worktree-first` skill, playbook rule 7 and `core-values.yml` each say "never type `git worktree add` yourself; use `worktree-create`".

---
Domain skills applied: None.
