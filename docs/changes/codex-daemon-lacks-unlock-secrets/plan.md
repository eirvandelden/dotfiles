# Plan: Codex sessions lack unlocked secrets

From `intent.md` (2026-10-08). Status: accepted.

## Context

`unlock` is today `alias unlock='eval "$(secrets)"'` in `zsh/.config/zsh/aliases.zsh`. It exports every variable from `~/.config/secrets/1password.env` and the optional `1password.work.env` into the current shell.

Codex 0.161.0 (the installed version, `/opt/homebrew/bin/codex`, a Homebrew cask) connects a plain `codex` session to the shared daemon `codex app-server --listen unix:// --managed-daemon`. That daemon runs from `~/.codex/packages/app-server-daemon/releases/<version>/bin/codex`, never from `PATH`. Its control socket is `~/.codex/app-server-control/app-server-control.sock`. On 2026-10-08 the running daemon (pid 77948, parent launchd) held neither `FIZZY_PAT` nor `MCP_EMAIL_SERVER_AUTH_TOKEN`.

Facts checked while planning, on codex 0.161.0:

- `codex --no-daemon` runs the session in-process. A probe in a pseudo-terminal showed no connection to the daemon socket, and the TUI spawned the MCP servers (`node_repl`) as its own children. In-process MCP servers and shell commands inherit the TUI's environment.
- `codex exec` already runs in-process. `PLANPROBE_VAR=probe-ok-42 codex exec ... "printenv PLANPROBE_VAR"` printed `probe-ok-42` while the shared daemon ran. `exec` has no `--no-daemon` or `--remote` flag.
- `--no-daemon` parses as a top-level flag before any subcommand (`codex --no-daemon mcp list`, `codex --no-daemon features list` exit 0).
- Codex refuses `--no-daemon` for the commands that need the shared server. Live forms, not `--help`: `codex --no-daemon agents` exits 1 with `--no-daemon cannot be used with codex agents. The agents overview requires a shared server.`; `codex --no-daemon queue --thread <uuid> --message probe` exits 1 with `--no-daemon cannot be used with codex queue. Queuing must discover the shared server ...`. The binary also holds `--no-daemon cannot be used with --remote.`
- `codex resume` and `codex fork` accept `--no-daemon`.
- `headroom wrap codex` (headroom 0.32.1, `_run_codex_wrap` in `headroom/cli/wrap.py`) finds Codex with `shutil.which("codex")`. Its `_codex_session_launch_settings` then sets `OPENAI_BASE_URL` in the environment and, for the default `openai` provider, runs `codex --config openai_base_url=<proxy> <user args>`. A zsh function cannot reach it; only an executable on `PATH` can.
- `shell_environment_policy.ignore_default_excludes` defaults to `true` (Codex config reference), so names with `TOKEN`, `KEY` or `SECRET` reach shell commands. `NODE_AUTH_TOKEN` needs no config change.

## Design decisions

