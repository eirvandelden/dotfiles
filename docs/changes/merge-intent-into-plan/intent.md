# Intent: Merge intent and plan into one plan.md

Author: Etienne van Delden. Status: accepted (2026-11-23). Type: refactor. Delivery: step-by-step.

## Problem

Every change has two documents, `intent.md` and `plan.md`, and two gates. No coworker reads either file. The split adds nothing over brainstorming into one bigger plan.

## Proposed outcome

- Each change has one `docs/changes/<slug>/plan.md`.
- Its header holds Status, Type, Delivery and Codex review. Its first sections hold the intent: problem, outcome, scope, out of scope, acceptance criteria and decisions. Design and proof follow.
- A vendored `brainstorming` skill, copied from superpowers-ruby 7.5.0 and trimmed to the interview, is the entry point. It asks one question at a time and records context and decisions as it goes. The `plan` skill calls it, then runs the existing design gate.
- The `intent` skill is deleted. Support for `intent.md` is dropped everywhere.
- A GitHub issue can still be written intent-shaped. The interview seeds from it.

## Gates

- Interactive: brainstorming and the draft run in plan mode. Approving `ExitPlanMode` counts as "accepted". `plan.md` is written right after approval if plan mode only permits its own plan file.
- Autonomous (§7a): Claude drafts the plan, the other model family critiques it, every finding closes as fixed or dismissed, then Etienne reads it and types "accepted". The critique no longer replaces the word. `auto-accept` becomes a "critique is closed" check.
- The literal word stays only for autonomous delivery and for panes where `ExitPlanMode` has no approver.

## Affected users and systems

Etienne and every agent that follows the playbook. Skills, scripts, hooks, agents, tests and docs in the dotfiles repository.

## Constraints

- Playbook rule 17, §7a and `core-values.yml` change. Both mirrors change together.
- No `stow` run.

## In scope

- Skills: `intent` (deleted), `brainstorming` (new), `plan`, `implement`, `deliver`, `review`, `finish`, `glossary`, `code-review`, `new-repo-setup`.
- Scripts: `change-folder`, `commit-plan`, `auto-accept`, `intent_metadata.rb`, `start-delivery`, `delivery-preflight`, `restore`, `deliver`, and `hand-off-plan.sh` in herdr, rex and herdr-app.
- Agents, hooks and display: `reviewer`, `test-writer`, `implementer`, generated Codex agents, `consent-guard`, `test-guard`, statusline.
- Docs: PLAYBOOK §7 and §7a, `core-values.yml`, `SKILLS-INDEX`, GLOSSARY.
- The matching tests.

## Out of scope

- Behaviour changes to implement, review and deliver beyond reading `plan.md`.
- Editing the private `dotfiles-work` overlay. The plan lists what it references.
- Running `stow`.

## Acceptance criteria

- Starting a change produces one `plan.md` with the intent sections and no `intent.md`.
- Approving `ExitPlanMode` in an interactive session marks the plan accepted.
- An autonomous plan cannot be marked accepted while a critique finding is open.
- `commit-plan`, `deliver`, `restore` and `start-delivery` work from `plan.md` alone.
- A change folder holding only `intent.md` is not treated as a plan.
- No file in the repository refers to the `intent` skill or `intent.md`, outside git history and this change folder.
- `bin/test` and all linters pass.

## Decisions

- Critique first, then the human reads and accepts — Etienne chose this order for autonomous delivery, no reason given beyond preference.
- Vendor as `brainstorming` and delete `intent` — keeps re-sync with upstream by diff easy.
- Drop `intent.md` support entirely — Etienne is the only reader and nothing is in flight.
- Use `ExitPlanMode` approval as "accepted" in interactive sessions — Etienne asked for plan mode to return.
