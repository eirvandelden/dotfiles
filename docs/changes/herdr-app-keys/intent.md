# Intent: Move from herdr TUI to herdr-app, work and personal apart

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-10). Type: feature. Delivery: autonomous. Codex review: no.

## Problem

Etienne keeps work and personal apart with two herdr TUI sessions, `default` (19 personal workspaces) and a work session (5 work workspaces), each in its own Ghostty or Rex tab. herdr-app, the Herdr desktop app on herdr-core, offers what the TUI lacks: a sidebar on the right and multi-key sequences for a `;` leader. Today it is not usable as his daily tool:

- Its config (`keys.json`, `settings.json`) lives only on this Mac, outside the dotfiles repository, and holds macOS-only paths. A fresh Mac or Steam Deck gets neither the app nor the config.
- It shows one herdr-core session, so work and personal terminals mix in one list.
- None of his herdr TUI shortcuts, commands or looks exist there.
- The agent pipeline (stage panes, review panes, worktree panes and viewer) drives only the herdr TUI and Rex.

Every step of the move must be written down, so it does not depend on an agent remembering it.

## Proposed outcome

Etienne works in herdr-app on macOS and SteamOS, in one window. Personal and work each have their own herdr-core session and their own foldable sidebar group, and his former TUI workspaces exist there as spaces. A `;` leader gives him his TUI shortcuts and commands. The sidebar sits on the right, colors follow solunized, and personal and work look different at a glance. Stage, review and worktree panes open in herdr-app. All of it is tracked in a `herdr-app` stow package and installed by the installer. The herdr TUI stays installed as a fallback.

## Phases

Five phases, in this order. Each phase ships as its own pull request, and the next phase starts only after the previous one merges.

1. Stow package: the config in the dotfiles repository, and the app installed on macOS and SteamOS.
2. Cores: two herdr-core sessions as sidebar groups, and the TUI workspaces migrated.
3. Keys: the `;` leader and the TUI shortcuts and commands.
4. Look: the sidebar on the right, the solunized theme, colors per session, TUI pane frames.
5. Pipeline: herdr-app as a third pane backend for the agent pipeline, next to herdr TUI and Rex.

Phase status: phase 1 shipped in PR #275 (merged 2026-11-10), after PR #273 removed `bundler` from `STOW`. Phase 2 shipped in PR #277 (merged 2026-11-10); its restore ran on 2026-11-11 through a one-time agent handoff. This branch, `herdr-app-keys`, carries phase 3. Each later phase copies this file from the last phase's history into its own change folder.

## Affected users and systems

- Etienne, on this Mac and on any fresh Mac or Steam Deck the installer sets up.
- herdr-app (0.1.13 here, 0.1.14 released) and its home, `~/.config/herdr-app`.
- herdr-core (`hc`) 0.1.18: session `default` (20 spaces, 78 live terminals today) and session `work` (exists, empty).
- The herdr TUI sessions `default` and the work session, as the source of the migration.
- `packages.conf` (`BREW_MACOS`, `STOW`, `STOW_SHARED`) and the installer tasks.
- The agent pipeline: `hand-off-plan`, `start-review`, `deliver`, `open-pr-dash`, `worktree-create`, `worktree-pane`, `worktree-viewer`, the stage skills, and their tests.
- The solunized repository (`~/Developer/solunized`), for the herdr-app theme template.

## Constraints

