# Probes: Codex sessions lack unlocked secrets

Recorded 2026-10-08 by the implement worker. No secret value appears here.

## Result

P10 passed in part. P1 to P9 did not run: `op whoami` reports `account is not signed in`, so `unlock` cannot read the 1Password references, and the worker cannot approve the 1Password prompt.

## Ran

- P10, locked shell: `env -u ZDOTDIR zsh -f -c 'command -v codex'` printed `/opt/homebrew/bin/codex`, the real binary. `unlocked-bin` is not on `PATH` (count 0). The "no notice" half needs an interactive `codex` start and did not run.
- Shim under dash (the CI `/bin/sh`): `dash unlocked-bin/codex -p terra` called the fake Codex with `--no-daemon -p terra`. `dash unlocked-bin/codex agents` called it with `agents` only.

## Not run

- P1, P2, P3, P4, P5, P6, P7, P8: need a real `unlock`, and so a signed-in 1Password.
- P9: needs ChatGPT.app, which Etienne drives.
- P10, interactive half: the TUI start notice.

Unit and acceptance tests cover the same behaviour against a fake Codex. They prove the shim passes `--no-daemon` and the secrets. Only P1 to P9 prove that the real Codex 0.161.0 honours them.
