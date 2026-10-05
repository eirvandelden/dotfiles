# Intent: the file viewer opens where the agent is working

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature.

## Problem

An agent in a herdr pane creates a worktree (for example through the `intent` skill) and writes its files there. The agent's pane itself stays in the main checkout. When the user then presses `prefix+f` or `prefix+shift+f` from that pane, the file viewer opens at the main checkout, so the file the agent just wrote is not in the tree. To read it, the user must press `W` and pick the worktree, or first focus the separate worktree pane that `worktree-first` opened. The user forgets this step and concludes the viewer is broken.

## Proposed outcome

From the focused pane, `prefix+f` and `prefix+shift+f` open the file viewer at the worktree that the agent in that pane created or used most recently. When the agent in the focused pane has no worktree, the viewer opens and shows the `W` worktree picker straight away, so the user chooses. Everything else about the viewer stays as it is today, including `W` to switch later.

## Affected users and systems

- The user, reading agent-written files in herdr.
- The herdr key bindings in `herdr/.config/herdr/config.toml`.
- The worktree tooling in `git/.config/git/worktree-tools/` and the `worktree-first` skill, which know which worktree an agent works in.
- The `herdr-file-viewer` plugin (`smarzban/herdr-file-viewer`), used as it is.
- `herdr/.config/herdr/README.md`, which documents how to reach a worktree.

## Constraints

- No changes to the viewer plugin: not to its code, not to its installed copy, and no upstream contribution. The change lives only in this repository and uses the plugin as it is.
- Must work for Claude and Codex panes alike (Claude/Codex parity).
- No new dependency without asking.
- Outside herdr, and in panes without an agent, nothing gets worse than today.

## Open questions

- Settled: `worktree-create` records which worktree each agent pane created or reused last, so Claude and Codex panes work the same way. Reading an agent's own session files is ruled out: Claude-only and an undocumented format.
- How to show the `W` picker straight away without changing the plugin. The plugin has no setting or launch option for it; its only launch option is `HERDR_FILE_VIEWER_OPEN`, which opens a file. Tested: `herdr pane send-keys <viewer pane> W` opens the picker once the viewer has loaded. For `spec` to settle the wait.