- herdr-app writes its own files into `~/.config/herdr-app`: `view.json`, `window.json`, `shared.json`, `data/`, `seen.json`, `installed.json`, `frame/`, `icons/`, `AGENTS.md`, the shipped mods, layouts and themes. None of these is tracked. By default the package links file by file (`STOW_SHARED`).
- `keys.json`: herdr-app treats an edited file as Etienne's and stops adding new default shortcuts to it. Phase 3 edits it, so new herdr-app defaults are added by hand after that.
- The Linux release is a tarball per architecture, listed with its sha256 in `https://releases.herdr.dev/app/latest.json`. The cask requires macOS on arm64.
- `;` leader: herdr-app loads bindings through GPUI's `KeyBinding::load`, which accepts sequences such as `"; t"`, and its terminal receives replayed prefixes (`src/terminal.rs` in herdrdev/herdr-app). Typing `;` and then a bound key quickly fires the binding. A `;` followed by a space or Enter is never bound.
- Running programs cannot move from the herdr TUI to herdr-core. Migration recreates names and folders, and resumes each agent's own session by its id while the TUI agent still runs. Until Etienne quits the TUI agent, one session has two writers; nobody types in either copy meanwhile.
- A herdr-core restart (an update, a reboot) gives every kept terminal a fresh shell and ends its agent. The 2026-10-30 import into herdr-core `default` lost its agents that way on 2026-11-05.
- Closing a space ends its programs and cannot be undone.
- The dotfiles repository is public: no work names in tracked files (the work TUI session name and work folders are arguments or live in `dotfiles-work`), and no MonoLisa font files (a paid font).
- Etienne types Dvorak; key instructions name the arrow keys, never `hjkl`.
- Never stop a herdr-core session, herdr TUI session or server Etienne started.
- Approved permissions:
  - Phase 1: add the `herdr-app` cask to `BREW_MACOS`, and an installer task that downloads the Linux tarball (rule 11).
  - Every phase: stow or restow the `herdr-app` package on this Mac in its delivery step, with `-t "$HOME"`. In phase 1, move the current local files aside with `trash` first (rule 12).
  - Phase 2: start the `work` herdr-core session and register it with herdr-app; run the migration script on this Mac.
  - Phase 4: a pull request in the solunized repository for the herdr-app theme template.

## In scope

### Phase 1: stow package

- A new `herdr-app` stow package with `.config/herdr-app/keys.json` and `.config/herdr-app/settings.json`, moved from this Mac.
- `herdr-app` in `STOW`, and in `STOW_SHARED` unless the fallback below applies.
- The `herdr-app` cask in `BREW_MACOS`.
- An installer task for SteamOS: install herdr-app from the Linux release tarball, check its sha256, and do nothing when the app is already installed.
- A portable `settings.json`: the sound paths resolve under each machine's home. The font stays MonoLisa.
- Finding out whether herdr-app keeps a linked file linked when it saves a setting from its settings dialog. Fallback: if a save replaces the link with a plain file, link the whole `~/.config/herdr-app` folder into the package instead, and gitignore every file Herdr writes.
- The `CLAUDE.md` package list and the dotfiles docs that list packages.

### Phase 2: cores

- herdr-core `default` holds personal; herdr-core `work` holds work.
- One herdr-app window shows both, as two foldable sidebar groups, named "personal" and "work". The personal name comes from a cloned `spaces` mod, shown by a cloned `main` layout; phase 4 builds on both clones.
- An installer task that starts the work core and registers it with herdr-app, idempotent, on macOS and SteamOS.
- Before the migration: Claude lists the stale herdr-app spaces from the 2026-10-30 import and closes them all after Etienne approves the list.
- A migration script that reads the herdr TUI workspaces, tabs and panes of a given session and builds them fresh in a given herdr-core session, with the same names and folders. It skips a workspace whose name already exists as a space. Etienne runs it once per side; the session names are arguments.
- Agent sessions: the script reads each TUI pane's `agent_session` (`herdr agent list`). It resumes exactly that session in the matching new pane, while the TUI agent still runs: `claude --resume <id>` or `codex resume <id>`. Then it lists every TUI pane next to its herdr-app pane for Etienne to check. Etienne quits each TUI agent himself after checking; the script never ends a program.
- Documented recovery: how agents come back after a herdr-core restart.

### Phase 3: keys

- `;` as a leader in both the `global` and `terminal` sections of `keys.json`, and `; ;` types a `;`.
- First, verify in the running app that sequences work in a terminal and that an unbound `;` still reaches the program.
- The proposed key map below, as Etienne corrects it. herdr-app's own `cmd-…` defaults stay.
- `keys.json` also works on Linux: the Steam Deck gets bindings that do not depend on the macOS `cmd` key.
- The herdr-app cores runbook (`agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md`) says `layout.switch --name cores`, and says to start, restart or stop an hc core only from a plain terminal, never from an agent shell or a `!` command.

