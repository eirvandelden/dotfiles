# Intent: AI-native workflow for personal and work development

Author: Etienne van Delden. Status: accepted (2026-09-18).

## Problem

Building code is no longer the slow part. The slow parts are what happens around it: deciding what to build, agreeing how, and checking that what came out matches what was asked. Today those steps live in chat history, in `~/.claude/plans/<random-name>.md`, or nowhere.

The agent setup has grown by accretion. Four rulesets say "plan before code" in four different ways (playbook, agile plugin, superpowers plugin, plan mode). Three mechanisms hand work to another session. Five paths review a branch. About 42 KB (~11k tokens) of instructions load before the first prompt, and 8 KB of that loads again into every subagent. Claude and Codex share the playbook by symlink but carry hand-copied skills that have already drifted.

Anthropic's AI-native SDLC playbook describes the alternative: every stage writes one committed markdown file the next stage reads — `intent.md`, `spec.md`, `plan.md` — and review reads them back. A fresh session, a second model, or a future self can pick any stage up from the file alone.

## Proposed outcome

- Every change, personal or work, starts as `docs/changes/<slug>/intent.md` in the application repo, grows a `spec.md` and a `plan.md` next to it, and is implemented from the plan. Review reads `plan.md` and a repo-level `REVIEW.md`. The folder is removed when the change is done.
- Claude Code and Codex CLI run the same workflow from the same files. Shared skills exist once and are linked into both; a test fails when they drift.
- One ruleset: the playbook. Process plugins that restate it are disabled (not uninstalled). Domain skills worth keeping are copied into the dotfiles.
- All agent work spends credits from the local CLIs. Nothing runs in GitHub.
- A written list of the habits Etienne has to change, because tooling alone will not.

## Affected users and systems

Etienne, in both roles. `~/Developer/dotfiles` (public; Claude, Codex, git, lefthook, herdr, conductor packages) and `~/Developer/dotfiles-work` (private; work skills, consent allowlist, project-local packages). Every personal repository via `new-repo-setup`. The two work applications via their stowed project-local packages.

## Constraints

- The public dotfiles repo may not name the employer or its systems.
- Company policy keeps some work integrations (mail, calendar, chat, search) available only to Codex; work intake must therefore be possible in Codex and continuable in Claude.
- No AI agents in GitHub Actions or GitHub apps — credits must come from the local CLIs.
- Work repositories cannot carry `CLAUDE.md`, `.claude/`, or `REVIEW.md` without team consent; today's stowed `docs/for-agents.local.md` mechanism stays the vehicle.
- Playbook rules still apply to the implementation of this change: worktree-first, ask before adding or removing dependencies, never `stow` without instruction, never edit `.github/workflows/` without approval, never commit machine-local state.
- Habits take time. Phases must be small enough to adopt one at a time.

## Open questions

- ~~Do the work applications already have an ADR convention?~~ Resolved 2026-09-21: they do not, and they should. Cross-application ADRs go in `docs/adr/` in the work repository.
- How is the work PR status flipped to "Needs Review" today (GitHub Project field, label, draft→ready)? `fizzy-sync` already writes Project Status; read the mechanism from there.
- Which superpowers-ruby domain skills are actually used? Decide keep/drop per skill during the vendoring phase, not up front.
