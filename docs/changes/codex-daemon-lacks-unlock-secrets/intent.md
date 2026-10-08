# Intent: Codex sessions lack unlocked secrets

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix. Delivery: autonomous.

## Problem

After `unlock`, a `codex` session started from that shell cannot reach the unlocked secrets. The fizzy and email MCP servers do not connect, and shell commands Codex runs do not see `FIZZY_PAT`, `NODE_AUTH_TOKEN` or the other variables from the 1Password mappings.

Since Codex 0.160, the `codex` TUI hands MCP servers and shell commands to a shared, managed `codex app-server` daemon. The daemon starts from wherever it is first needed — ChatGPT.app, an auto-update, or an earlier shell without `unlock` — and keeps that environment. The TUI's own environment, which does hold the secrets, no longer matters.

## Proposed outcome

Run `unlock`, then `codex` as usual: the fizzy and email MCP servers connect, and shell commands Codex runs see every unlocked variable. Only that session sees them. It holds no matter when or by whom the shared daemon started or restarted.

Without `unlock`, `codex` behaves as today and holds no secrets.

## Affected users and systems

- Etienne, running Codex by hand on every Mac that uses these dotfiles.
- The `codex` CLI 0.160+ and its managed app-server daemon, shared with other Codex sessions and ChatGPT.app.
- `unlock` / `secrets` (`zsh/.config/zsh/functions/secrets.zsh`) and both 1Password mapping files.
- `codex/.codex/config.toml` MCP entries that use `bearer_token_env_var`.
- `headroom wrap codex`.

## Constraints

- Secrets reach Codex only after `unlock` in the shell that starts it.
- Only the session started from the unlocked shell sees the secrets. Other Codex sessions, the shared daemon and ChatGPT.app agents never do.
- Never interrupt work running on the shared daemon.
- A process that holds the secrets may outlive the session, until logout or reboot.
- The launch command stays plain `codex` (and its usual subcommands and flags); no new command to remember.
- No plaintext secret on disk; the mapping files hold `op://` references only.
- The dotfiles repo is public: no work references in it.
- Approved up front: restowing an existing package with `stow -R -t "$HOME"` (rule 12), and starting or stopping private `codex app-server` processes for tests (rule 8). The shared daemon is never touched, and Codex is never installed or upgraded.

## In scope

- Sessions started by hand from a shell after `unlock`: `codex`, `codex -p <profile>`, `codex resume`, `codex exec`, `headroom wrap codex`.
- MCP servers that authenticate with `bearer_token_env_var` (fizzy, email).
- The environment of shell commands Codex runs in that session: every variable from both mapping files.
- Correct behaviour when the shared daemon already runs without secrets, and after it restarts or auto-updates.

## Out of scope

- Codex panes that herdr starts (`hand-off-plan.sh` stages, a Codex coordinator).
- Giving secrets to ChatGPT.app, the Codex desktop app, or the shared daemon.
- Removing secrets from memory when the session ends.
- Changing which secrets the 1Password mappings hold, or where `FIZZY_PAT` lives.
- Claude Code's MCP registration.

## Acceptance criteria

- After `unlock`, `codex` started from that shell lists the fizzy tools and reads a fizzy board.
- After `unlock`, the email MCP server connects in that session.
- After `unlock`, a shell command in that session reports `FIZZY_PAT` and `NODE_AUTH_TOKEN` as set.
- The three criteria above also hold for `codex -p terra`, `codex resume`, `codex exec` and `headroom wrap codex`.
- They hold when ChatGPT.app started the shared daemon earlier without secrets.
- They hold after the shared daemon restarts or auto-updates.
- Starting the unlocked session leaves a ChatGPT.app agent or another Codex session mid-task running, uninterrupted.
- While the unlocked session runs, a `codex` started from a shell without `unlock` has no fizzy tools, and its shell commands report `FIZZY_PAT` as unset.
- A ChatGPT.app agent's shell command reports `FIZZY_PAT` as unset, before and after an unlocked session starts.
- Without `unlock`, `codex` starts as today, on the shared daemon, with no new prompt or warning.

## Flagged concerns

- Isolation vs. shared visibility: a session kept off the shared daemon may not show in `codex agents` or ChatGPT.app's session list. Chosen side: isolation, as the interview asked for only the unlocked session to see the secrets.
- Secrets vs. running work: getting secrets into the shared daemon would mean restarting it mid-task. Chosen side: running work wins; the shared daemon is never restarted for secrets.

## Open questions

None.