| Keys | herdr-app action | herdr TUI today |
| --- | --- | --- |
| `; ;` | type `;` | none |
| `; t` | new tab | prefix `c` |
| `; 1`…`; 9` | show tab 1–9 | prefix `1`…`9` |
| `; shift-1`…`; shift-9` | show space 1–9 | prefix `shift+1`…`9` |
| `; n` / `; p` | next / previous tab | prefix `n` / `p` |
| `; ]` / `; [` | next / previous space | none |
| `; a` / `; shift-a` | next / previous agent | prefix `alt+1`…`9` |
| `; d` | list of done agents; Enter goes to the picked one | prefix `space`, then `d` |
| `; b` | list of blocked agents; Enter goes to the picked one | prefix `space`, then `b` |
| `; left`, `; right`, `; up`, `; down` | focus pane in that direction | prefix arrows |
| `; shift-` + arrow | swap pane in that direction | none |
| `; v` | split right | prefix `v` |
| `; -` | split down | prefix `-` |
| `; x` | close pane | prefix `x` |
| `; shift-x` | close tab | prefix `shift+x` |
| `; z` | zoom pane | prefix `z` |
| `; shift-b` | toggle sidebar | prefix `b` |
| `; w` | close pane, or the tab when it is the last pane | none |
| `; space` | picker: go to any tab, or start new work (outside terminals only; in a terminal, `cmd-p`) | prefix `w`, prefix `space` |
| `; shift-n` | new space | prefix `shift+n` |
| `; shift-w` | rename space | prefix `shift+w` |
| `; shift-t` | rename tab | prefix `shift+t` |
| `; shift-d` | close space | prefix `shift+d` |
| `; f` | Files panel | prefix `f` (worktree-viewer split) |
| `; shift-f` | Files in its own tab | prefix `shift+f` |
| `; g` | lazygit split right | prefix `g` |
| `; shift-g` | lazygit in its own tab | prefix `shift+g` |
| `; /` | search the terminal | none |
| `; shift-p` | command palette | none |
| `; ?` | keys help | prefix `?` |
| `; ,` | settings | prefix `s` |

Direct chords repeat the moves Etienne makes many times in a row: hold `ctrl+alt+cmd` once and press the key again and again. Each chord runs the same action as its leader twin. On Linux `cmd` is Super, so `; ` + arrow stays the Super-free path.

| Keys | herdr-app action | Leader twin |
| --- | --- | --- |
| `ctrl-alt-cmd-` + arrow | focus pane in that direction | `; ` + arrow |
| `ctrl-alt-cmd-shift-` + arrow | swap pane in that direction | `; shift-` + arrow |
| `ctrl-alt-cmd-n` / `ctrl-alt-cmd-p` | next / previous tab | `; n` / `; p` |
| `ctrl-alt-cmd-]` / `ctrl-alt-cmd-[` | next / previous space | `; ]` / `; [` |
| `ctrl-alt-cmd-a` / `ctrl-alt-cmd-shift-a` | next / previous agent | `; a` / `; shift-a` |

### Phase 4: look

- The whole current sidebar, with its spaces list and agents list, moves from the default left side to the right, in a cloned `main` layout.
- A solunized herdr-app theme, light and dark, generated from a new template in the solunized repository (its own pull request there, first).
- The herdr TUI's cards-on-frame look: pane gaps, frame color, accent border on the focused pane.
- Personal shows a blue accent and work an orange accent, both from solunized, following the focused space's core. Every work space has the same fixed sidebar color.
- Fallback, if herdr-app cannot change the accent per space: work always shows dark mode, and personal follows the system. If herdr-app can do neither, stop and ask Etienne.

### Phase 5: pipeline

