# Spec: a herdr pane rooted in every new worktree

From `intent.md` (2026-09-23). Status: accepted (2026-09-23).

## Flagged concerns

- `worktree-first`'s Step 1 (sweep and create) is a shell script embedded as prose in `SKILL.md`; every agent re-types it. Adding herdr calls there would grow untested prose. This spec moves the mechanics into a tested script under `git/.config/git/worktree-tools/` and leaves the skill to call it. That changes how the skill works, not what it does; the playbook's "verify, don't assume" rule favours the tested script. Named here so the plan does not treat it as scope creep.
- `hand-off-plan.sh` starts the worker in the main checkout so the worker can branch off cleanly. Starting the worker inside a pre-created worktree changes who creates the worktree (the caller, not the worker). The worker's `worktree-first` then skips itself, as it already does inside a linked worktree, so nothing else changes for the worker.

## Requirements

1. Creating a worktree through `worktree-first` while inside herdr (`HERDR_ENV` set and `herdr` on `PATH`) opens one terminal pane in the current workspace, split from the caller's pane, whose working directory is the new worktree. The caller's pane keeps focus.
2. The new pane is labelled `<repository>/<branch>` (repository = basename of the main checkout), so the tab and pane lists show which worktree it is.
3. Outside herdr, or when any herdr command fails, worktree creation completes exactly as today and prints one warning line at most. A herdr failure never makes `worktree-first` exit non-zero.
4. When `worktree-first` sweeps a merged worktree, every pane in the current workspace whose working directory is that worktree, and whose `agent_status` is not a running agent, is closed before the worktree is removed. A pane with a running agent is left open and named in the output.
5. `hand-off-plan.sh <plan> [<worktree-name>]`: with a name, the script creates the worktree (same sweep-and-create as `worktree-first`), splits the worker pane with `--cwd` set to that worktree, labels it `<repository>/<branch>`, and tells the worker it is already in its worktree. Without a name, today's behaviour is unchanged.
6. The `implement` skill's `handoff` mode passes the change's branch name as that second argument.
7. `start-review.sh` keeps splitting with `--cwd "$PWD"`; no change beyond confirming it.
8. All herdr interaction lives in one script, `git/.config/git/worktree-tools/worktree-pane`, with two commands: `open <worktree-path>` and `close <worktree-path>`. `worktree-first`, the new `worktree-create` script and `hand-off-plan.sh` call it; nothing else calls `herdr pane` for worktrees.
9. The sweep-and-create logic becomes `git/.config/git/worktree-tools/worktree-create <name>`: prunes, fetches the default branch, sweeps merged worktrees (calling `worktree-pane close` for each, then `worktree-remove`), creates `.worktrees/<name>` off `origin/<default>`, calls `worktree-pane open`, prints the worktree path. `worktree-first` Step 1 becomes "run `worktree-create <name>`" plus the skip conditions it has today. When `.worktrees/<name>` is already a registered worktree whose branch is `<name>` (the `intent` skill creates it before handoff time), `worktree-create` does not sweep it and does not run `git worktree add` again: it prints the existing path, still calls `worktree-pane open`, exits 0, and prints one stderr line naming the reuse. A path on another branch, or a branch that exists without a worktree, keeps today's failure.
10. `claude/.claude/WORKTREES.md` states the pane behaviour in one sentence; the skill and its Codex link stay one file.

## Design decisions

- **Pane, not workspace.** Decided 2026-09-23. A workspace is a sidebar entry; nineteen were open. A pane in the current workspace gives the viewer the right root when focused and adds nothing to the sidebar.
- **Finding the pane at sweep time by working directory, not by label.** `herdr pane list` returns each pane's `cwd`, `pane_id`, `agent_status` and `workspace_id` (verified on herdr 0.9.1). Matching `cwd` to the worktree's absolute path is exact and survives a renamed pane; a label is for humans only.
- **Split direction `down`, `--no-focus`.** Same as `hand-off-plan.sh`'s worker pane (decided 2026-09-23). The caller keeps typing; the new pane is a shell, not an agent.
- **One script for herdr calls.** Testable with a stub `herdr` on `PATH` (the `test/herdr_worker_scripts_test.rb` pattern); the skill prose stays short; Codex and Claude run the same bytes.
- **Language.** Ruby with the `#!/usr/bin/env rv run ruby` shebang, like `worktree-remove` and `worktree-setup`; tests under `git/.config/git/worktree-tools/test/`, which already hold `remove_test.rb`.
- **Degrade silently.** `HERDR_ENV` unset or `herdr` missing → `worktree-pane` exits 0 without output. Any herdr error → one line to stderr, exit 0. The worktree is never the casualty of a UI convenience.
- **Running agents.** The `agent` field, not `agent_status`, decides: a pane with any `agent` value (herdr 0.9.1: `claude`, or another kind) is skipped at sweep, named on stderr, whatever its `agent_status` — `idle` is a live agent waiting for input, closing it ends the session same as `working` or `done`. A pane with `agent: null` (a plain shell) is closed regardless of `agent_status`.
- **Superpowers worktree** under `~/.config/superpowers/worktrees/` is out of scope; only `.worktrees/` worktrees are swept or paned.

## Integration points

- `claude/.claude/skills/worktree-first/SKILL.md` (shared with Codex via `agents/.agents/skills/worktree-first`; `openai.yaml` unchanged).
- `claude/.claude/WORKTREES.md`.
- `git/.config/git/worktree-tools/` — new `worktree-create`, `worktree-pane`; existing `worktree-remove` called by the sweep; stowed by the `git` package (Etienne restows after merge).
- `herdr/.config/herdr/scripts/hand-off-plan.sh` and its tests in `test/herdr_worker_scripts_test.rb`.
- `claude/.claude/skills/implement/SKILL.md` (`handoff` mode passes the branch name).
- `gh pr view` is used by the sweep as today; unchanged.

## Acceptance criteria

- Creating a worktree inside herdr opens a pane in the current workspace whose working directory is the new worktree, labelled `<repo>/<branch>`, and the caller's pane keeps focus.
- Creating a worktree outside herdr opens no pane, prints nothing about herdr, and the worktree exists.
- When herdr refuses the split, the worktree still exists, the command exits 0, and one warning line names the herdr error.
- Sweeping a merged worktree closes the pane whose working directory is that worktree, then removes the worktree.
- Sweeping a merged worktree whose pane runs an agent leaves that pane open, names it, and still removes the worktree.
- Sweeping a merged worktree with no pane closes nothing and removes the worktree.
- `hand-off-plan.sh <plan> <name>` creates `.worktrees/<name>`, starts the worker in a pane whose working directory is that worktree, and the prompt it sends says the worker is already in its worktree.
- `hand-off-plan.sh <plan>` without a name behaves exactly as before: worker pane in the main checkout, prompt tells the worker to invoke `worktree-first`.
- `implement handoff` calls `hand-off-plan.sh` with the change's branch name.
- `worktree-first` run twice for the same name inside herdr opens one pane, not two: the second `worktree-create` reuses the existing worktree instead of failing, and `worktree-pane open` reuses the existing pane.
- `WORKTREES.md` mentions the pane in one sentence.

---
Domain skills applied: `dotfiles-maintenance` (stow layout, shared skill files, worktree-tools placement); `ruby-style` for the two scripts.
