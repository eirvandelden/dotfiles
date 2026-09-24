# Plan: Take the employer's details back out of the public dotfiles

From `intent.md` and `spec.md` (2026-09-24). Status: accepted.

## Context

A public repository carries 17 recorded Codex approval rules naming the employer's repositories, an internal issue number, a bug's test filename, the work 1Password account host, and the private work dotfiles path. Urgent, so this is a forward scrub; history and recurrence are separate decisions.

## Files that change

`codex/.codex/rules/default.rules` — 17 recorded `prefix_rule` lines removed, nothing else.

## Order of work

1. Scan wide, not just for the employer's name. That alone found 8 of 17.
2. Assert each match is a standalone `prefix_rule(...)` line before removing it, so a multi-line construct cannot be broken in half.
3. Remove, then rescan the file and the whole repository.
4. Confirm the diff is deletions only.

## Risks

**A partial scrub is worse than none** — it reads as done. Hence the wide pattern and the repository-wide rescan.

**Codex will ask again** for the removed commands. Every one is a one-shot from a finished session, so the cost is a prompt, once, if ever.

**The file re-accumulates.** Codex appends on every recorded approval, which is how this came back after the 2026-09-08 cleanup. Not solved here.

## Proof

- Wide scan of the repository returns nothing → `git grep -inE` over the full pattern, output empty. The pattern is not reproduced in these documents, which are public as well.
- Diff is deletions only → `git diff` reports no insertions.

Test setup: none. This is a deletion from a configuration file, which the agile ruleset exempts from unit tests; the proof is the scan.

## Out of scope

Rewriting history. Preventing recurrence. The uncommitted work references in `claude/.claude/settings.json` and `codex/.codex/config.toml`, which are not committed and so not public.
