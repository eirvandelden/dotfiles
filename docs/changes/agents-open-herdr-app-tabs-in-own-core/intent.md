# Intent: Agents open herdr-app tabs in their own core

Author: Etienne van Delden. Status: accepted. Type: feature. Delivery: autonomous. Codex review: no.

## Problem

Etienne moved fully to herdr-app and herdr-core and uses only the `default` (personal) and `work` cores. Agents that open a tab still land in the wrong place: outside herdr-core, or in the wrong core.

Three causes found:

- Two skills in `~/.claude/skills`, `herdr-gpui-browser` and `herdr-automations`, date from 30 Oct. The old Herdr UI wrote them. They tell agents that "open a browser tab" means a command of an app that no longer exists, gated on `HERDR_ENV=1`. No dotfiles package tracks them.
- `/opt/homebrew/bin/herdr`, the old TUI, is still installed. An agent that runs `herdr pane` or `herdr tab` talks to the TUI server, not herdr-core.
- A bare `herdr-app do tab.new` opens the tab in the focused space. An agent in the `work` core opens a personal tab when personal has focus, and the reverse.

No agent-facing skill says how to open a tab in herdr-app.

## Proposed outcome

An agent that opens a tab, in any repository, opens it in the core the agent itself runs in: `default` for personal, `work` for work. The focused space does not matter. Agents never reach for the old TUI or the old Herdr UI.

## Affected users and systems

- Claude and Codex agents that open tabs, panes or spaces in herdr-app.
- Etienne, who sees the tabs.
- The `agents` stow package (skill source), `SKILLS-INDEX.md` and the `herdr-app-pane` tool, which already targets the coordinator's space.

## Constraints

- Skill sources live in `agents/.agents/skills/<name>/`. No new stow package.
- The stale skills belong to Etienne's home directory, not the repository. Etienne trashes them himself with `trash`.
- Uninstalling the `herdr` TUI is system tooling (playbook rule 8) and stays Etienne's call.
- Herdr UI may rewrite the stale skills while the old app runs.
- No permissions needed: no gems, packages, system tools, destructive migrations or deploy files.

## In scope

- One agent-facing skill that says: open tabs with `herdr-app-pane` or `herdr-app do … --machine <own core>`, in the agent's own core; never use the `herdr` CLI, `HERDR_ENV` or the Herdr UI browser commands.
- A line in `SKILLS-INDEX.md` for the skill.
- A way for an agent to find its own core, stated in the skill.
- Test coverage where the repository tests skill content.

## Out of scope

- Uninstalling the `herdr` TUI.
- Deleting the stale skills (Etienne does it).
- Changing the pipeline scripts (`hand-off-plan`, `start-review`, `open-pr-dash`), which already place panes beside the coordinator.
- Changes to herdr-app or herdr-core themselves.

## Acceptance criteria

- An agent in the `work` core that opens a tab gets it in the `work` core, while the personal space has focus.
- An agent in the `default` core that opens a tab gets it in the `default` core, while the work space has focus.
- An agent that reads the skill never runs the `herdr` CLI or the Herdr UI browser command to open a tab.
- The skill appears in `SKILLS-INDEX.md`.

## Flagged concerns

None.

## Decisions

- A tab opens in the agent's own core, not in the focused space — matches the personal/work split.
- Autonomous delivery, no Codex review — small change on a personal repository.

## Open questions

None.