- **Mechanism: an executable `codex` shim that `unlock` puts first on `PATH`.** The shim runs the real Codex with `--no-daemon` for session launches. The session then runs in its own process with the unlocked environment. It never touches the shared daemon. Only a `PATH` executable covers `headroom wrap codex` and nested launches.
- **The shim is on `PATH` only after `unlock`.** A shell without `unlock` never sees it, so a locked `codex` runs the real binary with its arguments unchanged. The shim needs no marker variable: being on `PATH` and holding the secrets both travel together in the inherited environment.
- **Location: `zsh/.config/zsh/unlocked-bin/codex`.** `unlock` owns it, and `unlock` lives in the `zsh` package. The directory holds only `codex`, because everything in it shadows a real command.
- **`unlock` finds the directory at `${ZDOTDIR:-$HOME/.config/zsh}/unlocked-bin`**, read when `unlock` runs. That is the stowed path, the same way `.zshrc` finds `functions/` and `aliases.zsh`. The new directory needs one `stow -R -t "$HOME" zsh` per Mac after the merge; the intent approves that restow. When `unlocked-bin/codex` is not there, `unlock` still exports the secrets, leaves `PATH` alone, and prints `unlock: <dir>/codex is missing; restow the zsh package` to stderr, so a forgotten restow is visible instead of silent. Tests and the pre-merge probes set `ZDOTDIR` to a checkout's `zsh/.config/zsh`.
- **`unlock` becomes a function in `secrets.zsh`; the alias goes.** `.zshrc` sources `aliases.zsh` before `functions/*.zsh`, and an alias named `unlock` would shadow the function. The function runs `secrets`, and only when it succeeds does it eval the exports and prepend the shim directory once. A failed `secrets` now applies no exports at all (today a mid-file failure applies the exports before it). PATH stays unchanged on failure. The function body stays in syntax that `shellcheck -s bash` accepts, because the repository lints `*.zsh` that way (a `case ":$PATH:"` test for the existing entry, no zsh-only expansions).
- **The shim sorts each invocation into one of three kinds**, by the first word that is not an option or an option's value:
  - *Session*: no subcommand, a prompt, `resume` or `fork`, or any word it does not know. It runs `real-codex --no-daemon <args>` with the full environment. This covers `codex`, `codex -p terra`, `codex resume`, `codex fork` and headroom's `codex --config ... <args>`. An unknown word stays a session because it cannot be told apart from a prompt, and `codex <prompt>` is a usual launch. It still cannot carry the secrets into the shared daemon: it gets `--no-daemon`, and Codex refuses that flag for commands that need the shared server.
  - *Daemon*: `agents`, `queue`, `app-server`, `remote-control`, `update`, or any launch with `--remote`. These reach or may start the shared daemon. The shim unsets every variable named in the two mapping files, then runs the real Codex with the arguments unchanged. A daemon that such a command starts therefore never holds a secret.
  - *Other*: `exec`, `e`, `review`, `login`, `logout`, `mcp`, `plugin`, `app`, `completion`, `doctor`, `sandbox`, `debug`, `apply`, `a`, `archive`, `delete`, `migrate-rollouts`, `unarchive`, `cloud`, `exec-server`, `features`, `help`, or an explicit `--no-daemon`. The shim runs them unchanged with the full environment.
- **Options that take a value are skipped with their value**: `-c`/`--config`, `--enable`, `--disable`, `--remote-auth-token-env`, `-i`/`--image`, `-m`/`--model`, `--local-provider`, `-p`/`--profile`, `-s`/`--sandbox`, `-C`/`--cd`, `--add-dir`, `-a`/`--ask-for-approval`. `--` ends the scan (the rest is a prompt, so it is a session). The attached forms (`--config=x`, `-pterra`) are one word. A value option at the end with no value counts as a session; Codex reports the error itself.
- **The shim finds the real Codex by walking `PATH` and skipping its own directory** (compared with `pwd -P`). It runs it by absolute path and leaves `PATH` alone, so nested launches inside the session go through the shim again. No real Codex found: it prints `codex: no codex found on PATH besides <dir>` to stderr and exits 127.
- **POSIX `sh`.** The shim is `#!/bin/sh`, so it runs under dash on the Ubuntu CI and `shellcheck` lints it in full. It uses `exec`, so the real Codex keeps the pid, the terminal and the exit status.
- **Mapping file names come from the files**, as `secrets` reads them: `${XDG_CONFIG_HOME:-$HOME/.config}/secrets/1password.env` and `1password.work.env`. Names are the `KEY` in non-comment `KEY=...` lines. A missing file contributes no names.
- **No Codex config change.** `ignore_default_excludes` already defaults to `true`; `bearer_token_env_var` entries stay as they are.
- **One line of documentation** in the Codex section of `claude/.claude/HEADROOM.md`: after `unlock`, `codex` and `headroom wrap codex` run in-process, off the shared daemon, so they do not show in `codex agents`.

## Integration points

- Codex CLI 0.161.0: the `--no-daemon` flag, its subcommand list, and the shared daemon socket. A Codex upgrade can add or rename subcommands.
- headroom 0.32.1: `shutil.which("codex")` and the `--config openai_base_url=...` prefix it adds.
- 1Password CLI `op`, through the unchanged `secrets` function.
- GNU Stow: `~/.config/zsh` is a real directory with file symlinks into `~/Developer/dotfiles/zsh/.config/zsh`. A restow of `zsh` from the main checkout links the new `unlocked-bin` directory.
- `.zshrc` load order: `aliases.zsh`, then `functions/*.zsh`.
- CI (`.github/workflows/dotfiles-tests.yml`): Ubuntu, Ruby 3.4, zsh installed, runs every `test/*_test.rb` with `ruby -Itest`. `/bin/sh` there is dash.
- Codex shell commands run as `zsh -lc`, which re-runs `paths.zsh`. That prepends system directories, but those hold no `codex`, so the shim stays ahead of `/opt/homebrew/bin`.

