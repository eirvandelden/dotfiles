# Intent: Writing-as-Etienne skill

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-19). Type: feature. Delivery: step-by-step.

## Problem

Etienne confirmed a communication style on 2026-10-16. Agents have no shared copy, so a drafted message can sound wrong in the few cases where an agent may write as him.

## Proposed outcome

A shared skill, `writing-as-etienne`, holds the style guide. Claude loads it by relevance. Codex loads it only on request. The guide keeps its rule that drafting does not authorise sending.

## Affected users and systems

- Etienne, and Claude and Codex agents that draft messages as him.
- `agents/.agents/skills/`, `claude/.claude/skills/`, `SKILLS-INDEX.md`, `claude/.claude/PLAYBOOK.md`.

## Constraints

- No new stow package, no new dependency.
- Rules 6 and 26 stay in force: no posting without approval; one line per paragraph.
