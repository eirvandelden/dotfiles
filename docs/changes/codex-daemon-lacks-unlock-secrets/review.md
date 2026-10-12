# Review: codex-daemon-lacks-unlock-secrets

## Round 1 — 2026-10-09T10:45Z — 904f37da (codex)

- [x] Important: an unlocked `--no-daemon` session passes every secret to the real Codex, so a shared daemon that the session starts for a background feature ("Start background server", a handoff) inherits the secrets and exposes them to other Codex sessions and ChatGPT.app — `zsh/.config/zsh/unlocked-bin/codex:74` → dismissed: Etienne accepted this risk on 2026-10-12, because it needs an explicit action; documented in docs: warn against starting the background server from an unlocked session

## Round 2 — 2026-10-12T07:53Z — 9bdd7fec (claude)

- [x] Important: the P4 gate is not met. The fizzy and email calls for `codex -p terra`, `codex resume`, `codex exec` and `headroom wrap codex` did not run (home MCP hosts unreachable), so acceptance criterion 4 is proven live only for the shell-command secrets. The plan requires every probe to pass; probe.md still marks P4 "Pass" — `docs/changes/codex-daemon-lacks-unlock-secrets/probe.md:48` → fixed (docs: record P4's fizzy and email calls from the home network)
- [x] Nit: a daemon-kind launch strips the mapped secrets but keeps `unlocked-bin` first on `PATH`. A shared daemon that `codex agents`, `queue`, `app-server` or `update` starts from an unlocked shell therefore hands the shim to every later locked or ChatGPT.app session on it, and a nested `codex` there gets `--no-daemon`. This conflicts with "without `unlock`, `codex` behaves as today" — `zsh/.config/zsh/unlocked-bin/codex:76` → fixed (fix: daemon commands run without the codex shim on PATH)
- [x] Nit: the criterion "a `codex` started from a shell without `unlock` has no fizzy tools" maps to `test_daemon_commands_from_an_unlocked_shell_run_without_the_secrets`, which runs `codex agents` from an unlocked shell. `test_without_unlock_codex_is_the_real_binary_with_its_arguments_unchanged` is the test that proves it — `test/codex_unlock_test.rb:83` → fixed (docs: correct two test names in the plan's Proof list)
- [x] Nit: `## Proof` names `test_after_unlock_headroom_finds_the_shim_and_its_session_runs_off_the_shared_daemon`; the test in the diff ends in `_with_the_secrets` — `docs/changes/codex-daemon-lacks-unlock-secrets/plan.md:107` → fixed (docs: correct two test names in the plan's Proof list)
- [x] Nit: `test_the_shim_skips_its_own_directory_to_find_the_real_codex` makes the same assertions as `test_a_bare_launch_runs_the_real_codex_with_no_daemon_first`. If the skip breaks, the shim execs itself in a loop and the test hangs instead of failing — `test/codex_unlocked_shim_test.rb:97` → fixed (test: the shim's self-skip test covers a stowed symlink and fails on a deadline)

## Round 3 — 2026-10-12T13:02Z — 4d38b328 (claude)

Rounds 1 and 2 hold: the HEADROOM.md warning is in place; probe.md P4 records the fizzy and email calls for all four entry points; daemon commands drop `unlocked-bin` from `PATH` (`test_a_daemon_command_runs_without_the_shim_on_path`); the Proof names all exist; the self-skip test covers a symlinked directory and has a deadline. Shellcheck, `zsh -n` and rubocop are clean. Every test file passes except `test/review_report_check_test.rb`, which this branch does not touch: its temporary repository cannot commit to `main` past the global hooks. The shim's subcommand and option lists still match `codex --help` on 0.162.1.

- [x] Nit: the remedy `codex app-server daemon restart` "from a locked shell to clear them" has no probe behind it. Nothing shows that the restarted daemon takes the caller's environment and not the old daemon's. The doc also does not say that a restart interrupts work running on the daemon, which the intent forbids by default — `claude/.claude/HEADROOM.md:72` → fixed (docs: clear leaked daemon secrets with a stop, and say it interrupts work)
- [x] Nit: P0 cites commit `acb8012d`, which is not on the branch. It is the pre-rebase copy of `dc6cb172`, with the same patch-id — `docs/changes/codex-daemon-lacks-unlock-secrets/probe.md:16` → fixed (docs: cite P0's rebased commit in probe.md)

## Round 4 — 2026-10-12T13:00Z — 4d38b328 (codex)

- [x] Important: when the zsh package has not been restowed, `unlock` exports the secrets and returns success without the shim on `PATH`. A later `codex` runs the real binary and can start the shared daemon with the secrets. `unlock` should fail before it exports them — `zsh/.config/zsh/functions/secrets.zsh:132` → dismissed: the accepted plan chose this on purpose (plan.md: "Until it runs, `unlock` prints its restow warning and `codex` behaves as today"). `unlock` also gives Claude its MCP header tokens and npm its `NODE_AUTH_TOKEN`, so a failure would break those on every Mac until the restow. The result is no worse than before this change, and the warning names the fix.

## Round 5 — 2026-10-12T14:41Z — bac980d9 (claude)

Rounds 3 and 4 hold: HEADROOM.md now says `codex app-server daemon stop` and that it interrupts work (`stop` exists on 0.162.1); probe.md cites `dc6cb172` for P0 and records P9. The three touched test files pass (36 runs, 0 failures). Shellcheck, `zsh -n`, rubocop and the no-hardwrap markdownlint are clean. The diff holds no work names and no secret values. Every acceptance criterion maps to a test or a recorded probe, and every test that `## Proof` names exists. No existing test is weakened: `run_secrets` only moved its environment into a shared `env` helper.

- [ ] Important: a login shell started from an unlocked shell finds the real Codex first. macOS `/etc/zprofile` runs `path_helper`, and `/etc/paths.d/homebrew` puts `/opt/homebrew/bin` ahead of `unlocked-bin`, while the secrets stay exported. Codex runs its shell commands as `zsh -lc`, so a nested `codex agents`, `codex app-server daemon start` or plain `codex` from inside an unlocked session bypasses the shim. With no shared daemon running, that starts the shared daemon with the secrets. Checked: `PATH="<worktree>/zsh/.config/zsh/unlocked-bin:$PATH" zsh -lc 'command -v codex'` prints `/opt/homebrew/bin/codex`; without `-l` it prints the shim. The plan's claim "the shim stays ahead of `/opt/homebrew/bin`" is wrong, and no test or probe runs a nested launch — `zsh/.config/zsh/functions/secrets.zsh:139` →
- [ ] Nit: probe.md says "Recorded 2026-10-08 and 2026-10-09 by the probe runner", but P4's fizzy and email calls and P9 ran on 2026-10-12, and Etienne ran P9 — `docs/changes/codex-daemon-lacks-unlock-secrets/probe.md:3` →
- [ ] Nit: `SecretsLoaderTest` defines `ZSH_DIR`, `LOADER` and `SHIM_DIR` again, with the same values as `CodexShimSupport` in `test/codex_shim_support.rb` — `test/secrets_loader_test.rb:14` →

## Round 6 — 2026-10-12T14:40Z — bac980d9 (codex)

No findings.
