---
name: software-design
description: Use when designing a change before building it — writing the Design section of plan.md, comparing alternative designs, or judging whether an object model is deep, loosely coupled and free of service objects. Covers deep modules, messages first, CRC cards, connascence and SOLID on rich Rails models.
---

# Software design

Use this skill in the plan stage, before the file-level plan. It tells you how to fill the `## Design` section of `plan.md`. The `plan` skill owns the template and the design gate.

## Start from messages, not classes

List the messages first: who asks whom to do what. Find the objects after that. An object exists because it receives a message. A class that receives no message has no reason to exist.

Write each message as a public method signature in the design. The `plan` skill asks for inline RBS comments (`#:`) above each `def`, with a prose summary.

## Deep modules

A deep module has a small public interface and hides a lot of behaviour. A shallow module has an interface as large as its body. Prefer deep modules.

- Count the public methods. Fewer is better.
- Ask what the caller must know to use the object. Less is better.
- Reject a class that only forwards calls to another class.

## CRC cards

For each object in the design, write one card:

- Class name.
- Responsibility: one sentence, no "and".
- Collaborators: the objects it sends messages to.

If a responsibility needs "and", split the object. If a card has more than four collaborators, the object knows too much.

## Connascence

Connascence names the ways two parts of the code must change together. Rank it from weak to strong and move down the list:

1. Name and type: weak, accepted.
2. Meaning and position: a magic value or an argument order. Replace it with a named object or a keyword argument.
3. Algorithm and execution order: two parts must agree on a method or a sequence. Put both behind one method.
4. Timing and identity: two parts must agree at the same moment or on the same instance. Avoid it.

Keep strong connascence inside one object. Allow only weak connascence across object boundaries.

## SOLID on rich Rails models

- Single responsibility: one reason to change per object. A concern holds one behaviour.
- Open and closed: add behaviour with a new concern or a new state record, not with a new branch in a long method.
- Liskov substitution: a subclass keeps the promises of its parent. Prefer composition when it cannot.
- Interface segregation: a caller sees only the methods it needs. Keep public interfaces small.
- Dependency inversion: inject collaborators with keyword arguments that have defaults.

Business logic lives on the object that owns the data. Never use a service object, manager or other orchestration class. The order of preference is a model method, a concern, a state record, an inline ActiveJob, and last a PORO for view-only presentation. The `object-oriented-design` and `rails-architecture` skills hold the detail.

## Complexity and invariants

State the cost of each new path. For a database path, state the number of queries as a function of the input size. A claim such as "three queries, whatever the number of cards" needs a query-count test in `## Proof`.

State each invariant as a sentence that can be false. Name where it is enforced: a database constraint, a model validation or a method guard. Name the test that proves it.

## Alternatives

Produce two or three designs, each built for one goal, for example the fewest public methods, the least change to existing code or the cheapest queries. Say why you reject all but one. The `architect` agent proposes one design for one goal. Run two or three of them in parallel and compare the results.

## Names

Use the terms in the glossary. When a word the glossary lists as one to avoid appears, apply the `glossary` skill.
