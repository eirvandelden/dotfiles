# Review: js-hooks-use-npm

## Round 1 — 2026-10-29T11:25Z — b53c1580

- [ ] Nit: The two new public test methods carry no inline RBS signature (`#: () -> void`), which the design pass asks of every public method in the diff; `plan.md` `### Signatures` signs them and decides to keep bare `def`s to match the file's unannotated tests — `test/lefthook_local_hooks_test.rb:176` → fixed (Sign the browserslist tests with inline RBS)

No Important findings. Bugs: none; `npx --no` matches the stylelint and eslint jobs, and the `^…$` line anchors keep `npx browserslist` from matching. Security: none; no work references in the diff.

Compliance: criterion 1 → `test_pre_commit_browserslist_runs_through_npx_no`; criterion 2 → `test_pre_push_browserslist_runs_through_npx_no`; criterion 3 → checked by hand: `npx --no browserslist` in an empty directory exits 1 with "npx canceled due to missing packages" and installs nothing; criterion 4 → `test/lefthook_local_hooks_test.rb` 17 runs green, rubocop and yamllint clean, full `test/*_test.rb` suite green. Both Proof tests exist and fail against `origin/main`'s `lefthook.yml` with `Expected /^npx --no browserslist$/ to match "npx browserslist\n"`. No existing test was weakened, skipped or deleted. Files changed match the plan.

Suite note: `test/bi_test.rb` timed out twice (60 s `Timeout::Error`) under a load average of 174; both tests pass when run alone. Unrelated to this diff.

## Round 2 — 2026-10-29T12:10Z — a1e32c8c

No findings. The repository has no `REVIEW.md` or `REVIEW.local.md`; the reviewer defaults applied.

Bugs: none. Both `run` lines read `npx --no browserslist`, the same form as the stylelint and eslint jobs. Security: none; no work references in the diff. Design: the round 1 nit holds — both new tests carry `#: () -> void`, and they reuse the existing helpers with no new ones.

Compliance: criterion 1 → `test_pre_commit_browserslist_runs_through_npx_no`; criterion 2 → `test_pre_push_browserslist_runs_through_npx_no`; criterion 3 → the hand check recorded in round 1; criterion 4 → `test/lefthook_local_hooks_test.rb` 17 runs green, `rubocop` and `yamllint` clean. Every Proof test exists. No existing test was weakened, skipped or deleted.

Base note: the branch is 171 commits behind `origin/main` (base `2319e720`). `origin/main` rewrote parts of `test/lefthook_local_hooks_test.rb` but kept the helpers these tests use. `git merge-tree` reports no conflict, and both browserslist tests pass on the merged tree. Rebase before `deliver` (rule 20).
