# Review: global-sig-ignore

## Round 1 — 2026-10-18T09:29Z — 049a26f7 (codex)

No findings. `codex review --base origin/main` ran the new test file (5 runs, 0 failures) and found no actionable defects.

## Round 2 — 2026-10-18T09:30Z — dc2b41a3 (claude)

- [ ] Important: The gem CI recipe starts with `rm -rf sig`, which also deletes a hand-written `sig/manifest.yaml`. RBS 4.2 `docs/gem.md` ("Adding manifest.yaml") puts that file in the gem's `sig/` to declare stdlib dependencies. A gem that has one fails `git diff --exit-code sig/` on every run, or drops the file to get green. Regenerate without deleting `manifest.yaml` (for example, remove only `sig/**/*.rbs`), and say in step 12 that `manifest.yaml` is the one hand-written file there — `agents/.agents/skills/new-repo-setup/SKILL.md:54` → fixed (new-repo-setup: keep sig/manifest.yaml and read every file in gem CI)

Passes: Bugs — one finding above. Security — none; the diff has no secrets and no work references. Compliance — each acceptance criterion maps to its `plan.md` Proof test in `test/global_sig_ignore_test.rb`, and all five exist and pass (5 runs, 0 failures). `test/rbs_inline_tooling_test.rb` is unchanged and green (15 runs). RuboCop is clean on the new test. No existing test is weakened, skipped or deleted.

## Round 3 — 2026-10-18T09:33Z — 426b04af (codex)

No findings. `codex review --base origin/main` found the ignore rules, the gem exception and the CI regeneration guidance consistent, with the focused tests passing.
