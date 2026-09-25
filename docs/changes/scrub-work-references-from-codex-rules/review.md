# Review: Take the employer's details back out of the public dotfiles

## Round 1 — 2026-09-25T08:05Z — e06e9f4c

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default passes applied.

Bugs: 17 whole `prefix_rule(...)` lines removed from `default.rules`, each standalone, no insertions in that file. cspell is green on every changed file. Nothing found.

Security: no approval rule widened or added. Nothing found.

Compliance: spec criteria against the diff.

- Wide scan of `default.rules` returns nothing — proved only by the author's unpublished pattern; see the second Nit.
- Diff is deletions only — holds for `default.rules`; the branch as a whole also adds 11 dictionary words (first Nit).
- Rest of the repository clean under the same scan — see the Important finding and the second Nit.

- [ ] Important: A remaining rule still describes the employer's infrastructure. Its printf label uses the sector word that is also the employer's division name, next to a "management proxy parameters" label; the neighbouring labels ("HAProxy site manifest", "production cluster config", "management server template", "proxy.params") come from the same work session. That is weaker than a name, but spec requirement 1 targets anything that points at the employer, and the plan's own risk is that "a partial scrub is worse than none". Decide whether these five one-shot `printf` rules go too — `codex/.codex/rules/default.rules:111` (also lines 105–107, 109) →
- [ ] Nit: `plan.md` lists `default.rules` as the only file that changes, "nothing else", but the commit also adds 11 words to `project-dictionary.txt`. The commit message explains why (cspell reads the whole staged file), so the change is justified; the plan does not record it — `docs/changes/scrub-work-references-from-codex-rules/plan.md:11` →
- [ ] Nit: The proof cannot be repeated by a reviewer. The scan pattern is deliberately not written down, so "the rest of the repository is clean under the same scan" is unverifiable. Tracked files still name `~/Developer/dotfiles-work` (for example `install/tasks/50_stow_all.sh:43`, `claude/.claude/skills/dotfiles-maintenance/SKILL.md:10`) — deliberate and pre-existing, but the spec's "private work dotfiles path" wording reads as if it covers them. Say which form of that path the scan targets, without writing the rest of the pattern — `docs/changes/scrub-work-references-from-codex-rules/spec.md:19` →
