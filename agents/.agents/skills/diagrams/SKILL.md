---
name: diagrams
description: Use when a plan, review or conversation needs a diagram — class, ER, sequence or state — or when an agent must show Mermaid in the terminal as text or as an image. Covers Mermaid conventions per diagram type, the "before" picture generated from code, and the mermaid-show renderer.
---

# Diagrams

All diagrams are Mermaid. GitHub renders Mermaid fences in the plan and in the pull request. The terminal renders them with `mermaid-show` (below).

## Pick the diagram type

- Class diagram (`classDiagram`): the objects a change touches, their public methods and their associations. Show only the touched objects and their direct neighbours.
- ER diagram (`erDiagram`): tables, columns and foreign keys, for a change that touches the database.
- Sequence diagram (`sequenceDiagram`): who sends which message to whom, for a flow over several objects.
- State diagram (`stateDiagram-v2`): the states of one object and the transitions between them.

## Conventions

- One diagram answers one question. Split a diagram that answers two.
- Keep a diagram under about 12 nodes. Wider diagrams do not fit a terminal pane.
- Name nodes with the glossary terms. Never use a word from a term's `Avoid:` list.
- Label every relationship with a verb or a cardinality.
- Put a space on each side of every arrow (`A --> B`, never `A-->B`). The text renderer reads `A-->B` as one node named `A--` and prints no error.
- Put the fence directly in `plan.md` under `### Diagrams`. Do not link to an image file.

## The "before" picture

The before picture shows the touched models as they are now. The plan stage generates it. Architects only read it.

1. Read the rails-erd version from `Gemfile.lock`.
2. Version 2.x: run `bundle exec erd --only="Card,Closure"`, with the touched models in `only=`. It writes `erd.mmd` as Mermaid and needs no Graphviz. Paste the result under `### Diagrams`. Delete `erd.mmd` afterwards: it is a build artefact, not part of the change.
3. The gem is missing, or the version is 1.x (Graphviz only, no Mermaid output): ask Etienne to add or upgrade `rails-erd`. Adding a gem needs his approval (playbook rule 11).
4. He declines: build the `erDiagram` by hand from `db/schema.rb`. Read the `create_table` blocks of the touched tables, and the `add_foreign_key` lines for the relationships.

Options of `erd` are in the rails-erd README. The binary takes flags with a `--` prefix.

For a class diagram of a project with no database, read the classes and write the `classDiagram` by hand.

## Show a diagram in the terminal

`~/.claude/skills/diagrams/scripts/mermaid-show` renders Mermaid in the terminal.

- `mermaid-show <file.mmd>`: prints the diagram as Unicode text.
- `mermaid-show <file.md>`: prints each Mermaid fence of the file as text.
- `mermaid-show --markdown`: reads markdown on stdin and writes it back with each Mermaid fence replaced by a text fence. Nothing else changes.
- `mermaid-show --image <file>`: renders a PNG with `mmdc` and shows it with `timg`. Use it in Ghostty, on request.

Print diagrams as text in your own pane. Show an image only when Etienne asks. Text mode needs `beautiful-mermaid` installed globally with npm. Image mode needs `mmdc` and `timg` from Homebrew. When a tool is missing, the script says which one. Do not install it yourself.
