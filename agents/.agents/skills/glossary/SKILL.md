---
name: glossary
description: Use when a change introduces or reuses a domain term, when a word in a request may conflict with an agreed term, or when deciding whether a decision earns an ADR. Keeps GLOSSARY.md (personal repositories) or GLOSSARY.local.md (work repositories) so agreed terms outlive every change folder.
---

# Glossary

The glossary holds the domain terms agreed during changes. `finish` removes the change folder, so a term that lives only in `intent.md` or `plan.md` is lost. The glossary keeps it.

## Where the file lives

Run `~/.claude/skills/finish/scripts/change-scope`. It decides the scope.

- `personal`: `GLOSSARY.md` at the repository root. Commit it.
- `work`: `GLOSSARY.local.md` at the repository root. It is listed in the global git ignore, so git never tracks it. Never commit it.
- The script exits 1 (unknown remote): ask Etienne which one applies. Do not guess.

Read the file when it exists. Create it on the first agreed term.

## Format

One bullet per term, in alphabetical order:

```markdown
- **Term** — definition in one sentence. Avoid: synonym one, synonym two.
```

The `Avoid:` list names the words a reader must not use for this term. Omit it when no synonym competes.

## Challenge an avoided word

Check every word of a request, an intent and a plan against the glossary. When a word appears in a term's `Avoid:` list, stop. Name the glossary term, quote its definition and ask which one Etienne means: the glossary term or a new concept. A new concept needs a new term and a definition. Do not continue with the avoided word.

When a word conflicts with a definition in some other way, apply the same rule.

## Write terms

The `intent` and `plan` stages write the terms agreed in the conversation. Add a term only after Etienne agrees it. Never invent a term.

In a personal repository, commit the glossary change on its own: `docs: glossary terms for <slug>`. The commit of `intent.md` and the commit of `plan.md` stay alone. In a work repository, edit `GLOSSARY.local.md` and commit nothing.

## When a decision earns an ADR

Write an ADR when a decision meets one of these:

- It is costly to reverse.
- It contradicts an earlier decision.
- It will surprise a later reader.

Work ADRs go where step 2 of the `finish` skill puts them. Personal ADRs go to `docs/adr/NNNN-<slug>.md`, numbered one past the highest existing ADR, with the sections Context, Decision and Consequences.
