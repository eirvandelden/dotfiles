# Plan: Keep known_hosts and tool histories in XDG state

From `intent.md` (2026-11-11). Status: accepted.

## Design

Not affected: configuration plus one install script, no objects.

## Design decisions

A new install task `54_prepare_state_dirs.sh` follows the Rex task pattern. It creates directories with mode 700 and copies a history file only when the target is absent.

## Integration points

`install.sh` runs the task after `53_configure_rex_defaults.sh`.

## Files that change

- `ssh/.ssh/config` — `UserKnownHostsFile` above the includes.
- `ruby/.irbrc` — `HISTORY_FILE` path.
- `zsh/.config/zsh/environment.zsh` — `MYSQL_HISTFILE`.
- `install/tasks/54_prepare_state_dirs.sh`, `install.sh`, `test/state_dirs_install_test.rb`.

## Order of work

1. Write the test, watch it fail.
2. Write the task and register it.
3. Edit the three config files.
4. Run the checks.

## Risks

A missing directory makes ssh fail to record hosts; the install task prevents that. Work configs may set their own `UserKnownHostsFile`; they are out of sight.

## Proof

- Directories created, histories copied, no overwrite, idempotent → `test/state_dirs_install_test.rb`.
- ssh, irb and mysql settings → check: `ssh -G github.com | grep userknownhostsfile`, `irb -e 'p IRB.conf[:HISTORY_FILE]'`, `zsh -ic 'echo $MYSQL_HISTFILE'`.

Per changed file:
- `install/tasks/54_prepare_state_dirs.sh`: creates three directories, copies existing histories, skips an existing target.

Test setup: scratch `$HOME`.

---
Domain skills applied: None.
