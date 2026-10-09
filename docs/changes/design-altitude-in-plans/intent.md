# Intent: Design altitude in plans

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature.

## Problem

When Etienne plans a change with an agent, the conversation stays at file-and-task level. A plan names the files, the order of work and the tests, but it does not show the domain model, a class diagram, an ERD, the method signatures, the complexity of a query path or the invariants that must hold. Etienne cannot discuss the software as a design before it is built.

Domain names do not survive a change: `finish` removes the change folder, so the terms agreed during one change are gone at the next.

Reviews do not check the design: the reviewer runs bugs, security and compliance passes, so a Law of Demeter violation, an N+1 loop or a name that contradicts the domain language goes unreported.

Agents cannot show diagrams in the terminal: Mermaid appears as raw text in the agent pane and in the herdr file viewer.

## Proposed outcome

Every plan opens with a design discussion before the build steps. The agent presents the domain terms, diagrams of the objects and data the change touches, the public signatures, the complexity of each new path, the invariants and two or three alternatives. Etienne challenges and agrees the design before the file-level plan is written.

Each part of the design is proved by the build: a complexity claim by a query-count test, an invariant by its enforcement and a test.

The repository keeps a glossary of domain terms that outlives every change, and agents challenge any term that conflicts with it.

Diagrams render in the terminal as text, and as images where the terminal supports them. GitHub renders the same diagrams in the plan and the pull request.

The reviewer and the plan critique check the design as well as the code.

## Affected users and systems

- Etienne, in every personal and work repository that uses the `intent` → `plan` → `implement` chain.
- Claude Code and Codex agents: shared skills under `claude/.claude/skills/`, linked for Codex through the `agents` stow package; agents under `claude/.claude/agents/`, generated for Codex by `bin/generate-codex-agents`.
- Skills that change: `plan`, `object-oriented-design`, `rails-architecture`, `ruby-style`, `review` and the `reviewer` agent, the `REVIEW.md` template, the `intent` interview.
- herdr panes and the herdr file viewer, Ghostty.

## Constraints

- Playbook rules stay in force: no service objects, rich models, TDD, Simplified Technical English, one line per markdown paragraph.
- Claude/Codex parity: one shared source per skill; Claude-only features (the question tool's previews) need a plain-text equivalent for Codex.
- Ruby signatures are inline RBS comments (`#:` and `# @rbs`) above each `def`. No `sig/*.rbs` files, no Sorbet or Shopify typing tools.
- YARD tags are dropped. Prose summaries of what a class or method does stay; the inline RBS comment replaces `@param` and `@return`.
- Diagrams are Mermaid only.
- A design section the change does not touch shrinks to one line that says why.
- New gems in a project (rails-erd, Steep, rbs_rails, rbs) are added only after the agent asks in that project; each has a fallback when the answer is no.
- Approved during this interview: Homebrew `mermaid-cli`, `timg` and `imagemagick` (installed 2026-10-09); npm `beautiful-mermaid` for the terminal renderer.

## In scope

1. A design section in `plan.md` before the file-level part, and a plan conversation that walks it first.
2. `## Proof` lines for the design claims: query counts and invariants.
3. A repository glossary with avoided synonyms, kept up to date by the intent and plan stages, and the rule for when a decision earns an ADR. Personal repositories commit `GLOSSARY.md`; work repositories keep `GLOSSARY.local.md`, never committed.
4. A shared design skill: deep modules, messages first, CRC cards, connascence, SOLID mapped onto rich Rails models without service objects.
5. A read-only architect agent that the plan stage runs two or three times in parallel to compare designs.
6. A diagrams skill: Mermaid conventions per diagram type, the "before" picture generated from code (rails-erd when present, a no-gem fallback otherwise), terminal rendering as text and as images.
7. A design pass in the reviewer, the `REVIEW.md` template and the plan critique.
8. An investigation of whether the herdr file viewer can show Mermaid fences as text; kept only if the viewer allows it.
9. Inline RBS signatures in the plan and the code, checked by Steep (models included, through rbs_rails) where the project accepts the gems.

## Out of scope

- Formal methods: TLA+, Quint, Alloy, Dafny, Lean.
- Mutation testing.
- Property tests against a brute-force oracle.
- Inline image rendering of Mermaid in Neovim (a separate change).
- A stored domain or architecture document besides the glossary and ADRs. Diagrams of the current state are generated from code when a plan needs them; `finish` still removes the change folder.
- Changing the `rubocop-eirvandelden` gem.
- Rewriting existing YARD comments in other repositories; the new rule applies to code written from now on.

## Acceptance criteria

- A plan for a change that adds a method to a model opens with a design section: the domain terms, a class diagram of the touched objects, the method's inline RBS signature and its complexity. All of it comes before the files that change.
- A plan for a change with no design impact, such as a config tweak, shows each design subsection as one line that says why it does not apply.
- Before the plan agent writes the file-level part, it shows two or three alternative designs, says why it rejects all but one, and waits for Etienne to agree the design.
- A plan that says "the board page runs three queries, whatever the number of cards" has a Proof line that names the query-count test proving it.
- A plan that states an invariant, such as "a card has at most one closure", names where it is enforced and the test that proves it.
- A term agreed during a change is still in the glossary after `finish` removes the change folder: `GLOSSARY.md` in a personal repository, `GLOSSARY.local.md` in a work one.
- When Etienne uses a word the glossary lists as one to avoid, the agent names the glossary term and asks which one he means.
- The "before" ERD in a plan comes from rails-erd. When rails-erd is missing, the agent asks to add it; when Etienne declines, the agent builds the ERD from `db/schema.rb` instead.
- An agent prints a Mermaid class, ER, sequence or state diagram as text in its own pane, and shows it as an image in Ghostty on request.
- The plan stage runs two or three architect agents at once, each with a different design goal, and compares their designs. Codex gets the same architect agent.
- The reviewer reports a design finding for each of: a public method the plan did not sign, a Law of Demeter violation, an N+1 query loop, a word from the glossary's avoid list.
- New Ruby code an agent writes has a prose summary and an inline RBS signature per method, and no YARD tags.
- In a project that accepted Steep and rbs_rails, `steep check` passes on the change. In a project that declined them, the plan says the signatures are not checked.
- A Codex session loads the same design, diagrams and glossary skills from `~/.agents/skills` and writes the same plan template.

## Flagged concerns

- Agreeing the design needs Etienne, but autonomous delivery (playbook §7a) runs the plan stage without him. Chosen side: in autonomous delivery the recorded cross-model critique also covers the design section and stands in for his agreement, as it already does for plan acceptance.

## Open questions

None.