## Files that change

- `zsh/.config/zsh/unlocked-bin/codex` — new, mode 100755, POSIX `sh`. Classifies the invocation, adds `--no-daemon` to sessions, removes mapped secrets from daemon commands, and runs the real Codex. Header comment says why (Codex 0.160+ shared daemon) and points to `unlock`.
- `zsh/.config/zsh/functions/secrets.zsh` — adds `unlock()`, which reads the shim directory from `ZDOTDIR` and warns when the shim is missing; updates the header usage comment to name `unlock`.
- `zsh/.config/zsh/aliases.zsh` — removes `alias unlock='eval "$(secrets)"'` and its `# Secrets` heading.
- `test/codex_unlock_test.rb` — new acceptance tests: `unlock` then `codex ...` in a zsh shell, against a fake real Codex.
- `test/codex_unlocked_shim_test.rb` — new unit tests for the shim on its own.
- `test/secrets_loader_test.rb` — new unit tests for `unlock()`.
- `claude/.claude/HEADROOM.md` — one line in the Codex section.
- `docs/changes/codex-daemon-lacks-unlock-secrets/probe.md` — new, the by-hand checks and their recorded results.

## Order of work

1. Write the acceptance test `test_after_unlock_a_codex_session_gets_the_fizzy_token_off_the_shared_daemon` in `test/codex_unlock_test.rb`. Run `ruby -Itest test/codex_unlock_test.rb`. Watch it fail because `unlock` is not a function and no shim exists.
2. Write the `unlock()` unit tests in `test/secrets_loader_test.rb`. Watch them fail. Add the shim directory and `unlock()` to `secrets.zsh`; remove the alias from `aliases.zsh`. Make them pass.
3. Write the shim's session tests in `test/codex_unlocked_shim_test.rb`. Watch them fail. Create the shim with the `PATH` walk and session handling only. Make them pass. Step 1's test now passes.
4. Write the remaining acceptance tests in `test/codex_unlock_test.rb` (profile, resume, exec, headroom, locked shell, daemon commands, no daemon control). Watch the ones that need new behaviour fail.
5. Write the shim's daemon and other tests. Watch them fail. Add the daemon kind (unset mapped names) and the other kind. Make every test pass.
6. Add the HEADROOM.md line.
7. Lint every touched file: `shellcheck -S warning zsh/.config/zsh/unlocked-bin/codex`; `shellcheck -S warning -s bash zsh/.config/zsh/functions/secrets.zsh zsh/.config/zsh/aliases.zsh`; `zsh -n` on the same two files; `rubocop --force-exclusion` on the three test files; `markdownlint` on `HEADROOM.md`, `plan.md` and `probe.md`. No disable comments, no linter config edits.
8. Run the full suite: `set -o pipefail; for f in test/*_test.rb; do ruby -Itest "$f" || break; done`.
9. Run the by-hand probes P1–P10 from the worktree, without restowing: in a new terminal, `ZDOTDIR=<worktree>/zsh/.config/zsh; unalias unlock; source "$ZDOTDIR/functions/secrets.zsh"; unlock`. `unlock` needs 1Password approval from Etienne (see Risks). Record each command and result in `probe.md`, never a secret value. Use `test -n "$FIZZY_PAT" && echo set || echo unset` for presence, and `ps eww -p <pid> | grep -c 'FIZZY_PAT='` for a process environment. The change is not done until `probe.md` records P1–P10 as passed; a probe that cannot run is reported, not skipped.
10. Re-read the full diff. Grep it for work names before each commit (the repository is public). Commit in logical steps: `unlock` function with its tests; the shim with its tests and acceptance tests; the HEADROOM.md line; `probe.md`.

After the merge, on each Mac: `cd ~/Developer/dotfiles && stow -R -t "$HOME" zsh`. The intent approves this restow. Until it runs, `unlock` prints its restow warning and `codex` behaves as today.

## Risks

