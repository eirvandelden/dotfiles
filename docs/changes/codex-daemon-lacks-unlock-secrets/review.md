# Review: codex-daemon-lacks-unlock-secrets

## Round 1 — 2026-10-09T10:45Z — 904f37da (codex)

- [ ] Important: an unlocked `--no-daemon` session passes every secret to the real Codex, so a shared daemon that the session starts for a background feature ("Start background server", a handoff) inherits the secrets and exposes them to other Codex sessions and ChatGPT.app — `zsh/.config/zsh/unlocked-bin/codex:74` →

## Round 2 — 2026-10-12T07:53Z — 9bdd7fec (claude)

- [ ] Important: the P4 gate is not met. The fizzy and email calls for `codex -p terra`, `codex resume`, `codex exec` and `headroom wrap codex` did not run (home MCP hosts unreachable), so acceptance criterion 4 is proven live only for the shell-command secrets. The plan requires every probe to pass; probe.md still marks P4 "Pass" — `docs/changes/codex-daemon-lacks-unlock-secrets/probe.md:48` →
- [ ] Nit: a daemon-kind launch strips the mapped secrets but keeps `unlocked-bin` first on `PATH`. A shared daemon that `codex agents`, `queue`, `app-server` or `update` starts from an unlocked shell therefore hands the shim to every later locked or ChatGPT.app session on it, and a nested `codex` there gets `--no-daemon`. This conflicts with "without `unlock`, `codex` behaves as today" — `zsh/.config/zsh/unlocked-bin/codex:76` →
- [ ] Nit: the criterion "a `codex` started from a shell without `unlock` has no fizzy tools" maps to `test_daemon_commands_from_an_unlocked_shell_run_without_the_secrets`, which runs `codex agents` from an unlocked shell. `test_without_unlock_codex_is_the_real_binary_with_its_arguments_unchanged` is the test that proves it — `test/codex_unlock_test.rb:83` →
- [ ] Nit: `## Proof` names `test_after_unlock_headroom_finds_the_shim_and_its_session_runs_off_the_shared_daemon`; the test in the diff ends in `_with_the_secrets` — `docs/changes/codex-daemon-lacks-unlock-secrets/plan.md:107` →
- [ ] Nit: `test_the_shim_skips_its_own_directory_to_find_the_real_codex` makes the same assertions as `test_a_bare_launch_runs_the_real_codex_with_no_daemon_first`. If the skip breaks, the shim execs itself in a loop and the test hangs instead of failing — `test/codex_unlocked_shim_test.rb:97` →
