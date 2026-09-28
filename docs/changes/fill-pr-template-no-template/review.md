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

## Round 2 — 2026-09-28T11:40Z — f41c7197

Bugs:

- [x] Important: `test_an_appended_proof_section_drops_the_real_plans_per_file_unit_test_list` reads `docs/changes/fill-pr-template-no-template/intent.md` and `plan.md`. The `finish` skill runs `git rm -r docs/changes/<slug>` before it pushes, so after `finish` these files do not exist. The script then fails on `File.read`, `status.success?` is false, and the test fails. `.github/workflows/dotfiles-tests.yml:42` runs every `test/*_test.rb`, so CI goes red on the PR and on `main` after merge. `test_an_appended_proof_section_drops_the_per_file_unit_test_list_after_its_lead_in` already proves the same behaviour with the `PLAN_WITH_NESTED_PROOF` fixture, which has the real plan's shape. — `test/fill_pr_template_test.rb:443` → fixed (Delete Proof test that reads files finish deletes)

Security: nothing found.

Compliance:

- [x] Important: `plan.md`'s Proof maps the "Proof section holds the acceptance-criteria lines only" criterion to `test_an_appended_proof_section_drops_a_nested_per_file_unit_test_list`. No test has that name. The test that proves the criterion is `test_an_appended_proof_section_drops_the_per_file_unit_test_list_after_its_lead_in`. — `docs/changes/fill-pr-template-no-template/plan.md:36` → fixed (Fix plan.md Proof line's test name)
- [x] Nit: `plan.md` still describes the column-0 rule that round 1 replaced. Order of work step 3 says "keep only lines matching `/^-\s/`". Risks says the per-file list "is written more indented specifically so a column-0-only match is sufficient". The per-file note under Proof says `acceptance_criteria` "drops indented lines". The code and `spec.md` now use the `→` arrow filter. — `docs/changes/fill-pr-template-no-template/plan.md:18` → fixed (Describe the arrow-based Proof filter in plan.md)
- [x] Nit: The script's header comment still says "Any of the four categories" and "that means all four". The appended set has three categories now, and it uses trimmed content. — `claude/.claude/skills/finish/scripts/fill-pr-template:6` → fixed (Trim script header comment to three categories)
- [x] Nit: `04-finish.md` step 1 says the appended Proof holds "the plan's top-level acceptance-criteria lines, not any nested per-file unit-test list". The code keeps bullets that contain `→` and ignores indentation, so a real plan's column-0 per-file list is dropped because it has no arrow, not because it is nested. `SKILL.md` §3 says "acceptance-criteria lines only", which is correct. — `docs/changes/ai-native-workflow/phases/04-finish.md:21` → fixed (Describe the arrow-based Proof filter in 04-finish.md)
- [x] Nit: A plan whose Proof bullets have no `→` (older plans, or a hand-written plan) now gets no `## Proof` heading at all, with no warning. The categorized path would still include that Proof. No test covers this case. It may be acceptable, but nothing states the decision. — `claude/.claude/skills/finish/scripts/fill-pr-template:74` → fixed (Keep all Proof bullets when none carry an arrow)

Criteria to tests:

- Summary holds Problem and Proposed outcome: `test_no_template_produces_three_sections_from_intent_and_plan_alone`.
- No Why section: `test_no_template_produces_three_sections_from_intent_and_plan_alone`, `test_a_template_with_no_matching_headings_gets_three_sections_appended`.
- Implementation holds the file list only: `test_no_template_produces_three_sections_from_intent_and_plan_alone`.
- Proof holds criteria lines only: `test_an_appended_proof_section_drops_the_per_file_unit_test_list_after_its_lead_in`, `test_an_appended_proof_section_keeps_an_asterisk_bullet_with_an_arrow`.
- No plan Proof means no Proof heading: `test_a_missing_proof_in_the_plan_is_not_appended_as_an_empty_heading`.
- Categorized path unchanged: `test_a_plain_template_gets_its_matching_headings_filled`, `test_a_matched_testing_heading_still_gets_the_plans_whole_proof_section`.

Existing tests: none weakened, skipped, or deleted. `ruby test/fill_pr_template_test.rb`: 27 runs, 0 failures. Rubocop on both touched Ruby files: no offenses.
