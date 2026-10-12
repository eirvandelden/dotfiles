# Probes: Codex sessions lack unlocked secrets

Recorded 2026-10-08 and 2026-10-09 by the probe runner. No secret value appears here. Presence checks use `test -n "$(printenv NAME)"` and `ps eww -p <pid> | tr ' ' '\n' | grep -c '^NAME='`.

## Setup

- Unlocked shell: `ZDOTDIR=<worktree>/zsh/.config/zsh zsh -f`, then `source "$ZDOTDIR/functions/secrets.zsh"`, then `unlock`. Every probe checked that `command -v codex` is `$ZDOTDIR/unlocked-bin/codex`, and stopped if `unlock` failed.
- Locked shell: `env -u ZDOTDIR zsh -f`. Every probe checked that `command -v codex` is `/opt/homebrew/bin/codex`.
- Interactive sessions ran in a pseudo-terminal, in `~/Developer/dotfiles`, with `-s read-only`. Only one `unlock` ran at a time.
- Codex was 0.161.0 for P1, P2, P3, P5 and P6 (2026-10-08). It updated itself to 0.162.0 before the other probes (2026-10-09). The shim needed no change: 0.162.0 still honours `--no-daemon`.

## Result

P0 to P10 passed. P4's fizzy and email calls and P9 ran on 2026-10-12.

## P0: a failed unlock changes nothing (commit dc6cb172)

- Command: a stub `op` that always exits 1, then `unlock`, `unlock && echo ok` and `unlock || echo "unlock reported failure"` in a `zsh -f` shell.
- Result: plain `unlock` returned 1. `unlock && echo ok` printed nothing and returned 1. `unlock || ...` printed `unlock reported failure`. In all three cases the mapped variable stayed unset and the shim was not on `PATH`. `secrets` printed `op read failed for A_SECRET`.
- Pass.

## P1: fizzy tools in an unlocked session

- Command: unlocked shell, `codex -s read-only`, then `/mcp`, then a prompt to list the fizzy boards with read-only tools and reply with one board name.
- Result: the process was `/opt/homebrew/bin/codex --no-daemon -s read-only`. `/mcp` showed `fizzy : connected (49 tools)`. Codex called `fizzy.fizzy_get_accounts` and `fizzy.fizzy_get_boards`, then replied with one board name.
- Pass.

## P2: email server in an unlocked session

- Command: in the P1 session, `/mcp`, then a prompt to call one read-only email tool and reply YES_EMAIL or NO_EMAIL.
- Result: `/mcp` showed `email : connected (13 tools)`. Codex called `email.list_available_accounts` and replied `YES_EMAIL`.
- Pass.

## P3: secrets in shell commands

- Command: in the P1 session, the shell command `for v in FIZZY_PAT NODE_AUTH_TOKEN; do test -n "$(printenv $v)" && echo "$v set" || echo "$v unset"; done`.
- Result: `FIZZY_PAT set`, `NODE_AUTH_TOKEN set`.
- Re-check after the unlock fix, through `codex exec -s read-only` with the same command: `FIZZY_PAT set`, `NODE_AUTH_TOKEN set`.
- Pass.

## P4: the other entry points

