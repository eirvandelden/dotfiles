# Spec: `fill-pr-template`'s appended sections duplicate content and oversize the PR body

From `intent.md` (2026-09-25). Status: accepted.

## Requirements

1. With no template, or a template whose headings match nothing (the *appended* path), the PR body's Summary section still holds the intent's Problem and Proposed outcome — unchanged.
2. With no template, the appended body has no Why section.
3. With no template, the appended body's Implementation section holds only the plan's "Files that change" text — not "Order of work".
4. With no template, the appended body's Proof section holds only the plan's Proof section's top-level acceptance-criteria lines (the `- <criterion> → <test>` bullets) — not any nested, more-indented per-file unit-test list underneath them.
5. With no template and no Proof section in the plan, the appended body still has no Proof heading (an empty appended section is never emitted — unchanged rule).
6. The *categorized* path (a template heading matches Why, Implementation, or Test/Proof) is unaffected: a matched Why heading still gets the Problem text, a matched Implementation heading still gets the file list plus Order of work, and a matched Test heading still gets the plan's whole Proof section, exactly as today.

## Design decisions

- The appended set and the categorized set now source different content for the same three categories (why, implementation, test), so the script computes two separate fill hashes: `fill` (today's full values, used wherever a template heading matches a category) and `appended_fill` (the trimmed values above, used only by `appended_sections`). `appended_filler` builds the second hash directly from `intent`/`plan`, sharing a `summary_text` helper with `filler` so the Summary computation isn't duplicated (ruby-style: extract on the second repetition, target ~5-line methods, one purpose per method).
- Acceptance-criteria extraction (requirement 4) is content-based, not indentation-based: keep only top-level (column 0) bullet lines from the plan's Proof section that contain a `→` arrow; the bullet marker may be `-` or `*`. A real plan's Proof section (the `plan` skill's own shape) carries a "Per changed file, the unit tests expected, named as behaviour:" lead-in and its per-file bullets, plus a "Test setup:" paragraph, all at column 0 alongside the acceptance-criteria bullets — so a column-0-only filter keeps them too. The arrow is the actual signal; indentation is not.
- `appended_sections` takes the new `appended_fill` hash in place of the general `fill` hash it reads today; `fill_template`'s categorized replacement keeps reading `fill` unchanged.

## Integration points

- `claude/.claude/skills/finish/scripts/fill-pr-template` — the script itself.
- `test/fill_pr_template_test.rb` — its Minitest suite; several existing tests assert today's Why-duplication and full-Implementation/Proof appended behavior and must be updated to match the new appended output (their names describe the old behavior and should be renamed to describe the new one).
- `claude/.claude/skills/finish/SKILL.md` §3 — prose describing the script's output.
- `docs/changes/ai-native-workflow/phases/04-finish.md` step 1 — the phase document describing the rule; updated in the same commit as the code.

## Acceptance criteria

- With no template, the PR body's Summary holds the Problem and the Proposed outcome → `test/fill_pr_template_test.rb`.
- With no template, the PR body has no Why section → `test/fill_pr_template_test.rb`.
- With no template, the PR body's Implementation section holds the file list only, not Order of work → `test/fill_pr_template_test.rb`.
- With no template, the PR body's Proof section holds the acceptance-criteria lines only, not a nested per-file unit-test list → `test/fill_pr_template_test.rb`.
- With no template and a plan with no Proof section, the PR body has no Proof heading → `test/fill_pr_template_test.rb`.
- With a template whose headings match Why, Implementation, and Test, each still gets today's full content (Problem text; file list plus Order of work; the whole Proof section) → `test/fill_pr_template_test.rb`.

---
Domain skills applied: ruby-style.
