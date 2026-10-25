# Intent: Write the test-suite terms to GLOSSARY.md

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-25). Type: chore.
Delivery: autonomous. Codex review: no.

## Problem

The branch `speed-up-test-suite` (PR #234, merged) introduced nine test-suite terms, agreed on 2026-10-21. The repository has no `GLOSSARY.md`, so the terms live only in issue #232. A later reader or agent cannot look them up, and can mix up "binary", "shim", "binstub" and "native lefthook".

## Proposed outcome

`GLOSSARY.md` exists at the repository root and holds the nine terms in the `glossary` skill format. Agents that read the glossary challenge "binary" and "shim" when they mean one of these terms.

## Affected users and systems

- Etienne and every agent that reads the glossary in this repository (the `glossary`, `intent` and `plan` skills).
- The test suite under `test/` and the runner `bin/test`, as the subject of the terms. Their code does not change.

## Constraints

- Scope is `personal`: the file is `GLOSSARY.md` at the root, and it is committed.
- Format from the `glossary` skill: one bullet per term, alphabetical, `- **Term** — definition in one sentence. Avoid: …`.
- Markdown prose: one line per bullet (playbook rule 26). The markdown linters must pass.
- No permissions are needed: no gems or packages, no system tools, no migrations, no deploy files.
- Default: the change is documentation, so it gets no test of its own.
- Default: the intent stage writes no glossary terms of its own. The nine terms are the deliverable, and the implement stage writes them.

## In scope

- Create `GLOSSARY.md` with these nine terms, with the meanings issue #232 gives: Binstub, Chained test, Covering test, Hook scripts, Hooks copy, Native lefthook, PATH stub, Runner, Test file.
- An `Avoid:` list where the issue names a competing word: "binary" for Native lefthook, "shim" for Binstub.

## Out of scope

- Terms from other branches or changes.
- Any change to the tests, `bin/test`, the hook scripts or the `glossary` skill.
- An ADR. No decision here is costly to reverse, contradicts an earlier one, or surprises a reader.

## Acceptance criteria

- A reader opens `GLOSSARY.md` at the root and finds all nine terms, in alphabetical order, one bullet each.
- Each definition is one sentence and keeps the issue's meaning: "Binstub" says it is the RubyGems Ruby script `lefthook` on `PATH` that boots Ruby and then starts the native lefthook.
- "Native lefthook" lists `Avoid: binary`, and "Binstub" lists `Avoid: shim`. Terms with no competing word have no `Avoid:` list.
- The markdown linters pass on `GLOSSARY.md`.

## Decisions

- Type is chore — small docs change.
- Fit the issue's definitions to the glossary format (one sentence, `Avoid:` list) instead of copying them verbatim — small docs change; the glossary format is the agreed standard.
- Autonomous delivery, no Codex review — small docs change, no plan review needed.

## Open questions

None.