- `codex -p terra -s read-only`: the process was `codex --no-daemon -p terra -s read-only`. Its environment held `FIZZY_PAT`. It had no link to the shared daemon. The P3 command printed `FIZZY_PAT set` and `NODE_AUTH_TOKEN set`.
- `codex -s read-only resume 01a11c0c-3c51-76c3-aa0d-534485510799` (the probe's own P1 session): the process was `codex --no-daemon -s read-only resume <id>`, and it showed the P1 history. Its environment held `FIZZY_PAT`. It had no link to the shared daemon. The P3 command printed `FIZZY_PAT set` and `NODE_AUTH_TOKEN set`. `/mcp` showed `github : connected (49 tools)`, whose bearer token also comes from `unlock`.
- `headroom wrap codex --no-mcp --no-tokensave --no-serena --no-context-tool -- -s read-only` (headroom 0.32.1; flags checked with `--help`): headroom found the shim. The process was `codex --no-daemon --config openai_base_url="http://127.0.0.1:8787/p/dotfiles/v1" -s read-only`. Its environment held `FIZZY_PAT`. It had no link to the shared daemon. The P3 command printed `FIZZY_PAT set` and `NODE_AUTH_TOKEN set`. The `git diff` of `codex/.codex/config.toml` in the main checkout had the same md5 before and after. No headroom proxy stayed on port 8787.
- `codex exec -s read-only` with the P3 command: `FIZZY_PAT set`, `NODE_AUTH_TOKEN set`.
- Fizzy and email on 2026-10-09: `/mcp` in each session above showed `fizzy : failed` and `email : failed`. `codex exec` logged `error sending request for url (http://fizzy-mcp.home.arpa/mcp)`, and the same for email. `fizzy-mcp.home.arpa` and `email-mcp.home.arpa` did not resolve from this network (`dscacheutil` gave no address, `curl` failed). This is a network failure, not a missing token: the locked P8 session reports a missing token with a different message.
- Fizzy and email on 2026-10-12, from the home network: one unlocked shell (the branch's `unlock`, with the shim first on `PATH`) ran each entry point with a read-only prompt. The prompt asked for the fizzy accounts and boards and the email accounts, and said not to show any content.
  - `codex exec --json -s read-only`: the `mcp_tool_call` events were `fizzy fizzy_get_accounts completed`, `fizzy fizzy_get_boards completed` and `email list_available_accounts completed`, each without an error.
  - `codex -p terra -s read-only`: the process was `codex --no-daemon -p terra -s read-only`. The TUI showed `Called fizzy.fizzy_get_boards` and `Called email.list_available_accounts`. The first prompt's calls failed on missing arguments (`Required`, `account_name Field required`), which means the servers accepted the token.
  - `codex -s read-only resume <the terra session>`: the process was `codex --no-daemon -s read-only resume <id>`. The TUI showed `Called fizzy.fizzy_get_accounts`, `Called fizzy.fizzy_get_boards` and `Called email.list_available_accounts`.
  - `headroom wrap codex --no-mcp --no-tokensave --no-serena --no-context-tool -- -s read-only <prompt>`: the process was `codex --no-daemon --config openai_base_url="http://127.0.0.1:8787/p/codex-daemon-lacks-unlock-secrets/v1" ...`. The TUI showed the same three `Called` lines. Afterwards no headroom proxy listened on port 8787, and the main checkout's `codex/.codex/config.toml` diff had no `openai_base_url`.
  - The shared daemon processes (started 2026-10-09) and the ChatGPT.app app-server had no `FIZZY_PAT` in their environment after these runs.
- Pass.

## P5: the shared daemon runs without secrets

- Command: `codex app-server daemon version`, and the presence check on the daemon process.
- Result on 2026-10-08: the daemon (pid 77948, started 07:29:13, parent launchd) was running with `FIZZY_PAT=0` before and after P1–P3. P1–P3 passed while it ran.
- Result on 2026-10-09: the daemon (pid 18171, 0.162.0, started 09:23:18, not by a probe) had `FIZZY_PAT=0` through P7 and P8.
- Pass.

## P6: the unlocked session owns its servers

- Command: during the P1 session, `lsof -a -U -p <tui pid>`, `pgrep -P <tui pid>` and the presence check on the session.
- Result: the session's environment held `FIZZY_PAT`. It had 0 sockets linked to the daemon. Its children were its own `node_repl`, the computer-use REPL and `codex-code-mode-host`.
- Pass.

## P7: an unlocked start does not touch work on the shared daemon

- Command: locked session A, `codex -s read-only`, ran `sleep 90; echo SLEEP_DONE` from 10:31:12. Unlocked session B started at 10:31:13 and ran the P3 command while A slept.
- Result: A had one socket linked to the daemon. A's command finished at 10:32:50 and printed `SLEEP_DONE`. The daemon kept pid 18171 and its start time 09:23:18 from before A until after B exited. Its environment had `FIZZY_PAT=0` at the end. B ran as `codex --no-daemon -s read-only` with 0 links to the daemon and printed `FIZZY_PAT set`.
- Pass.

## P8: a locked session gets no secrets while an unlocked one runs

- Command: while B ran, locked session C, `codex -s read-only`, with `/mcp` and the P3 command.
- Result: C was `codex -s read-only` with one socket linked to the daemon. Its environment had `FIZZY_PAT=0`. `/mcp` showed `fizzy : failed (0 tools)` and `email : failed (0 tools)`. The startup warnings said `FIZZY_PAT for MCP server 'fizzy' is not set` and `MCP_EMAIL_SERVER_AUTH_TOKEN for MCP server 'email' is not set`. The P3 command printed `FIZZY_PAT unset` and `NODE_AUTH_TOKEN unset`.
- Pass.

## P9: ChatGPT.app agents get no secrets

- Command on 2026-10-12, run by Etienne: a ChatGPT.app Codex agent ran P3's command before and after he started `unlock && codex` in a terminal.
- Result: every run printed `FIZZY_PAT unset` and `NODE_AUTH_TOKEN unset`.
- Pass.

## P10: a locked shell runs Codex as today

- Command: locked shell, `command -v codex`, then `codex -s read-only`, with the startup warnings paged through.
- Result: `command -v codex` printed `/opt/homebrew/bin/codex`, and `unlocked-bin` was not on `PATH`. The process was `codex -s read-only`, without `--no-daemon`, and had one socket linked to the shared daemon. No screen showed a notice about running without the shared background server.
- Pass.
