# Intent: Restore agents in herdr-app panes after a reboot or core restart

Author: Etienne van Delden. Status: accepted (2026-11-13). Type: feature. Delivery: autonomous. Codex review: no.

## Problem

After a reboot or a core restart, every herdr-app pane holds a bare shell in its last folder. The Claude and Codex agents that ran there are gone. Their transcripts survive, but nothing records which session belonged in which pane, so several sessions in one folder cannot be told apart. Today Etienne matches transcripts to panes by hand.

## Proposed outcome

Every running Claude and Codex session records its pane. After the cores are back, one command resumes each session that was running at shutdown in its own pane, with the same session id.

## Affected users and systems

- Etienne, on every herdr-app core (`default` and `work`).
- Claude and Codex `SessionStart` hooks (`claude/.claude/settings.json`, `codex/.codex/config.toml`).
- The `herdr-app` package: a new restore command. `herdr-app-migrate` already has `AgentSession#resume_argv`.
- `hc` (`ls`, `send`, `keep`) is the interface to terminals.

## Constraints

- No new gems or packages. Playbook rules 8, 9, 11, 12 and 13 need no permission for this change.
- The records are keyed by core session plus `HC_TERMINAL_ID`, because terminal ids repeat across cores.
- The restore command must never type into a pane that is not at a bare shell, and never resume a session already open in another pane.
- Records live outside the repository, in a state directory under `~/.local/state`.
- Premises the plan stage must verify before building on them: the Codex `SessionStart` payload carries the session id and cwd; `HC_TERMINAL_ID` stays the same across a core restart; `hc ls --json` lists the restored terminals.

## In scope

- A `SessionStart` recorder, for Claude and for Codex, that writes one JSON record per pane (session id, cwd, transcript path, agent kind, core session).
- A manual restore command that finds the panes with a record whose transcript changed within 10 minutes of the last shutdown, and resumes them (`claude --resume <id>`, `codex resume <id>`).
- Skipping `claude -p` and other non-interactive runs.
- Restoring the permission flag the session started with, when the hook can see it.
- Tests for the recorder and the restore command.

## Out of scope

- Starting the restore automatically after login (no LaunchAgent).
- A `SessionEnd` hook that deletes records.
- The herdr TUI and Rex. They have their own session handling.
- Matching transcripts to panes by topic for panes with no record.
- A fix in herdr itself (herdr-core#15).

## Acceptance criteria

- Starting a Claude session in a herdr-app pane writes a record for that pane.
- Starting a Codex session in a herdr-app pane writes a record for that pane.
- Running `claude -p` writes no record.
- After a core restart, the restore command runs `claude --resume <id>` in the pane that held that session.
- After a core restart, the restore command runs `codex resume <id>` in the pane that held that session.
- Four sessions in one folder each return to their own pane.
- A pane whose transcript was last written more than 10 minutes before shutdown is left alone.
- A pane that no longer shows a bare shell is left alone.
- A session already open in another pane is not resumed twice.
- Panes on the `work` core restore the same way as panes on the `default` core.
- The command reports how many agents it restored.

## Decisions

- Restore starts from a manual command, not a LaunchAgent — Recommended option taken: herdr-app has no post-boot hook.
- Claude and Codex both restore — Etienne chose the wider option; no reason given.
- Every core is covered — terminal ids repeat across cores, so keys include the core session.
- A transcript timestamp window decides what was running, not a `SessionEnd` hook — Etienne chose the article's approach over the recommended option; no reason given.
- The window is 10 minutes — the value the article proved.
- Delivery is autonomous, without a Codex review — Etienne chose it; the change is small shell and config.

## Open questions

None.
