# Intent: Move the stage hand-off from herdr-tui to herdr-core (`hc`)

Author: Etienne van Delden. Status: accepted. Type: refactor. Delivery: autonomous. Codex review: no.

## Problem

Etienne switched from herdr-tui to herdr-app. In agent sessions `HERDR_ENV`, `HERDR_PANE_ID` and `herdr pane current` no longer exist, so `~/.agents/bin/hand-off-plan plan <slug> --auto` exits 1 ("run it inside a herdr pane (HERDR_ENV=1) or a Rex block (REX_SESSION)"). The intent, plan, implement and review hand-offs, the stage-pane cleanup at delivery and the gh-dash pane all depend on herdr-tui state and are broken or stale.

## Proposed outcome

An agent session inside an `hc` terminal (`HC_TERMINAL_ID` set) hands a stage to a fresh worker as an `hc` terminal, and the worker reports back to the coordinator through `hc send`. The review pane, the gh-dash pane and the delivery cleanup work the same way. No herdr-tui or Rex call remains in the agent workflow.

## Affected users and systems

- Etienne and every agent session started from herdr-app.
- Sources in the dotfiles repo: `agents/.agents/bin/{hand-off-plan,start-review,open-pr-dash}`, `herdr/.config/herdr/scripts/*`, `rex/.config/rex/scripts/*`, `agents/.agents/skills/{intent,plan,implement,review,deliver,finish}`, `agents/.agents/skills/deliver/scripts/{deliver,rex_panes.rb}`, the worktree tools `worktree-create` and `worktree-pane`, and their tests.
- `core-values.yml` and `PLAYBOOK.md`, only if a mirrored rule changes.

## Constraints

- Edit sources in `~/Developer/dotfiles/<package>/`, never the symlink targets. No `stow`, no new stow package.
- Playbook rules apply: worktree from `worktree-create`, one logical change per commit, every touched file linted, no linter disables, tests for code changes.
- A child `hc` terminal ends with its parent unless started with `--outlive-parent`. A worker that must outlive its coordinator needs that flag. Names are unique among live terminals, 1-32 of `a-z 0-9 - _`.
- The stage workers keep their models: Opus for `intent` and `plan`, Sonnet for `implement`, in auto permission mode (playbook rule 24).
- The prompt parts stay: intro, role per stage, acceptance, `Decision needed:` lines, the intent branch for autonomous delivery, the report path and the `Plan ready:` / `Handoff done:` line sent back.
- Approved permission: touching `.github/workflows/` if a test needs it. Everything else (gems, system tools, dropping migrations, deploy files) is a stop-and-ask.

## In scope

- Dispatchers choose `hc` when `HC_TERMINAL_ID` is set. `COORDINATOR` defaults to `$HC_TERMINAL_ID`.
- A new `hc` hand-off script with the arguments and stage logic of the herdr script: `hc run --bg` replaces the pane split and agent start, the positional prompt replaces `herdr agent prompt`, and `hc send` replaces the coordinator reply.
- The same port for `start-review` and `open-pr-dash`.
- `worktree-create` and `worktree-pane` open and label via `hc`, and the `intent-pane-<slug>` record holds the `hc` terminal address.
- `deliver` closes the change's idle stage terminals through `hc`.
- The skills `intent`, `plan`, `implement`, `review`, `deliver` and `finish` name the `hc` terminal address instead of `HERDR_PANE_ID` or `herdr pane current`.
- Removal of the Rex path (dispatcher branch, Rex scripts, `rex_panes.rb`, Rex recording in `worktree-create`) and then of the herdr-tui path, each in its own commit, after the `hc` path is proven.
- The same removal in the files outside the agent workflow: `worktree-viewer`, `worktree-viewer-rex`, `lib/common.rb`, `lib/agent_worktree.rb`, `rex/.config/rex/scripts/play-tone.sh`, `rex/.config/rex/launchers.lua` and `github/.config/gh-dash/config.yml`, so no herdr-tui or Rex mention remains anywhere in the repository.
- Tests for each changed script.

## Out of scope

- Moving the report directory: reports and the intent-pane record stay under `<git-common-dir>/herdr/`.
- Any change to herdr-app itself, to the models, or to the content of the stage prompts beyond the transport.
- New `hc` templates.
- Retiring Rex itself as an application; only its agent-workflow hooks go.

## Acceptance criteria

- A plan hand-off from an `hc` terminal starts a worker terminal named `plan-<slug>` in the change's worktree, and its `Plan ready: <path>` line arrives in the coordinator's terminal.
- The report file lands under `<git-common-dir>/herdr/` and is empty when the worker starts.
- An intent hand-off records the intent terminal address in `<git-common-dir>/herdr/intent-pane-<slug>`.
- Delivery closes the idle stage terminals of the change and leaves the intent terminal open.
- Outside `hc` (no `HC_TERMINAL_ID`) the dispatcher exits 1 with a message that names `HC_TERMINAL_ID`.
- After the removal commits, no file in the repository mentions `HERDR_PANE_ID`, `herdr pane` or `REX_SESSION`.

## Flagged concerns

- `die_with_parent`: a worker ends when its coordinator ends. A coordinator that closes before the `Plan ready:` line loses the worker, so the stage workers use `--outlive-parent` where the coordinator may finish first. Side chosen: the worker outlives, and the report file is the durable record.

## Decisions

- Scope covers start-review and open-pr-dash as well as hand-off-plan and the worktree tools — no reason given.
- Reports stay in `<git-common-dir>/herdr/` — no reason given.
- Drop the Rex path — no reason given.
- Remove the herdr-tui path in a later commit, after the `hc` path is proven — no reason given.
- Widen the removal to every file that mentions herdr-tui or Rex, not only the agent workflow — no reason given.
- Add the six new terms (Terminal, Terminal address, Coordinator, Stage terminal, Worktree terminal, Terminal name) to `GLOSSARY.md` in a separate commit — no reason given.
- Autonomous delivery, with `.github/workflows/` approved as a touch if a test needs it — no reason given.

## Open questions

None.
