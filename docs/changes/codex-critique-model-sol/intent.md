# Intent: Codex critique and review use GPT Sol

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-10). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

The plan critique that a Claude author asks of Codex runs `codex exec -p terra`. Etienne wants Codex second critiques to use GPT-6.1 Sol at medium reasoning effort. The skill, the playbook and the contract test still say Terra.

## Proposed outcome

A Claude author runs the Codex critique with `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium`. The speed-run reviewer names GPT Sol instead of GPT Terra.

## Affected users and systems

- Etienne and any agent that runs the autonomous plan critique.
- `agents/.agents/skills/plan/SKILL.md`, step 2 of autonomous delivery.
- `agents/.agents/PLAYBOOK.md`, section 7a (also reached as `claude/.claude/PLAYBOOK.md`).
- `agents/.agents/skills/speed-run/SKILL.md`, the reviewer line.
- `test/autonomy_contract_test.rb`, the critique contract assertion.

## Constraints

- The model ID `gpt-6.1-sol` comes from `~/.codex/models_cache.json` and the base `model` in `codex/.codex/config.toml`.
- Playbook rules 8, 9, 11, 12 and 13 need no approval: no tool install, migration, dependency, symlink or deploy file changes.
- Markdown prose stays one line per paragraph.

## In scope

- Replace `-p terra` with `-m gpt-6.1-sol -c model_reasoning_effort=medium` in the plan skill and in section 7a.
- Update the contract test assertion to match.
- Replace "GPT Terra" with "GPT Sol" in the speed-run reviewer line.

## Out of scope

- Playbook rule 24 (Terra for planning sessions) and `codex/.codex/terra.config.toml`.
- The `claude -p` critique from a Codex author.
- Any new Codex profile file.
- The `Codex review: yes` reviewer path.

## Acceptance criteria

- The plan skill tells a Claude author to critique with `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium`.
- Section 7a names the same command.
- `bin/test test/autonomy_contract_test.rb` passes and fails if the command goes back to `-p terra`.
- `grep -rn "codex exec -p terra"` finds nothing outside `docs/changes`.
- The speed-run reviewer line names GPT Sol, not GPT Terra.

## Decisions

- Use `gpt-6.1-sol` with medium effort for Codex critiques — Etienne asked for "6.1-sol-medium".
- Also change the speed-run reviewer to Sol — Etienne chose the wider scope; no reason given.
- Deliver autonomously, without the Codex review — Etienne chose autonomous; Codex review defaults to no.

## Open questions

None.
