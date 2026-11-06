# Plan: Rex app defaults in the install

From `intent.md` (2026-11-05). Status: accepted (2026-11-05).

## Design

### Domain terms

Install task: a numbered, standalone script in `install/tasks/` that `install.sh` runs.

### Diagrams

Not affected: a shell task, no object model.

### Signatures

Not affected: no Ruby code.

Not checked: this repository has no Steep setup for shell tasks.

### Complexity

Two `defaults read` calls and at most two `defaults write` calls per run.

### Invariants

The task never writes while Rex runs. A second run writes nothing.

### Alternatives

- Put the lines in `install/macos.sh`: rejected, `install.sh` never runs that file.
- Put a script in the `rex` stow package: rejected, `install.sh` has no step that runs it.

## Design decisions

Follow `51_configure_glow_style.sh`: bootstrap, macOS check, skip with a log line, write only when the value differs.

## Integration points

`install.sh` step list. `defaults` and `pgrep` on macOS.

## Files that change

- `install/tasks/52_configure_rex_defaults.sh` — new task.
- `install.sh` — run the new task after the glow step.
- `test/rex_defaults_install_test.rb` — new test with `defaults`, `pgrep` and `uname` stubs.

## Order of work

1. Write the test, run it, watch it fail.
2. Write the task. Make the test pass.
3. Wire the task into `install.sh`.
4. Run the test file, then the full suite and the linters.

## Risks

A Rex that runs during install keeps its old values. The task warns and skips, and a later `./install.sh` run fixes it.

## Proof

- Writes both keys on macOS with Rex stopped → `test/rex_defaults_install_test.rb` `test_both_keys_are_written_when_rex_is_not_running`
- A second run writes nothing → `test/rex_defaults_install_test.rb` `test_a_second_run_writes_nothing`
- Warns and writes nothing while Rex runs → `test/rex_defaults_install_test.rb` `test_nothing_is_written_while_rex_runs`
- Skips outside macOS → `test/rex_defaults_install_test.rb` `test_the_step_skips_outside_macos`
- `install.sh` runs the task after the glow step → `test/rex_defaults_install_test.rb` `test_install_runs_the_task_after_the_glow_step`

Per changed file, the unit tests expected, named as behaviour:

- `install/tasks/52_configure_rex_defaults.sh`: covered by the four task tests above.

Test setup: scratch `$HOME`, stub `defaults`, `pgrep` and `uname` first on PATH. The stub `defaults` keeps its state in a file.

---
Domain skills applied: None.