- Isolation costs visibility: an unlocked session does not show in `codex agents` or ChatGPT.app's session list. Intent accepted this trade.
- Inside an unlocked session, a Codex feature that starts a background server (the TUI shows "Starting a background server will not interrupt or move this session") would start the shared daemon from the session's environment, with the secrets. Probe P7 checks that the daemon pid and its environment are unchanged after an unlocked session. If a TUI action does start the daemon with secrets, that is a new decision for Etienne, not a silent fix.
- Codex upgrades can add subcommands. An unknown word counts as a session and gets a top-level `--no-daemon`. A new daemon-bound subcommand would keep the secrets until the shim lists it, but it reaches the daemon only if Codex ignores its own `--no-daemon` for it; today Codex refuses the flag for every command that needs the shared server. The shim's comment names the Codex version its list came from.
- `codex resume` in-process on a thread that the shared daemon still has open could give two writers on one rollout. Probe P4 resumes an idle session only.
- `unlock` becomes all-or-nothing. A failing `op read` now leaves the shell exactly as before, instead of half unlocked.
- Each Mac needs the restow after pulling the merge. Until then `unlock` warns and the fix is off on that Mac; nothing breaks.
- The by-hand probes need a real `unlock`, so 1Password asks Etienne for approval. An autonomous worker cannot give it.
- Rejected:
  - A zsh `codex` function: headroom finds Codex with `shutil.which`, which a function cannot answer.
  - Restarting the shared daemon with the secrets: breaks isolation and interrupts running work.
  - A private `codex app-server` per unlocked shell plus `--remote unix://PATH`: a process to start, find, and clean up, for the same isolation `--no-daemon` gives with no extra process.
  - A shim always on `PATH`, gated by a marker variable: it would sit in every locked launch, and a bug there would break plain `codex`.
  - Finding the shim through `realpath "$0"` of the sourced `secrets.zsh`: `$0` names the file only while zsh's `FUNCTION_ARGZERO` holds; under `emulate sh` or `POSIX_ARGZERO` it is `zsh`. The zsh-only `${(%):-%x}` and `:A` fail the repository's `shellcheck -s bash` lint.
  - Treating an unknown first word as a daemon command without secrets: it would strip the secrets from `codex <prompt>`.
  - Changing `shell_environment_policy`: the default already passes `TOKEN` names.

## Out of scope

- Codex panes that herdr starts. If a herdr server was itself started from an unlocked shell, its Codex panes inherit the shim and also run off the shared daemon; that is accepted, not designed for.
- Secrets for ChatGPT.app, the Codex desktop app, or the shared daemon.
- Removing secrets from memory when a session ends.
- The contents of either mapping file, and where `FIZZY_PAT` lives.
- Claude Code's MCP registration, and any change to `codex/.codex/config.toml`.
- Restowing during implementation. The restow happens after the merge, from the main checkout.

## Proof

- After `unlock`, `codex` started from that shell lists the fizzy tools and reads a fizzy board → `test/codex_unlock_test.rb` `test_after_unlock_a_codex_session_gets_the_fizzy_token_off_the_shared_daemon`; `probe.md` P1 (live, manual)
- After `unlock`, the email MCP server connects in that session → `test/codex_unlock_test.rb` `test_after_unlock_a_codex_session_gets_the_email_token_off_the_shared_daemon`; `probe.md` P2 (live, manual)
- After `unlock`, a shell command in that session reports `FIZZY_PAT` and `NODE_AUTH_TOKEN` as set → `test/codex_unlock_test.rb` `test_after_unlock_a_codex_session_gets_every_variable_from_both_mapping_files`; `probe.md` P3 (live, manual)
- The three criteria above also hold for `codex -p terra`, `codex resume`, `codex exec` and `headroom wrap codex` → `test/codex_unlock_test.rb` `test_after_unlock_a_profile_session_runs_off_the_shared_daemon_with_the_secrets`, `test_after_unlock_resume_runs_off_the_shared_daemon_with_the_secrets`, `test_after_unlock_exec_runs_unchanged_with_the_secrets`, `test_after_unlock_headroom_finds_the_shim_and_its_session_runs_off_the_shared_daemon`; `probe.md` P4 (live, manual)
- They hold when ChatGPT.app started the shared daemon earlier without secrets → `probe.md` P5 (live, manual: needs the real daemon)
- They hold after the shared daemon restarts or auto-updates → `probe.md` P6 (live, manual: the session holds no daemon socket and owns its MCP and shell children; the shared daemon is not restarted for the test)
- Starting the unlocked session leaves a ChatGPT.app agent or another Codex session mid-task running, uninterrupted → `test/codex_unlock_test.rb` `test_unlocked_launches_never_start_stop_or_restart_the_shared_daemon`; `probe.md` P7 (live, manual)
- While the unlocked session runs, a `codex` started from a shell without `unlock` has no fizzy tools, and its shell commands report `FIZZY_PAT` as unset → `test/codex_unlock_test.rb` `test_daemon_commands_from_an_unlocked_shell_run_without_the_secrets`; `probe.md` P8 (live, manual)
- A ChatGPT.app agent's shell command reports `FIZZY_PAT` as unset, before and after an unlocked session starts → `probe.md` P9 (live, manual: needs ChatGPT.app)
- Without `unlock`, `codex` starts as today, on the shared daemon, with no new prompt or warning → `test/codex_unlock_test.rb` `test_without_unlock_codex_is_the_real_binary_with_its_arguments_unchanged`; `probe.md` P10 (live, manual)

