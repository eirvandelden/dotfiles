---
name: brainstorming
description: Use when starting any change that would touch code — a feature, a component, a behaviour change — before any plan or implementation exists. Interviews one question at a time, records context and decisions in the running docs/changes/<slug>/plan.md draft.
---

<!-- upstream: lucianghinda/superpowers-ruby@7.5.0 skills/brainstorming — re-sync: unwrap the upstream copy first (markdownlint -c ~/.config/markdownlint/unwrap.json -r ~/.config/markdownlint/no-hardwrap.cjs --fix), then diff. Local edits: the spec is the running plan.md draft, the terminal state is the plan skill's design gate, and the visual companion, the reviewer prompt, the dot graph and the superpowers-ruby cross-references are removed. -->

# Brainstorming Ideas Into Designs

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you are building, present the design and get user approval.

The `plan` skill calls this skill as its interview. The running spec is `docs/changes/<slug>/plan.md`, with `Status: draft`.

<HARD-GATE>
Do NOT write any code, scaffold any project, invoke any implementation skill, or take any implementation action until ALL of these are true: a design was presented and approved, `plan.md` is written, and the user has accepted it. Chat approval of a design ("looks good, go ahead") clears the NEXT checklist item only — it is not permission to implement. This applies to EVERY change regardless of perceived simplicity.
</HARD-GATE>

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every change goes through this process. A single-function utility, a config change — all of them. "Simple" changes are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for a truly simple change), but you MUST present it and get approval.

## When NOT to Use

- **Debugging a failure with no behaviour change in view** — use `systematic-debugging`. If the fix turns out to change intended behaviour, come back here.
- **Executing an already-accepted plan** — use `implement`.
- **Pure research or questions** — no implementation ahead means nothing to design.

## Checklist

Create a task for each of these items and complete them in order:

1. **Explore project context** — check files, docs, recent commits.
2. **Ask clarifying questions** — one at a time, understand purpose, constraints and success criteria.
3. **Propose 2-3 approaches** — with trade-offs and your recommendation.
4. **Present design** — in sections scaled to their complexity, get user approval after each section.
5. **Finalize the draft** — promote the running draft (see "Persist as you go") to a complete `plan.md`, including the Decisions log.
6. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below).
7. **User reviews the written plan** — ask the user to review `plan.md` before proceeding.
8. **Transition** — hand back to the `plan` skill's design gate.

**The terminal state is the `plan` skill's design gate.** Do NOT invoke any implementation skill.

## The Process

**Understanding the idea:**

- Check out the current project state first (files, docs, recent commits).
- Before asking detailed questions, assess scope: if the request describes multiple independent subsystems, flag this immediately. Don't spend questions refining details of a change that needs to be decomposed first.
- If the change is too large for a single plan, help the user decompose it into independent pieces: how they relate, what order they ship in. Then brainstorm the first piece through the normal flow. Each piece gets its own plan and implementation cycle.
- For appropriately-scoped changes, ask questions one at a time to refine the idea.
- Prefer multiple choice questions when possible, but open-ended is fine too. Where the `AskUserQuestion` tool is available, use it to render the options.
- Default is one question per message — if a topic needs more exploration, break it into multiple questions.
- Exception: when questions are genuinely independent (no answer would change another question), you may batch up to 4 multiple-choice questions in a single `AskUserQuestion` call. Dependent questions are never batched.
- Focus on understanding: purpose, constraints, success criteria.

**Persist as you go:**

- As soon as real decisions start landing, create `plan.md` as a draft (`Status: draft` in its header) and append each resolved decision when it is made.
- Chat history is not storage — a crashed, compacted or interrupted session must not lose brainstorm state. The draft file is what a future session resumes from.

**Exploring approaches:**

- Propose 2-3 different approaches with trade-offs.
- Present options conversationally with your recommendation and reasoning.
- Lead with your recommended option and explain why.

**Presenting the design:**

- Once you believe you understand what you are building, present the design.
- Scale each section to its complexity: a few sentences if straightforward, up to 200-300 words if nuanced.
- Ask after each section whether it looks right so far.
- Cover: architecture, components, data flow, error handling, testing.
- Be ready to go back and clarify if something doesn't make sense.

**Design for isolation and clarity:**

- Break the system into smaller units that each have one clear purpose, communicate through well-defined interfaces, and can be understood and tested independently.
- For each unit, you should be able to answer: what does it do, how do you use it, and what does it depend on?
- Can someone understand what a unit does without reading its internals? Can you change the internals without breaking consumers? If not, the boundaries need work.
- Smaller, well-bounded units are also easier to work with: you reason better about code you can hold in context at once.

**Working in existing codebases:**

- Explore the current structure before proposing changes. Follow existing patterns.
- Where existing code has problems that affect the work, include targeted improvements as part of the design — the way a good developer improves code they are working in.
- Don't propose unrelated refactoring. Stay focused on what serves the current goal.

## After the Design

**Documentation:**

- Promote the running draft to the final `plan.md` at `docs/changes/<slug>/plan.md`; the `Status:` line stays `draft` until the plan is accepted.
- The plan MUST include a `## Decisions` section: every explicit user decision from the brainstorm, stated verbatim or near-verbatim, each with a one-line rationale. Downstream reviews and plan-fidelity checks key off this section.

**Spec Self-Review:**

After writing the plan, look at it with fresh eyes:

1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections, or vague requirements? Fix them.
2. **Internal consistency:** Do any sections contradict each other? Does the architecture match the feature descriptions?
3. **Scope check:** Is this focused enough for a single implementation plan, or does it need decomposition?
4. **Ambiguity check:** Could any requirement be interpreted two different ways? If so, pick one and make it explicit.

Fix any issues inline. No need to re-review — just fix and move on.

**User Review Gate:**

After the self-review passes, ask the user to review the written plan before proceeding:

> "Plan written to `<path>`. Please review it and let me know if you want to make any changes before we run the design gate."

Wait for the user's response. If they request changes, make them and re-run the self-review. Only proceed once the user approves.

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions.
- **Multiple choice preferred** - Easier to answer than open-ended when possible.
- **YAGNI ruthlessly** - Remove unnecessary features from all designs.
- **Explore alternatives** - Always propose 2-3 approaches before settling.
- **Incremental validation** - Present design, get approval before moving on.
- **Be flexible** - Go back and clarify when something doesn't make sense.

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "User told me exactly what they want" | They gave a solution, not the open decisions hiding inside it. A 3-sentence design + one-word approval surfaces them in seconds. |
| "User said to skip the design process" | Compress it, don't skip it: shortest possible design, single approval message. Speed comes from brevity, not from skipping the gate. |
| "User approved in chat, so I'm cleared to code" | Chat approval clears ONE checklist item. Plan write, user review of the written file and the design gate all still stand. |
| "Skip the doc, it's tiny" | The written plan is what future sessions build from. Chat history evaporates; the user approved a chat blurb, not a reviewed plan. |
| "I'll present the design and the code together to save time" | Defeats the gate — wrong assumptions must be caught before the work, or the time is already wasted. |

## Red Flags — STOP

- About to write code with no written plan.
- Treating "go ahead" / "looks good" as permission to implement.
- Planning to write the plan after the code "to document what I did".
- Jumping from idea straight to the design gate without a presented, approved design.

**All of these mean: return to the checklist and complete the current item.**
