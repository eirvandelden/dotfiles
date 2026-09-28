# Review: fill-pr-template-no-template

No `REVIEW.md` or `REVIEW.local.md` at the repository root; passes and severity follow the default policy in `claude/.claude/skills/new-repo-setup/references/REVIEW.md`.

## Round 1 — 2026-09-28T11:23Z — e9525243

Bugs:

- [x] Important: The appended Proof still includes the per-file unit-test list for plans written in the `plan` skill's own format. `claude/.claude/skills/plan/SKILL.md:46` puts that list at column 0, after a lead-in line ("Per changed file, the unit tests expected, named as behaviour:"), so `/^-\s/` keeps it. Only the lead-in line is removed. To reproduce: run the script with an empty template on this branch's own `intent.md` and `plan.md`. The output's `## Proof` ends with the `` - `claude/.claude/skills/finish/scripts/fill-pr-template`: `summary_text` builds… `` bullet. This means requirement 4 fails on real plans. The design decision assumed the per-file list is "written more indented", but the plan template does not write it that way. The `PLAN_WITH_NESTED_PROOF` fixture uses a nesting that real plans do not use, so the test passes and the bug stays. — `claude/.claude/skills/finish/scripts/fill-pr-template:78` → fixed (Filter fill-pr-template's Proof by arrow, not indentation)

Security: nothing found.

Compliance:

- [x] Important: Nothing proves the categorized half of spec requirement 6, "a matched Test heading still gets the plan's whole Proof section". `test_a_plain_template_gets_its_matching_headings_filled` uses `PLAN`, whose Proof is one column-0 bullet. The trimmed and the whole Proof are identical for that fixture, so the test would still pass if the categorized path also used `acceptance_criteria`. (A manual run with a `## Testing` template on this branch's plan keeps the per-file list, so the behaviour is correct today. Only the test is missing.) — `test/fill_pr_template_test.rb:91` → fixed (Match fill-pr-template's Proof fixture to a real plan's shape)
- [x] Important: The Summary criterion ("holds the Problem and the Proposed outcome") maps to `test_no_template_produces_three_sections_from_intent_and_plan_alone`. That test asserts only the Problem text. No no-template test asserts the Proposed outcome ("export status appears on the claim page"). — `test/fill_pr_template_test.rb:377` → fixed (Match fill-pr-template's Proof fixture to a real plan's shape)
- [x] Nit: `plan.md`'s Proof maps "Implementation holds the file list only, not Order of work" to `test_no_template_produces_three_sections_from_intent_and_plan_alone`. That test has no `assert_no_match(/Write the acceptance test/)`. Only the new nested-proof test checks this. The criterion is covered, but by a different test than the one the plan names. — `test/fill_pr_template_test.rb:377` → fixed (Match fill-pr-template's Proof fixture to a real plan's shape)
- [x] Nit: `APPEND_ORDER` still lists `[ :why, "Why" ]`. The appended set never has Why now, and `appended_filler` returns `why: ""` only so that the empty check removes it. Removing the Why entry and the `why:` key would make the rule visible in the code. — `claude/.claude/skills/finish/scripts/fill-pr-template:19` → fixed (Filter fill-pr-template's Proof by arrow, not indentation)
- [x] Nit: A Proof bullet that wraps onto an indented second line loses its continuation, because the column-0 filter drops the second line with the nested list. A Proof written with `*` bullets loses every line, and then the Proof heading disappears. The no-hardwrap rule makes the first case rare, but the column-0 rule has no test for either case. — `claude/.claude/skills/finish/scripts/fill-pr-template:78` → fixed (Filter fill-pr-template's Proof by arrow, not indentation)

Existing tests: none weakened, skipped, or deleted. The two renamed tests changed `assert_match(/## Why/)` to `assert_no_match`, as the spec requires. `ruby test/fill_pr_template_test.rb`: 27 runs, 0 failures.
