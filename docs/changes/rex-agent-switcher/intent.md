# Intent: Rex agent and terminal switcher

Author: Etienne van Delden. Status: accepted (2026-11-04). Type: feature. Delivery: autonomous. Codex review: no.

## Problem

Etienne is migrating from Herdr to Rex. In Herdr, `prefix+space` opens a panel that lists every agent and terminal and jumps to the one picked. Rex has no such panel. With 22 sessions and more than 60 panes, he cannot find the blocked or finished agent quickly.

## Proposed outcome

A floating panel in Rex lists every pane across all sessions. Etienne filters it to working, blocked or done agents with one key, searches by text, and jumps to the pane he picks.

## Affected users and systems

Etienne, in the Rex app. The Rex config (`init.lua`, Lua actions, a shell script) and the dotfiles repo, which gets a new `rex` stow package.

## Constraints

- Built with Rex's own mechanisms: a Lua `rex.action` that opens a floating `rex.session.new_layer`, as in smnatale/dotfiles `rex/.config/rex`.
- Pane state comes from `program_status` (`working`, `blocked`, `done`, `idle`). A pane that reports nothing is a plain shell.
- Switching sessions from a script needs Remote Control on in Rex settings.
- Approved permissions: a new `rex` stow package in the dotfiles repo. No gems or packages. No migrations. No deploy files. Claude never runs `stow`; Etienne does, after moving `~/.config/rex/init.lua` aside.
- `fzf`, `jq` and `rex` are the tools the script uses; all three are installed.
- Rex's experimental "Group Activity by priority" (`client.sidebar.activity.by_priority`) exists. This change does not use or bind it: it is a sidebar view with no single-key filters, no search across shells, and no floating layout.

## In scope

- A new `rex` stow package holding the current `init.lua` content, the switcher action and its script.
- A floating panel with two modes. List mode: `w` working, `b` blocked, `d` done, `a` all, arrows or `j`/`k` to move, Enter to jump. `/` starts a text search, `esc` returns to list mode.
- Every pane across all sessions, one row each: `state  session / tab  program  cwd  message`. Plain shells show state `shell`. `a` shows all rows, idle agents and shells included.
- Enter selects the session in the app, focuses the tab, then focuses the pane.
- `ctrl+s space` opens the panel. `shift+cmd+k` keeps the built-in `session.switch`.
- Tests that follow the repository's Minitest style, with PATH stubs for `rex`, `fzf` and `jq`.

## Out of scope

- Porting the other Herdr scripts, skills, tests and docs (a separate intent).
- Notifications and status badges in the Rex UI.
- Starting, resuming or closing agents from the panel.
- Running `stow`, or touching `~/.config/rex/`.

## Acceptance criteria

- Pressing `b` in the panel lists only blocked agents.
- Pressing `w` lists only working agents, and `d` only done agents.
- Pressing `a` lists every pane, shells and idle agents included.
- Typing `/` then `caren` lists only rows that mention Caren; `esc` returns to list mode with the same filter.
- Pressing Enter on a pane in another session shows that pane, focused, in the Rex app.
- With no matching pane, the panel shows "No panes match" and Enter does nothing.
- With Remote Control off, Enter prints a one-line hint and the panel stays open.
- If the pane closed after the list was built, Enter shows "Pane no longer exists" and the panel stays open.
- Pressing `ctrl+s space` opens the panel; pressing `shift+cmd+k` still opens the built-in session switcher.
- The new `init.lua` keeps every binding the current one has, except `ctrl+s space`, which now opens the panel.

## Decisions

- Create a `rex` stow package for the Rex config — keeps it version-controlled; recommended option chosen.
- Two modes, list first, with `/` for search — single-key filters would clash with typing a search.
- List every pane, one row each — covers agents and terminals, as Herdr's panel does.
- Enter switches session, window and pane — lands on the exact pane.
- New panel on `ctrl+s space`, built-in stays on `shift+cmd+k` — the Herdr key carries over, the built-in stays reachable.
- Autonomous delivery, Claude reviewer only — Etienne chose autonomous; Codex review declined as the recommended default.
- Keep the floating switcher; leave Rex's built-in Group Activity by priority alone — the built-in covers none of the single-key filters, the search or the floating layout.

## Open questions

None.
