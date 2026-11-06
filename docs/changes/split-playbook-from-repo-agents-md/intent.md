# Intent: Split the playbook from this repository's agents.md

Author: Etienne van Delden. Status: accepted. Type: refactor. Delivery: autonomous. Codex review: no.

## Problem

Root `agents.md` in the dotfiles repository is the shared playbook, not a description of this repository. Claude's `PLAYBOOK.md`, Codex's `PLAYBOOK.md` and the root `CLAUDE.md` all point at it. In this repository the playbook therefore loads twice: once through `~/.claude/CLAUDE.md` and once through the repo `CLAUDE.md`. No file tells an agent how to use this repository: its packages, its tests, its linters. The playbook itself says a repository's own `AGENTS.md` covers that half. Etienne also has no place for a note that holds in every repository, such as the keyboard note (Dvorak, arrow keys).

## Proposed outcome

Two separate files. The shared playbook is the one file all agents read, in every repository, and it carries the keyboard note. The repository `agents.md` describes only this repository. In this repository an agent reads the playbook once and the repo file once.

## Affected users and systems

- Claude Code and Codex sessions in every repository (playbook path and content).
- Sessions in the dotfiles repository (new repo `agents.md`).
- The tests, scripts, comments and docs that read or cite root `agents.md` as the playbook.

## Constraints

- Both tools keep importing a file named `PLAYBOOK.md` from their home directories. `claude/.claude/CLAUDE.md` and `codex/.codex/AGENTS.md` stay unchanged.
- Edit only source files under `~/Developer/dotfiles`. Never run `stow`.
- Approved permission (playbook rule 12): repoint the two tracked symlinks `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md`, and move the playbook file with `git mv`. No other symlink changes. No gems, system tools, migrations or deploy files.
- Etienne chose autonomous delivery for a change that decides the load path of every agent session, so the acceptance criteria prove that path resolves.

## In scope

- Move the playbook to `agents/.agents/PLAYBOOK.md` and repoint the Claude and Codex `PLAYBOOK.md` symlinks to it.
- Write a new repo-only root `agents.md` with three parts: the stow packages and rules (skill source location, the `dotfiles-work` overlay, no `stow`), the test and lint commands, and a link to the `dotfiles-maintenance` skill. Keep it under one page. The root `CLAUDE.md` symlink stays.
- Repoint every test, script, comment and doc that means the playbook to the new path. A citation whose content now sits in neither file points to the `dotfiles-maintenance` skill.
- Add a `Keyboard` section to the moved playbook as the last, separate commit.

## Out of scope

- Documenting mirrored rules and drift tests in the repo `agents.md`.
- Moving or copying `dotfiles-maintenance` skill content into the repo `agents.md`.
- Changing the playbook's wording, other than the new `Keyboard` section.
- Editing `~/Developer/AGENTS.md`, which stays as it is.
- Creating `~/.agents/PLAYBOOK.md`; no tool reads it, so no re-stow is needed.

## Acceptance criteria

- In a session in the dotfiles repository, the playbook text loads once: root `agents.md` no longer contains it.
- `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md` both resolve to `agents/.agents/PLAYBOOK.md`, and a test proves it.
- Root `agents.md` tells an agent the stow packages, where skills live, the `dotfiles-work` overlay and the no-`stow` rule; it lists `bin/test` and the repo's linters, each checked against the repo; it links the `dotfiles-maintenance` skill; it is under one page.
- Every test that read root `agents.md` as the playbook now reads the new path, and the full suite is green.
- No file in the repo cites root `agents.md` as the playbook.
- The playbook has a `Keyboard` section: Etienne types Dvorak, navigates with the arrow keys on a separate layer, and agents name the arrow keys, never `hjkl`. It arrives in the last commit.

## Decisions

- All agents share one playbook, and a separate `agents.md` describes only this repository — "so agents know how to use this repository".
- The playbook moves to `agents/.agents/PLAYBOOK.md` — no reason given beyond the option shown: the agents package already holds the files both tools share, such as `MCP.md` and the skills.
- The repo `agents.md` covers packages and stow rules, test and lint commands, and a link to the `dotfiles-maintenance` skill; it does not cover mirrored rules and drift tests — no reason given.
- The keyboard note lands in this change, as the last commit, not in a separate change — no reason given.
- Delivery is autonomous, with no Codex review — no reason given.

## Open questions

None.
