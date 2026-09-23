# Intent: a herdr pane rooted in every new worktree

Author: Etienne van Delden. Status: accepted (2026-09-23). Type: feature.

## Problem

Pressing the file-viewer key in herdr opens the viewer at the main checkout, never at the worktree an agent works in. The viewer roots at the focused pane's directory, and every pane sits in the main checkout: `worktree-first` creates worktrees with `git worktree add` and never gives herdr a pane there. `hand-off-plan.sh` starts its worker pane in the main checkout on purpose, so the worker can branch off cleanly, and the pane stays there after the worker moves into its worktree — a pane's directory does not follow the agent's `cd`. Verified 2026-09-23 on herdr 0.9.1: eleven linked worktrees, none with a pane or workspace of its own.

## Proposed outcome

Whenever `worktree-first` creates a worktree inside herdr, a pane rooted in that worktree exists in the current workspace, next to the caller, so focusing it makes the viewer and any other pane-rooted tool see the worktree. Workers started by `hand-off-plan.sh` begin in a pane already rooted in their worktree. When `worktree-first` sweeps a merged worktree, the pane it opened for it is closed, so no orphaned panes accumulate. No new sidebar workspaces are created; the workspace list stays as it is.

## Affected users and systems

Etienne, in every repository, in Claude and Codex sessions alike. `claude/.claude/skills/worktree-first/SKILL.md` (shared with Codex through `agents/.agents/skills/worktree-first`; its `openai.yaml` keeps `allow_implicit_invocation: false`), `claude/.claude/WORKTREES.md` (states the policy), `herdr/.config/herdr/scripts/hand-off-plan.sh` and `start-review.sh` (the pane-splitting scripts), `test/herdr_worker_scripts_test.rb` (the stub-`herdr` test pattern). The herdr file-viewer plugin is not changed.

## Constraints

- Outside herdr (`HERDR_ENV` unset: Codex, plain shells, CI) the skill and scripts behave exactly as today; the worktree is created and nothing herdr-related runs or fails.
- No new workspace, no `--cwd` on `herdr plugin pane open`, no custom viewer launcher — the brief's two verified dead ends.
- One skill file serves both tools; do not fork it.
- Tests use a stub `herdr` on `PATH` that records commands, as `test/herdr_worker_scripts_test.rb` does; CI has no herdr.
- Decided 2026-09-23: pane in the current workspace, not a workspace per worktree; sweep closes the pane; the superpowers worktree under `~/.config/superpowers/worktrees/` is out of scope.

## Open questions

- How does `worktree-first` find the pane it opened for a worktree at sweep time — a pane label carrying the branch name, a file in the worktree, or `herdr pane list` output? The spec decides.
- Should the new pane take focus? The caller usually wants to keep typing where it is; `--no-focus` is the likely default.
