# Delivery account: restore-agents-after-reboot

## Behaviour delivered

- `herdr-app-agents record claude|codex` runs as a `SessionStart` hook and writes one agent record per core and terminal.
- `herdr-app-agents restore` resumes each session that was running at shutdown, in its own pane, with `claude --resume <id>` or `codex resume <id>`, on every running core.
- It types only into a bare shell, never resumes a session twice, skips cores that are not running, and keeps the permission flags the session started with.
- Recorder and restore refuse non-interactive runs (`claude -p`, `codex exec`).

## Evidence

- Codex gate, live, Codex 0.168.0: plain `codex` runs its hook in the TUI process, not in the app-server daemon. The recorder wrote a correct record with no refusal in plain and `--no-daemon` mode.
- Claude, live: the recorder run from a real herdr-app pane wrote a correct record, so the hook lineage passes against real `hc get` and `ps`.
- Sandbox core restart, live: two `claude --model haiku` sessions in one folder, `hc server stop` then `start`. `herdr-app-agents restore` printed `restored 2 agents`. Each pane resumed its own session. A second run printed `restored 0 agents` and typed nothing. The sandbox, scratch records and processes were removed afterwards.
- Not verified live: `codex resume` itself, a Codex TUI at the daemon's version (0.169.0), and a full reboot.

## Checks

- Full `bin/test`: 123 files, 0 failed, on `30dbc318`. The later commit changes `plan.md` only.
- New tests: `test/herdr_app_agents_cli_test.rb` (26) and `test/herdr_app_agents_test.rb` (41), green.
- rubocop on every touched Ruby file: no offenses. markdownlint on touched markdown: clean, except two MD038 lines in `herdr-app-cores.md` that predate this change.

## Review outcome

- Four rounds by the Claude reviewer. Round 1 found a real bug (restore started cores that were not running) and four more findings; round 4 found nothing.
- Every finding is closed: nine fixed, one dismissed because its live evidence is recorded here.
- No Codex review (`Codex review: no`).

## After the merge

- Etienne restows `herdr-app` so `~/.local/bin/herdr-app-agents` exists. Until then the hooks fail quietly.
- Etienne trusts the new Codex hook once.
- The first real reboot is the last check.
