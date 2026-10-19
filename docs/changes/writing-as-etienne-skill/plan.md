# Plan: Writing-as-Etienne skill

Status: accepted (2026-10-19).

## Steps

1. Add `agents/.agents/skills/writing-as-etienne/SKILL.md` with the style guide, one line per paragraph.
2. Add `agents/openai.yaml` with the display name only; the parity test needs Claude and Codex to share one policy, so both load the skill implicitly.
3. Link `claude/.claude/skills/writing-as-etienne` to the shared skill.
4. List the skill in `SKILLS-INDEX.md`.
5. Add one line to rule 6 in `PLAYBOOK.md` that points to the skill.

## Proof

- Both skill paths resolve and show the same `SKILL.md`.
- `SKILLS-INDEX.md` lists the skill.
- Linters and repo tests are green.
