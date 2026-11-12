# Delivery account: herdr-app-space-goto

## Behaviour delivered

- `; space` opens the `picker` mod in a herdr-app terminal too. The `terminal` section of `keys.json` no longer overrides it with `send:; `.
- `; ;` still types one `;`, so `; ;` then a space types `; ` in a shell or agent prompt.
- The leader runbook (`references/herdr-app-cores.md`) says this, and that a `; ` typed in a terminal now opens the picker.
- `test_space_opens_the_picker_in_a_terminal` replaces `test_space_in_a_terminal_types_semicolon_space`. It refutes a terminal `; space` key and asserts that a terminal resolves `; space` to `mod.open:picker`.

## Evidence

- The new test failed before the `keys.json` change, on the `refute`, and passes after it.
- Sandbox herdr-app window (`HERDR_APP_HOME=/private/tmp/claude-502/sgk`, `HC_SESSION=sgk1`, started under `env -i`) with the branch `keys.json`: `keys.error` absent, `herdr-app status` printed `"errors": []`.
- Control: a truncated sandbox `keys.json` produced `keys.error` and a status error ("EOF while parsing a value at line 1 column 25"). Restoring the branch file cleared both. The window reloads `keys.json` live.
- `herdr-app do mod.open --name picker` added `picker` to the status `overlays` in the sandbox, so the overlay list shows when the picker is open.
- Not run: the key walk (`; space` in a terminal, `; ;` then space, `; space` in the sidebar). herdr-app has no CLI that sends a key into a window, and OS-level synthetic keystrokes could reach Etienne's own window. Etienne checks these three by hand after restowing `herdr-app`.

## Check results

- `bin/test test/herdr_app_keys_test.rb`: 9 runs, 0 failures.
- rubocop on the test file: no offenses. markdownlint no-hardwrap on the runbook: clean. `keys.json` parses as JSON.
- Full `bin/test`: 120 files, 2 failed, both unrelated to this diff and red on `main` (`b0745263`) as well:
  - `test/repo_agents_file_test.rb`: `agents.md` still lists `conductor`, which commit `7ebcd89f` dropped from `packages.conf`. Main CI fails on this too.
  - `test/secrets_loader_test.rb`: 5 failures on live 1Password `op read` calls, local only; CI passes it.
- Etienne chose to deliver with CI red on the `conductor` failure and to fix `main` himself.

## Review outcome

- Round 1 (Claude, `b2e941c9`): one Nit, "picker" in bare prose where the glossary reserves it; fixed in "Name the picker mod, not a bare picker, in the runbook and test".
- Round 2 (Claude, `653693c6`): no findings. Codex review: not enabled.

## Notes for Etienne

- `~/.config/herdr-app/scripts/` is empty since 2026-11-12 13:25, so `start-review` and `hand-off-plan` fail in herdr-app until `herdr-app` is restowed. The review ran in-session for that reason.
