# Intent: Retire herdr TUI and Rex from the agent workflow and the repository

Author: Etienne van Delden. Status: accepted. Type: refactor. Delivery: autonomous. Codex review: no.

## Problem

Etienne moved from herdr TUI to herdr-app. PR #279 (`herdr-app-pipeline`) already gave the stage hand-off an `hc` path: `HC_TERMINAL_ID` picks `herdr-app/.config/herdr-app/scripts/{hand-off-plan,start-review,open-pr-dash}.sh`, and `deliver` and `worktree-pane` use `herdr-app-pane`. The herdr TUI and Rex paths stay beside it: dispatcher branches, `herdr` and `rex` packages, `rex_panes.rb`, viewer scripts, allow rules, hooks, bindings, tests and skill text. Every agent and every reader must still pick the right branch, and the dead branches can no longer be exercised.

## Proposed outcome

`hc` is the only transport. The dispatchers, `deliver`, `worktree-create`, `worktree-pane` and the six stage skills know only `HC_TERMINAL_ID`. The `herdr` and `rex` packages are gone from the repository and from `packages.conf`, with every config, hook, allow rule and binding that points at them. `herdr-app` and `hc` stay.

## Affected users and systems

- Etienne and every agent session started from herdr-app.
- Dispatchers in `agents/.agents/bin/`, the `herdr` and `rex` packages, `agents/.agents/skills/deliver/scripts/{deliver,rex_panes.rb}`, the worktree tools (`worktree-create`, `worktree-pane`, `worktree-pane-rex`, `worktree-viewer`, `worktree-viewer-rex`, `lib/common.rb`, `lib/agent_worktree.rb`, README), `github/.config/gh-dash/config.yml`, `claude/.claude/settings.json`, `codex/.codex/config.toml`, `packages.conf`, `README.md`, `SKILLS-INDEX.md`, the skills `intent`, `plan`, `implement`, `review`, `deliver`, `finish`, `worktree-first`, `dotfiles-maintenance`, and their tests.
- `core-values.yml` and `PLAYBOOK.md`, only if a mirrored rule changes.

## Constraints

- Edit sources in `~/Developer/dotfiles/<package>/`, never the symlink targets. No `stow`, no new stow package.
- Playbook rules apply: worktree from `worktree-create`, one logical change per commit, every touched file linted, no linter disables, tests for code changes.
- Reports and records stay where main already writes them, `<git-common-dir>/herdr-app/`. Stage models stay as they are (playbook rule 24).
- Approved permissions: touching `.github/workflows/` if a test needs it, and removing `go` from the BREW list in `packages.conf` (playbook rule 11). Everything else (gems, system tools, dropping migrations, deploy files) is a stop-and-ask.

## In scope

- Remove the herdr TUI and Rex branches from `agents/.agents/bin/{hand-off-plan,start-review,open-pr-dash}`; they pick `hc` or fail naming `HC_TERMINAL_ID`.
- Remove `rex_panes.rb` and the herdr TUI and Rex code from `deliver`, `worktree-create`, `worktree-pane` and their README.
- Delete `worktree-pane-rex`, `worktree-viewer`, `worktree-viewer-rex`, `lib/agent_worktree.rb`, and the herdr TUI and Rex code in `lib/common.rb`.
- Retire the `herdr` and `rex` packages: delete their files, their `packages.conf` entries (including the herdr plugin list and the Rex launch agent) and every hook, allow rule, binding and gh-dash entry that points at them.
- Remove or rewrite their tests, and delete tests that only cover removed code.
- Update the skills, `README.md`, `SKILLS-INDEX.md` and `PLAYBOOK.md` wording to name `HC_TERMINAL_ID` and the terminal address.
- Remove the herdr TUI mentions that sit in herdr-app files: `herdr-app-migrate`, the runbook `herdr-app-cores.md`, and the glossary terms herdr TUI, Pairing, Running agent and Workspace. This removes the migration tooling; no replacement is planned.
- Remove `go` from the BREW list in `packages.conf`.
- Add the six terms (Terminal, Terminal address, Coordinator, Stage terminal, Worktree terminal, Terminal name) to `GLOSSARY.md` in a separate commit.
- A test that fails while any tracked file outside `docs/changes/` mentions `HERDR_PANE_ID`, `herdr pane` or `REX_SESSION`.

## Out of scope

- Moving the report directory: it stays `<git-common-dir>/herdr-app/`.
- Any change to herdr-app, `hc`, the stage models or the stage prompts.
- Porting the retired viewer keys to herdr-app.

## Acceptance criteria

- With `HC_TERMINAL_ID` unset, `hand-off-plan`, `start-review` and `open-pr-dash` exit 1 with a message that names `HC_TERMINAL_ID`.
- With `HC_TERMINAL_ID` set, a plan hand-off starts a worker terminal for the change's worktree, and its `Plan ready: <path>` line reaches the coordinator terminal.
- Delivery closes the change's idle stage terminals and leaves the intent terminal open.
- `packages.conf` lists neither `herdr` nor `rex`, and the repository has no `herdr/` or `rex/` directory.
- No tracked file outside `docs/changes/` mentions `HERDR_PANE_ID`, `herdr pane` or `REX_SESSION`.
- `bin/test` and every linter pass.

## Flagged concerns

- Dangling links: removing the packages leaves links in `~/.config/herdr`, `~/.config/rex` and `~/.config/git/worktree-tools` that `stow -R` does not clean. Side chosen: the delivery account lists them for Etienne to trash; no agent runs `stow` or deletes links.

## Decisions

- Main already holds the `hc` path from PR #279, so this change shrinks to removal and cleanup — Etienne: "main moved", then "go".
- Retiring the `herdr` and `rex` packages is in scope of this change, not a separate one — Etienne: "retiring herdr and rex are in scope of this change"; no further reason given.
- Widen the removal to every file that mentions herdr TUI or Rex, not only the agent workflow — no reason given.
- Reports stay in `<git-common-dir>/herdr-app/`, where main already writes them; the old intent text said `herdr/` — Etienne: "Keep herdr-app/ and correct the intent".
- Remove the herdr TUI mentions in herdr-app files too, with no exception, and drop `go` from BREW — no reason given.
- Add the six new terms to `GLOSSARY.md` in a separate commit — no reason given.
- Autonomous delivery, `Codex review: no`, with `.github/workflows/` approved as a touch if a test needs it — no reason given.

## Open questions

None.