- herdr-app as a third pane backend for the agent pipeline, next to herdr TUI and Rex, with the same behaviour: stage panes, review panes, worktree panes, the worktree viewer, `open-pr-dash`, sending the final line back to the coordinator, closing idle stage panes, and the tones.
- The backend is picked from the environment, as herdr TUI and Rex are today.
- Tests for the new backend, next to the existing herdr TUI and Rex tests.

## Out of scope

- Tracking `view.json` and `window.json`: they hold this machine's selected spaces and window spot, and Herdr rewrites them on every click.
- Installing MonoLisa and the herdr tone files on SteamOS. Ghostty and Zed already need MonoLisa there too.
- Moving running programs or scrollback from the herdr TUI.
- Removing the herdr TUI, its `herdr` package, its Homebrew formula or its plugins: it stays as a fallback.
- Porting the five herdr TUI plugins (session title, auto-retry, Ghostty tab title, file viewer, golden ratio) beyond what phase 3 and phase 5 name.
- Replacing this Mac's manual Herdr install with the cask, and running the installer here.
- A work environment beyond the sidebar color: git identity already follows the remote, and work shells need no other variables.

## Acceptance criteria

### Phase 1

- After delivery on this Mac, `~/.config/herdr-app/keys.json` and `~/.config/herdr-app/settings.json` resolve into the dotfiles repository, and herdr-app still uses MonoLisa and plays the herdr tones.
- Changing the font in the repository's `settings.json` changes the running window's font within about 10 seconds, the herdr-app poll interval.
- Changing a setting in herdr-app's settings dialog shows up as a diff in the dotfiles repository.
- With herdr-app running for a while, `git status` in the dotfiles repository shows no file Herdr wrote.
- On a fresh Mac, the installer installs Herdr and links both files.
- On a fresh Steam Deck, the installer installs herdr-app from the Linux tarball and links both files. A second installer run downloads nothing.
- On a Steam Deck with the tone files present, herdr-app plays the same tones as the Mac, from the same `settings.json`.

### Phase 2

- herdr-app shows two sidebar groups, "personal" and "work", and each one folds away.
- A new space made while a work space has focus lands in the work core, and `hc ls` in a personal shell does not list it.
- After the migration, every herdr TUI workspace has a space with the same name and folder, on the right side. A second run makes no new spaces.
- The stale herdr-core spaces close only after Etienne approves the list.
- After the migration, every former herdr TUI Claude or Codex pane runs the same conversation, with the same session id, in herdr-app.
- The script prints each TUI pane next to its herdr-app pane, and ends no TUI agent.
- On a fresh machine, the installer leaves the work core registered, and a second run changes nothing.

### Phase 3

- `; t` opens a new tab, from a terminal and from the sidebar.
- `; w` in a tab with two panes closes the focused pane; `; w` in a tab with one pane closes the tab.
- `; space` from the sidebar opens the picker; `; space` in a shell types `; `.
- With two done agents and one blocked agent, `; d` lists only the two done agents and `; b` only the blocked one; Enter on a row shows that agent.
- In a shell, `; ;` types one `;`, and `echo a; echo b` runs unchanged.
- Every row of the key map does what it says.
- On the Steam Deck, the `;` leader keys work, and no herdr-app action needs the Super key.

### Phase 4

- The sidebar with the spaces list and the agents list sits on the right of the window, not on the left.
- herdr-app's colors match Ghostty's solunized colors in light and dark mode.
- Focus on a personal space shows the blue accent; focus on a work space shows the orange accent (or, with the fallback, dark mode).
- Panes look like cards on a frame, as in the herdr TUI.

### Phase 5

- `implement handoff` in a herdr-app terminal opens the stage pane in herdr-app, and its final line comes back to the coordinator.
- `review` opens its review pane in herdr-app.
- `worktree-create` opens a pane rooted in the new worktree in herdr-app.
- The existing herdr TUI and Rex tests stay green.

## Decisions

