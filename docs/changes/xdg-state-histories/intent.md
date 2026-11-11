# Intent: Keep known_hosts and tool histories in XDG state

Author: Etienne van Delden. Status: accepted. Type: chore.

## Problem

SSH wrote `known_hosts` through a symlink into the repo's `ssh/.ssh` directory, next to private keys, and stow warned about the conflict. irb and mysql keep history in `~`, and the irb setting points at a file name irb does not use.

## Proposed outcome

`known_hosts`, the irb history and the mysql history live under `~/.local/state`, outside every stowed tree.

## Constraints

Private keys and `master.key` stay where they are. Etienne moves the existing `known_hosts` himself.

## In scope

- `UserKnownHostsFile ~/.local/state/ssh/known_hosts` in `ssh/.ssh/config`.
- irb history at `~/.local/state/irb/history`; `MYSQL_HISTFILE=~/.local/state/mysql/history`.
- An install step that creates the three directories and copies `~/.irb_history` and `~/.mysql_history` into them when the target is absent.

## Out of scope

Private keys, `master.key`, zsh history, zcompdump, less and python history.

## Acceptance criteria

- `ssh -G github.com` reports the new `userknownhostsfile`.
- irb reports the new `HISTORY_FILE`; a zsh shell exports the new `MYSQL_HISTFILE`.
- The install step creates the directories, copies existing histories without overwriting, and is safe to run twice.

## Decisions

Use `~/.local/state`, the XDG state default. Accepted by "agreed".