The by-hand probes are a required gate: the change is done only when `probe.md` records every probe below as passed, each with the command and its observed result.

- P1: after `unlock`, `codex`; `/mcp` lists fizzy tools; ask it to read one fizzy board.
- P2: in that session, `/mcp` shows the email server connected.
- P3: in that session, ask Codex to run `for v in FIZZY_PAT NODE_AUTH_TOKEN; do test -n "$(printenv $v)" && echo "$v set" || echo "$v unset"; done`.
- P4: repeat P1–P3 in interactive sessions started with `codex -p terra`, `codex resume` (an idle session) and `headroom wrap codex`. `codex exec` is not interactive, so it gets three prompts of its own, all with `-s read-only`: `codex exec "List the names of your MCP tools that start with fizzy_, then read one fizzy board and reply with its name only."`; `codex exec "Is the email MCP server connected? Call one of its read-only tools and reply yes or no."`; and `codex exec` with P3's command.
- P5: before the probes, confirm the shared daemon runs (`codex app-server daemon version`) and lacks the secrets (`ps eww -p <daemon pid> | grep -c 'FIZZY_PAT='` prints 0). P1–P4 then pass with it running.
- P6: during an unlocked session, `lsof -a -U -p <tui pid> | grep -c app-server-control` prints 0, and `pgrep -P <tui pid>` lists its MCP servers.
- P7: start a long task in a plain locked session (ask it to run `sleep 90`) and note the daemon pid. Start an unlocked session. The task finishes, and the daemon pid and its start time are unchanged. After the unlocked session exits, the daemon environment still has no `FIZZY_PAT`.
- P8: while the unlocked session runs, in a locked shell `codex`; `/mcp` shows fizzy failing; P3's command prints `FIZZY_PAT unset`.
- P9: in ChatGPT.app, an agent runs P3's command before and after an unlocked session starts: `FIZZY_PAT unset` both times.
- P10: in a locked shell, `command -v codex` prints the real binary, and `codex` shows no "Running without the shared background server" notice.

Per changed file, the unit tests expected:

- `zsh/.config/zsh/unlocked-bin/codex` (through `test/codex_unlocked_shim_test.rb`): `a bare launch runs the real codex with --no-daemon first`, `a prompt starts a session with --no-daemon`, `resume and fork start a session with --no-daemon`, `headroom's config prefix still starts a session with --no-daemon`, `an option value is never taken for a subcommand` (`-m exec`, `-C agents`, `-c x=agents`), `an explicit --no-daemon is not repeated`, `exec and other subcommands run unchanged with the secrets`, `agents, queue, app-server, remote-control and update run without any mapped variable`, `a --remote launch runs unchanged without the secrets`, `variables not in a mapping file survive a daemon command`, `a missing mapping file strips nothing and does not fail`, `the shim skips its own directory to find the real codex`, `no real codex fails with exit 127 and names the shim directory`, `the real codex's exit status comes back unchanged`.
- `zsh/.config/zsh/functions/secrets.zsh` (through `test/secrets_loader_test.rb`): `unlock exports the secrets and puts the unlocked commands first on PATH`, `unlock twice keeps one PATH entry`, `a failed unlock changes neither the environment nor PATH`, `unlock without the shim in ZDOTDIR exports the secrets, keeps PATH and warns to restow`, `the unlock alias no longer shadows the function` (source `aliases.zsh`, then `secrets.zsh`, then call `unlock` on a later line).
- `zsh/.config/zsh/aliases.zsh`: covered by the alias test above.

