---
name: ruby-style
description: Use when writing or changing Ruby method bodies, naming methods, choosing between guard clauses and if/else, deciding method visibility, or writing documentation comments — the formatting and method-shape rules a linter cannot fully enforce.
---

# Ruby Method Style and Formatting

Most of this is enforced mechanically by the `rubocop-eirvandelden` gem. The rules are written
out here so an agent writes the code correctly the first time instead of relying on autocorrect,
and so agents without a RuboCop run available still follow them.

## Method shape

- Each method does exactly one thing. If it starts doing more, extract helper methods.
- Target methods at 5 lines, keep under 10.
- Keep classes under ~100 lines.
- Pass no more than 4 parameters (a hash of options counts as one).
- Max line length ~120 characters.

## Naming

- Bang methods (`!`) are unsafe — they mutate the receiver or behave more dangerously. There
  should normally be a safe non-bang variant.
- Predicate methods (`?`) must always return a boolean, and never mutate or have side effects.
- Prefer intention-revealing names. Short names are fine in hot paths, longer names in less-used
  code.
- Avoid abbreviations unless universal (`id`, `url`, `api`).

## Control flow

- Personal projects: prefer guard clause style (`return x if y`) over `if/else/end` when the line
  fits within 120 characters.
- A guard clause is followed by a blank line.
- No one-line method definitions.
- No inline variable assignment inside a guard condition.
- Add parentheses when a compound condition reads ambiguously.

## Mutation and interfaces

- `rescue => error`, never `rescue => e`.
- Never mutate a method's parameters — work on a copy (`dup`) when a transformation is needed.
- No `send`/metaprogramming to shortcut a proper interface.

## Visibility and layout

- Keep existing methods' visibility when refactoring; new helper methods default to `private`.
- Blank lines between methods.
- Group related private methods together.
- Use explicit `private`/`protected` sections.

## Documentation comments

- Work projects use YARD: short docs on classes always, on methods only when complex, never on
  private methods, no giant `@example` blocks.
- Personal projects: no doc comments unless a non-obvious "why" needs recording.

## Examples

Guard clause and related examples: `rails-architecture` skill, `references/examples.md`.
