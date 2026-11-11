# Probe: herdr-app 0.1.15 and hc 0.1.20 in a sandbox window

Run on 2026-11-11 in a sandbox window (`HERDR_APP_HOME=/private/tmp/claude-502/hac5h`, `HC_SESSION=hac5`), started under `env -i`. Plan step 1.

## Window

- `HERDR_APP_HOME` must be short: the window's socket is `<home>/herdr-app.sock`, and a long scratch path fails with `path must be shorter than SUN_LEN`.
- `herdr-app status` → `{"space", "tab", "focused_pane", "layout", "agent", "floats", "overlays", "errors", ...}`. The focus key is `focused_pane` (a pane id, or `null`).
- `herdr-app ls` → `{"spaces":[{"id","name","folder","machine":null,"active","tabs":[{"id","name","active","settled","terminals":[{"terminal","pane","status","app","name","sub_agents"}]}]}],"recent":[]}`. A claude terminal shows `"status":"done","app":"claude-code"`; a shell shows `"status":null,"app":null`.
- `herdr-app do pane.split '{"direction","pane","argv"}'` → `{"pane","terminal"}`. The split takes focus: `focused_pane` becomes the new pane. `herdr-app do pane.focus '{"pane":"<old>"}'` → `{"ok":true}` gives it back.
- `herdr-app do pane.close '{"pane"}'` → `{"ok":true}`; an unknown pane → `{"error":"no pane \"<id>\""}` and exit 1.
- Terminals in the sandbox window inherit `HERDR_APP_HOME`, `HC_SESSION`, their own `HC_TERMINAL_ID` and the sandbox core's `HC_TERMINAL_SOCKET`, so scripts run there target the sandbox window and core.

## hc

- `hc get <t> --json` for a claude started by `pane.split` with a first prompt: `{"state":"live","exit_code":null,"status":{"app":"claude-code","state":"done"},"foreground":{"argv":["claude",...],"cwd":"<the cd target>"},"cwd":"<the spawn folder>"}`. Top-level `cwd` is the folder the terminal was spawned in (the focused pane's), not the `cd` target: compare `foreground.cwd` first.
- Before claude reports, `status` is `null`. A folder-trust dialog keeps it `null`.
- Terminals are kept (`keep`): when claude exits, the pane gets a login shell and `state` stays `live`. A failed start therefore shows as `status: null` with a shell in the foreground, never as `finished`.
- `hc ls --json` → `{"terminals":[{"address","status":"done"|"idle"|"working"|null,...}]}`.
- `hc server status` starts a core that is not running. Never call it to check a core: read `ps` instead.

## Claude

- A folder that is not trusted shows the trust dialog before the first prompt runs. `~/Developer` is trusted, so worktrees under it start without the dialog.