- Name the change `herdr-app`, with no GitHub issue — Etienne's choice.
- One intent with five phases, not separate changes — "it relies on you; I don't like that".
- Ship one pull request per phase, in order: package, cores, keys, look, pipeline — each phase builds on the files of the one before.
- Deliver autonomously, without a Codex review, and settle the keys in this interview — Etienne's choice.
- Track `keys.json` and `settings.json` — they are the only files Herdr does not write.
- Keep `view.json` and `window.json` untracked — per-machine runtime state that changes on every click.
- Add the `herdr-app` cask to `BREW_MACOS` — the package is useless without the app.
- Use herdr-app on macOS and SteamOS; install it from the Linux tarball there — same outcome on both systems.
- Make `settings.json` portable and keep MonoLisa on both systems — one file for both; no visual change on the Mac.
- If herdr-app replaces a linked file on save, link the entire folder instead — "configuration is held in my dotfiles repo".
- Run stow in each phase's delivery step — Etienne approved it.
- herdr-core `default` is personal, `work` is work — the work session already exists.
- The only work environment is a fixed sidebar color for work spaces — Etienne's choice; git identity already follows the remote.
- Migrate TUI workspaces by script, names and folders only — running programs cannot move.
- Close the stale herdr-core spaces from the 2026-10-30 import, after Etienne approves, then migrate fresh — Etienne's choice; the import's agents were already lost.
- Restore each agent's own Claude or Codex session in its matching pane, by session id — "restore the correct claude and codex sessions in each matching panel".
- herdr-core stays herdr-app's to install and update; the installer only warns when `hc` is missing — herdr-app manages core versions itself.
- Name the personal sidebar group "personal" in phase 2, through a cloned `spaces` mod — Etienne's choice; the clone gets no Herdr updates.
- Claude may update the work core with `hc machine update` only while it holds 0 terminals; otherwise stop and ask — no running program can end.
- Resume each session in herdr-app while its TUI agent still runs; Etienne quits the TUI agent after checking the resumed one — "so I can manually check it went ok". Same session id, not a fork — Etienne's choice, with two writers until the TUI agent quits.
- `;` is the leader everywhere, and `; ;` types a semicolon — Etienne's choice; sequence support checked in the herdr-app source.
- `; w` closes the pane, or the tab when it is the last pane — Etienne's choice.
- `; space` opens the picker, outside terminals only — `; ` is common in shells and code, so typing stays unchanged.
- `; d` and `; b` open lists of done and blocked agents, from a cloned picker — Etienne uses `ctrl+s space d` and `ctrl+s space b` a lot; the clone gets no Herdr updates.
- Look: solunized theme, a fixed color for work spaces, TUI pane frames, blue accent for personal and orange for work; fallback work dark always and personal following the system — Etienne's words.
- Add the agent pipeline as a third backend; keep the herdr TUI installed as a fallback — herdr-app is at 0.1.x.
- Accept about 10 seconds (measured 9.9–10.5 s in Etienne's window, the poll interval plus check overhead) as meeting phase 1's reload criterion — Etienne accepted it on 2026-11-10.
- Accept up to 10 seconds for a repository edit of `settings.json` to reach the running window — herdr-app's watcher misses edits through a link and polls every 10 seconds; settings edits are rare.
- Until phase 3, the Steam Deck uses the macOS `keys.json`; phase 3 adds Linux bindings — phase 3 rewrites `keys.json` anyway.
- The plans of phases 2–5 get a Codex critique with `gpt-6.1-sol` at medium effort — the playbook's §7a now names that model, so no playbook change is needed.
- `; shift-b` toggles the sidebar and `; b` stays the blocked-agents list — Etienne's choice on 2026-11-11; the map had `; b` twice.
- The phase 3 plan gets a Claude critique instead of the Codex one — Etienne's choice; the Codex critique took over 10 minutes.
- The two runbook fixes ship in phase 3 — Etienne's choice; same runbook, small edit.
- Never start, restart or stop an hc core from an agent shell: it copies the agent's CLAUDE_* variables into every terminal — learned on 2026-11-11, when resumed agents stopped saving transcripts.
- The herdr-app leader stays `;`; Neovim's leader moves to space, and `ctrl+alt+cmd` chords repeat pane, tab, space and agent moves — Etienne, 2026-11-11, after the review found Neovim's `;` leader clashed.

## Open questions

None.
