# herdr-app cores: work and personal, and the migration from the herdr TUI

herdr-app shows one herdr-core session per window. Personal is the `default` core. Work is the `work` core, which the `default` core knows as the machine `work`. herdr-app groups spaces by machine, and each group folds.

## The work core

Task `install/tasks/27_register_work_core.sh` starts the `work` core and registers it with the `default` core: `HC_SESSION=default hc machine add --via 'sh -c' --name work --session work`. `hc server status` starts a core that is not running, so a status call is also a start. The task never stops a core. It restarts one only through `hc machine update work`, and only when the work core holds no live terminal. With a live terminal it stops and names the count. A `work` machine with another session or transport is never replaced. Change it by hand. On a fresh machine `hc` arrives with herdr-app's first open. Open herdr-app once, then run `install/tasks/27_register_work_core.sh` or the installer again. If the work machine shows `unreachable`, the `default` core's PATH lacks `~/.local/bin`. Try `--via 'sh -lc'`.

## The cores layout

The package holds a clone of the `spaces` mod, `spaces-cores`, which labels the local group "personal", and a clone of the `main` layout, `cores`, which uses it. The window shows it after `herdr-app do layout.switch --name cores`. Run that once per machine. Herdr rewrites `jsconfig.json` and the `.d.ts` files in a mod folder on every start, so `.gitignore` leaves them out.

## Stale spaces

`herdr-app-migrate stale --machine ''` lists the live spaces of this computer. `recent` entries are not listed. Etienne approves the list. Then `herdr-app-migrate close --machine '' <id>…` closes only those ids, or nothing. Close them before the first `build`, or `build` skips their names.

## Migration, per side

1. `herdr-app-migrate build --tui <session> --machine '' --dry-run` previews every space, tab, split and start command, and sends nothing. Use `--machine work` and the work TUI session for the work side.
2. Run it again without `--dry-run`. It reads the whole TUI session and checks every layout first, so a refused layout creates nothing. It skips a workspace whose name is already a space on that machine, so a second run creates nothing. It prints one line per TUI pane: space, tab, TUI pane, herdr-app pane, and `claude <id> started`, `codex <id> started` or `shell`.
3. A failure after a space exists names that space and its id. Approve closing it, close it, and run again.
4. Etienne checks each resumed agent against its TUI pane, then quits each TUI agent himself. Until then one session runs in two processes. Type in neither copy.

Ratios of splits are not kept, and running programs and scrollback do not move.

## After a core restart

A core restart ends every agent. Every kept terminal gets a shell in its last folder. In each agent pane run `claude --resume` or `codex resume` there and pick the session, or use the id from the pairing list.

## Starting and stopping cores

Start, restart or stop a core only from a plain terminal, never from an agent shell or a `!` command. The core holder copies the environment of the shell that starts it, so its `CLAUDE_*` variables then reach every terminal the core runs.

## The leader and the agent lists

`keys.json` adds a `;` leader sequence for every herdr-app shortcut, such as `; t` for a new tab and `; space` for the `picker` mod. The `cmd-…` and `ctrl-…` bindings stay. In a terminal, `; ;` types a `;` and `; space` types a semicolon and a space. The leader also fires in a terminal: a `;` followed by a bound key runs that binding, so `ls;pwd` runs `tab.prev` at `; p`. A typed `;;`, as in a shell `case` arm or `for(;;)`, arrives as one `;`. Type `; ; ; ;` to get `;;`. In a herdr-app text input, such as a tab name, a `;` followed by a bound key fires that binding, and `; ;` types nothing. `; d` lists the done agents and `; b` the blocked ones, from the `agents-done` and `agents-blocked` mods. Both load one `main.js`, and each `mod.json` names its status. After a change to `keys.json`, check that `$HERDR_APP_HOME/keys.error` does not exist and that `herdr-app status` names no keys error. One bad binding drops every binding in the window.