Test setup: plain Minitest, no Rails, as in `test/secrets_loader_test.rb`. Reuse its `op` stub, which answers any `op read` with a fixed value; add a failing variant for the failed-unlock test. A temporary `XDG_CONFIG_HOME` holds both mapping files, with made-up `op://Test/...` references for `FIZZY_PAT`, `NODE_AUTH_TOKEN` and `MCP_EMAIL_SERVER_AUTH_TOKEN`, and `SECRETS_WORK_OP_ACCOUNT` set. A fake real `codex` in a temporary `bin` writes one line per argument, plus `NAME=set` or `NAME=unset` for each mapped name, to a log, and exits with a status the test chooses. Shells run as `zsh -f -c` so no user startup file runs, with `ZDOTDIR` set to the checkout's `zsh/.config/zsh` and `PATH` set to the fake `bin`, the stub `bin`, `/usr/bin` and `/bin` only: the real Codex must never run in a test. The headroom test does what `_run_codex_wrap` does: it resolves `codex` with `command -v` (the `PATH` lookup `shutil.which` does), asserts that path is the shim, then runs that absolute path with `OPENAI_BASE_URL` set and the arguments `--config openai_base_url="http://127.0.0.1:8787/v1"`, and asserts the fake Codex got `--no-daemon` first, the headroom arguments unchanged after it, and the secrets.

## Decisions (coordinator, 2026-10-08)

- The implement worker runs every live probe it can reach, P1–P8 and P10, including the interactive TUI probes, by driving Codex in a pseudo-terminal. Etienne approves the 1Password prompts that `unlock` raises while the worker runs. A probe the worker cannot drive is reported in its report as `Decision needed:`, not skipped.
- P9 runs before the pull request opens. Etienne drives ChatGPT.app; the coordinator asks him for it once the worker's probes pass, and records his result in `probe.md`.
- After Etienne says the pull request merged, an agent runs `cd ~/Developer/dotfiles && stow -R -t "$HOME" zsh` on this Mac from the main checkout. Other Macs are Etienne's. The pull request body lists the command.

---
Domain skills applied: dotfiles-maintenance (stow layout, public-repository hygiene), object-oriented-design (one owner per behaviour: `unlock` owns the shim, the shim owns the launch decision), rails-testing (Minitest conventions, behaviour-named tests).

## Critique

### Round 1 (Codex, `codex exec -p terra -s read-only`)

- The shim directory cannot resolve: `realpath "$0"` in a sourced file names `zsh`, not `secrets.zsh`; use `$ZDOTDIR/unlocked-bin`, restow the approved package, and set `ZDOTDIR` in tests → fixed (unlock now reads `${ZDOTDIR:-$HOME/.config/zsh}/unlocked-bin`, warns to restow when the shim is missing, tests and probes set ZDOTDIR, and the restow runs after the merge)
  - Under default zsh options `$0` does name the sourced file; it is `zsh` only under `emulate sh` or `POSIX_ARGZERO`. That dependence on an option is reason enough to drop it.
- Unknown subcommands fail open: an unknown word keeps the secrets, so a future daemon command could receive them; strip by default and allow only verified in-process launches → dismissed: an unknown first word cannot be told apart from a prompt, and `codex <prompt>` is a usual launch that must keep the secrets. Every such launch gets `--no-daemon`, which Codex refuses for the commands that need the shared server, live-verified for `agents` and `queue`, so the secrets reach the daemon only if Codex ignores its own flag. Risks names the residual case.
- The headroom claim is stale because headroom 0.32.1 sets `OPENAI_BASE_URL`, and a `command -v` test proves neither interface → fixed (the headroom test now runs the resolved shim the way _run_codex_wrap does, and Context names both the variable and the config prefix that headroom sets)
  - `_codex_session_launch_settings` in headroom 0.32.1 sets `OPENAI_BASE_URL` and also adds `--config openai_base_url=...` for the `openai` provider, so the original claim was right but incomplete.
- The `codex exec` proof cannot run, because `/mcp` is interactive, and P1–P10 should be a required gate → fixed (P4 now gives codex exec its own read-only prompts, and probe.md must record P1 to P10 as passed before the change is done)
- The claim that Codex rejects `--no-daemon` with `agents` and `queue` is unsupported, since the `--help` forms succeed → dismissed: `--help` exits before validation. The live forms `codex --no-daemon agents` and `codex --no-daemon queue --thread <uuid> --message probe` both exit 1 with Codex's own refusal, now quoted in Context.
