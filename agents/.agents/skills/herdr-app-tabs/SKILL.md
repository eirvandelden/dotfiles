---
name: herdr-app-tabs
description: Use when an agent opens a tab, a pane beside itself or a terminal in herdr-app — which command to run, in which core, and what never to run (the herdr TUI, `HERDR_ENV`, the stale herdr-gpui-browser and herdr-automations skills).
---

# Open tabs in herdr-app

herdr-app is the only terminal app. Open a tab with `herdr-app-pane`. It opens the tab in the core your own terminal runs in, whatever space has focus.

## When

- Open a tab only inside herdr-app: `HC_TERMINAL_ID` is set. Outside herdr-app, open no tab.
- Open one only for a reason that Etienne can see, such as a log to follow or a second shell.

## Open a tab

```bash
herdr-app-pane tab "<folder>" --name "<name>" [-- <command>...]
```

- The tab opens in your own space, rooted in `<folder>`. It runs `<command>`, or the default shell when you give none.
- The tab does not take focus. Tell Etienne the tab's name.
- The command prints the hc address of the new terminal, such as `t61`.
- A refusal prints one line and exits 1. Report that line. Do not retry with another tool.

## Open a pane beside you

```bash
herdr-app-pane open "<folder>" [-- <command>...]
herdr-app-pane close [<terminal>]
```

`open` splits a pane beside the coordinator. `close` closes the pane of a terminal, by default your own. The pipeline scripts call both; run them by hand only when a task asks for a pane.

## Your own core

- `HC_SESSION=work` is the work core.
- `HC_SESSION` unset, empty or `default` is the personal core.
- `herdr-app-pane` reads `HC_SESSION` itself. Pass no core and no space.

## Never

- Never run `herdr pane`, `herdr tab` or any other `herdr` command. The old herdr TUI serves no herdr-app terminal.
- Never read `HERDR_ENV` or `herdr-automate`. Never follow the stale skills `herdr-gpui-browser` and `herdr-automations`.
- Never run a bare `herdr-app do tab.new` without `space`. It opens the tab in the focused space, which can be the wrong core.
- herdr-app has no browser tab. Give Etienne the URL or the file path instead.
