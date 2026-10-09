# Intent: Keep every skill in one tool-agnostic location

Author: Etienne van Delden de la Haije. Status: accepted. Type: refactor.
Delivery: autonomous

## Problem

Skill sources live in the Claude package (`claude/.claude/skills/`). The tool-agnostic location (`agents/.agents/skills/`, installed at `~/.agents/skills/`) holds only links back into the Claude package. A skill therefore belongs to Claude first, and other agents see it second.

Eleven skills are visible to Claude only: dependencies, dotfiles-maintenance, new-repo-setup, object-oriented-design, rails-api-design, rails-architecture, rails-ops, rails-testing, rails-ui, ruby-style and sync. Codex cannot use them.

The repository also tracks four unused rule folders for other agents: `.clinerules/`, `.cursor/`, `.opencode/` and `.windsurf/`. Each holds a copy of the caveman rule. Nothing references them.

## Proposed outcome

Every skill source lives in the `agents` package, under `agents/.agents/skills/<name>/`. Claude and Codex both see every skill. The four unused rule folders are gone.

## Affected users and systems

- Claude Code and Codex sessions on this machine.
- The dotfiles repository: tests, docs, hooks, herdr scripts and git worktree tools that name a skill path.

## Constraints

- `~/.claude/skills/<name>/` keeps resolving for every skill, because Claude reads only that path and scripts call files under it.
- `~/.agents/skills/<name>/` resolves for every skill, because Codex reads only that path.
- dotfiles-work also installs skills into `~/.claude/skills/` and `~/.agents/skills/`. Both paths stay real directories that several stow packages share.
- The repository is public. No work skill content moves into it.
- Permission approved now (playbook rule 12): after Etienne merges the pull request, the agent may run `stow -R -t "$HOME"` for the `claude` and `agents` packages from the main checkout. Dangling links that the restow leaves go to Etienne as a `trash` command, not removed by the agent.
- No other rule 8, 9, 11, 12 or 13 permission is needed or approved.

## In scope

- Move every skill source to `agents/.agents/skills/<name>/`.
- Make all skills visible to both Claude and Codex, including the eleven Claude-only skills. Each gets the Codex invocation policy file it needs.
- Update tests, docs, hooks and scripts that name the old paths.
- Delete `.clinerules/`, `.cursor/`, `.opencode/` and `.windsurf/`, in the same pull request as a separate commit.

## Out of scope

- The dotfiles-work skills (code-style-*, review-as-*, fizzy-sync). A separate intent for the same slug runs in its own pane in that repository.
- Content changes to any skill, other than path references and the Codex invocation policy file.
- Plugin and marketplace skills that Claude Code installs itself.
- The `synced` folder in `~/.claude/skills/`, which is not a skill.

## Acceptance criteria

- `claude/.claude/skills/` holds no skill source. Each skill folder lives in `agents/.agents/skills/<name>/`.
- A skill source added under `claude/.claude/skills/` makes the test suite fail.
- After the restow, a new Claude session lists every repository skill, for example `intent`, `finish` and `ruby-style`.
- After the restow, Codex lists every repository skill, including `ruby-style` and `sync`, which it cannot see today.
- After the restow, `~/.claude/skills/finish/scripts/change-scope` still prints `personal` in this repository.
- After the restow, `hand-off-plan.sh` and `start-review.sh` still find the skill files they read.
- After the restow, `~/.claude/skills/` and `~/.agents/skills/` hold no dangling link that this change caused.
- The repository test suite and linters pass.
- `.clinerules/`, `.cursor/`, `.opencode/` and `.windsurf/` no longer exist in the repository.

## Open questions

None.
