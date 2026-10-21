# Review: global-sig-ignore

## Round 1 — 2026-10-18T09:29Z — 049a26f7 (codex)

No findings. `codex review --base origin/main` ran the new test file (5 runs, 0 failures) and found no actionable defects.

## Round 2 — 2026-10-18T09:30Z — dc2b41a3 (claude)

- [ ] Important: The gem CI recipe starts with `rm -rf sig`, which also deletes a hand-written `sig/manifest.yaml`. RBS 4.2 `docs/gem.md` ("Adding manifest.yaml") puts that file in the gem's `sig/` to declare stdlib dependencies. A gem that has one fails `git diff --exit-code sig/` on every run, or drops the file to get green. Regenerate without deleting `manifest.yaml` (for example, remove only `sig/**/*.rbs`), and say in step 12 that `manifest.yaml` is the one hand-written file there — `agents/.agents/skills/new-repo-setup/SKILL.md:54` → fixed (new-repo-setup: keep sig/manifest.yaml and read every file in gem CI)

Passes: Bugs — one finding above. Security — none; the diff has no secrets and no work references. Compliance — each acceptance criterion maps to its `plan.md` Proof test in `test/global_sig_ignore_test.rb`, and all five exist and pass (5 runs, 0 failures). `test/rbs_inline_tooling_test.rb` is unchanged and green (15 runs). RuboCop is clean on the new test. No existing test is weakened, skipped or deleted.

## Round 3 — 2026-10-18T09:33Z — 426b04af (codex)

No findings. `codex review --base origin/main` found the ignore rules, the gem exception and the CI regeneration guidance consistent, with the focused tests passing.

## Round 4 — 2026-10-18T09:35Z — eb6fa25b (claude)

No findings.

Passes: Bugs — none. The recipe flags match rbs-inline 0.14.0's CLI: `--opt-out` exists, and the default `--base` of `lib` maps `lib/foo.rb` to `sig/foo.rbs`. `find sig -name '*.rbs' -delete` keeps `sig/manifest.yaml`, and `git diff --exit-code sig/` also catches a deleted `.rbs` file whose source is gone. No tracked path in this repository falls under `sig/` or `.gem_rbs_collection/`. Security — none; no secrets and no work references in the diff. Compliance — the repository has no `REVIEW.md`, so the default passes apply. Each acceptance criterion maps to its `plan.md` Proof test in `test/global_sig_ignore_test.rb`; all five exist, plus the round 2 manifest test, and pass (6 runs, 0 failures). `test/rbs_inline_tooling_test.rb` is unchanged and green (15 runs). RuboCop is clean on the new test. The recipe differs from `plan.md` (`find … -delete` instead of `rm -rf sig`, plus `--opt-out`); round 2 records that change. No existing test is weakened, skipped or deleted.

## Round 5 — 2026-10-21T12:37Z — f02952cf (claude)

No findings.

Passes: Bugs — none. The new gem CI recipe holds in a scratch repository with `!sig/`: a clean `sig/` passes; a modified, a deleted and a new nested `.rbs` each fail; `find sig -name '*.rbs' -delete` keeps `sig/manifest.yaml`. `test -z "$(git ls-files --others --exclude-standard -- sig/)"` sees new files through the gem's `!sig/`, also under the global excludes, which `test_gem_sig_ci_step_fails_on_a_generated_file_git_does_not_hold` proves with the shipped git config. Security — none; no secrets and no work references in the diff. Compliance — the repository has no `REVIEW.md`, so the default passes apply. Each acceptance criterion maps to its `plan.md` Proof test in `test/global_sig_ignore_test.rb`; all five exist, plus the manifest test and the three amendment tests (deleted source, untracked generated file, matching `sig/`), and pass (9 runs, 0 failures). `test/rbs_inline_tooling_test.rb` is unchanged and green (15 runs). The full suite is green (70 files). RuboCop is clean on the new test. No existing test is weakened, skipped or deleted. The no-hardwrap rule flags `intent.md` lines 3–4, where `Delivery: autonomous` sits below `Status:` as the `intent` skill prescribes; that file is a change-folder record that `deliver` removes, so it is not a finding. The per-file test notes in `plan.md` still name the pre-amendment `--intent-to-add` commands; the amendment section supersedes them. Design — no Ruby production code; the test file defines no public API beyond Minitest test methods.
