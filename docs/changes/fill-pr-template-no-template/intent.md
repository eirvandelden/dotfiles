# Intent: `fill-pr-template`'s appended sections duplicate content and oversize the PR body

Author: Etienne van Delden. Status: accepted. Type: bugfix.

## Problem

`claude/.claude/skills/finish/scripts/fill-pr-template` builds the PR body from `intent.md` and `plan.md`. With no template — the common case in personal repositories — it appends four sections: Summary, Why, Implementation, Proof. Two defects:

1. Why duplicates Summary: both receive the intent's Problem text, verbatim.
2. Implementation is the whole plan: it gets the file list *and* every numbered step of Order of work — for PR #158 that was eleven RED/GREEN steps including review-round notes, when a PR reader only wants the file list.

Etienne trimmed PR #158's body by hand to work around this: Summary (Problem + Outcome), Implementation (file list only), Proof (acceptance criteria lines only, no per-file unit-test list), no Why.

## Proposed outcome

With no template, or no matching heading anywhere, the appended body is:

- Summary: Problem + Proposed outcome (unchanged).
- No Why section.
- Implementation: the file list only, not Order of work.
- Proof: the acceptance-criteria lines from plan.md's Proof section only, not any nested per-file unit-test list.

This matches what Etienne wrote by hand for PR #158, without hand-editing next time.

The *templated* path (a template whose own headings match Summary/Why/Implementation/Test) is unaffected: a template that legitimately asks for a Why heading still gets the Problem text, and an Implementation heading still gets the file list plus Order of work as it does today. The distinction is between the *appended* set (no heading matched, or the one that did was a checkbox list) and the *categorized* set (a template heading matched) — only the appended set changes.

## Affected users and systems

- `claude/.claude/skills/finish/scripts/fill-pr-template` (the script).
- `test/fill_pr_template_test.rb` (its tests).
- `claude/.claude/skills/finish/SKILL.md` §3 (describes the output).
- `docs/changes/ai-native-workflow/phases/04-finish.md` step 1 (the plan document describing the rule — updated in the same commit as the code, since it now departs from the code otherwise).
- Anyone (personal repos, mostly Etienne) running `finish` on a repository with no PR template, or a template with no matching headings.

## Constraints

- Templated-path behavior (categorized sections, matched by heading) does not change.
- Scope is `finish/`'s `fill-pr-template` script and its direct docs only — not the `finish` flow itself. In particular, capturing something like a review-round count in the PR body (as Etienne did by hand for PR #158) would require changing `finish`'s own flow (§3) to preserve that count past `review.md`'s deletion; that's out of scope for this change.

## Open questions

None.
