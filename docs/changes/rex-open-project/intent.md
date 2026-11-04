# Intent: Open a project session in Rex from the keyboard

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature. Delivery: autonomous. Codex review: no.

## Problem

Etienne cannot jump to a project from inside Rex. Each project session is opened by hand: create a session, set its directory, name it. Rex has no project picker.

## Proposed outcome

The key sequence `ctrl+s` then `o` opens a floating fuzzy picker of git repositories under `~/Developer` and `~/Sites`. Picking one opens a Rex session in that folder, labelled with the folder name, and switches to it. If a session with that label is already open, Rex switches to it instead.

## Affected users and systems

Etienne's Rex app on macOS. The dotfiles repository: new files in `rex/.config/rex/` and one binding line in `init.lua`.

## Constraints

- No new dependency: `fzf` and `jq` are already installed.
- The `rex` stow package already exists in the branch `rex-agent-switcher`, with its `init.lua` and its `packages.conf` entry. This branch stacks on `rex-agent-switcher`: it rebases onto that branch, and its PR targets that branch until it merges. No new stow package is created here.
- The `rex-prefix-keybindings` change also edits `init.lua`. Expect an overlap there and resolve it on its merits.
- The switcher in `rex-agent-switcher` already ships a session-jump script. The plan reuses it for the session switch when it fits, instead of adding a second one.
- Agents never run `stow` (playbook rule 12).
- Switching the app to a session needs Remote Control on in Rex Settings > Rex Server. Without it, the picker still creates the session and prints a hint.
- The prefix is `ctrl+s`, matching the other Rex bindings.

## In scope

- A palette action `open_project` that opens a floating pane running the picker script, in the focused pane's directory.
- A binding `ctrl+s>o` for that action in `init.lua`.
- A picker script that lists the folders directly under `~/Developer` and `~/Sites` that hold a `.git` entry.
- Session reuse by label: open a session when none has that label, otherwise switch to it.
- A way to switch the Rex app to a session, reusing the switcher's jump script when it fits.
- `.luarc.json`, so the Lua language server knows the `rex` global.

## Out of scope

- Scratch terminal, Lazygit, fork-Claude and open-in-Finder actions.
- Worktree create, open and remove actions: worktrees come from the `worktree-first` skill.
- Bare repositories, folders without `.git`, and folders nested deeper than one level.
- Two folders with the same name in different directories: they share one session.
- Creating the `rex` stow package, running `stow`, or touching `~/.config/rex` directly.

## Acceptance criteria

- Pressing `ctrl+s` then `o` opens a floating picker.
- The picker lists `dotfiles` from `~/Developer` and `eirvandelden.github.io` from `~/Sites`.
- The picker does not list `conductor`, `private` or `archive`, which have no `.git` entry.
- Picking `dotfiles` when no session is labelled `dotfiles` creates one in `~/Developer/dotfiles` and switches to it.
- Picking `dotfiles` when a session labelled `dotfiles` is open switches to it and creates no second session.
- Pressing Escape in the picker closes it and creates nothing.
- With Remote Control off, picking a folder creates the session and prints a hint to switch by hand.

## Decisions

- The session label is the folder name — Etienne chose "use the folder name"; no reason given.
- The picker lists only git repositories — Etienne chose it over listing every folder; no reason given.
- The picker also covers `~/Sites` — Etienne asked to add it.
- The binding is `ctrl+s>o` — Etienne chose the prefix form over `cmd+o`; no reason given.
- Delivery is autonomous, with Claude-only review — Etienne chose both; no reason given.
- The `rex` package comes from the `rex-agent-switcher` branch, so this branch stacks on it — Etienne said the package is there; no reason given.

## Open questions

None.
