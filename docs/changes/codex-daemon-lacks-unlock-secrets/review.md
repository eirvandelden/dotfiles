# Review: codex-daemon-lacks-unlock-secrets

## Round 1 — 2026-10-09T10:45Z — 904f37da (codex)

- [ ] Important: an unlocked `--no-daemon` session passes every secret to the real Codex, so a shared daemon that the session starts for a background feature ("Start background server", a handoff) inherits the secrets and exposes them to other Codex sessions and ChatGPT.app — `zsh/.config/zsh/unlocked-bin/codex:74` →
