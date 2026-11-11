## Round 1 — 2026-11-11T13:29:00Z — 10865896

- [x] Important: A tab or space missing from the document (a fresh tab the app has not yet persisted) is not treated as drift. `drifted` returns false when `tabOf` finds nothing, `planFor` returns `[]`, and `settle` then sets `lastApplied`, so there is no retry and the pane is skipped until focus leaves it. Only a machine space should stay quiet. This is the doc-lag case the plan's Risks section promises to retry — `herdr-app/.config/herdr-app/mods/golden-ratio/planner.js:57` → fixed (6888d057 Retry the golden-ratio mod when the tab is missing from the document)
- [x] Nit: `settle` sets `lastApplied` after a zoomed or no-op pass, so unzooming with the same pane focused does not rebalance — `herdr-app/.config/herdr-app/mods/golden-ratio/controller.js:51` → fixed (22a8edc2 Re-evaluate the golden-ratio pane when its tab is unzoomed)
- [x] Nit: `plan` counts a `stack` container as an axis and resizes its children, though a stack shows one child and has no weights; restrict to `row` and `column` — `herdr-app/.config/herdr-app/mods/golden-ratio/planner.js:41` → fixed (d9003a0e Treat only rows and columns as axes in the golden-ratio planner)
- [x] Nit: The README paragraph has a sentence of about 45 words, above the 20-word STE limit; split it — `herdr/.config/herdr/README.md:90` → fixed (106dad86 Split the long golden-ratio sentence in the herdr README)

Checks: 26 tests green (golden-ratio and package), rubocop and markdownlint clean. Every Proof test named in `plan.md` exists; no existing test weakened. The sandbox mount check (zero-size block) is not covered in this round.

## Round 2 — 2026-11-11T13:43:49Z — 106dad86

Nothing found. Round 1 fixes verified: missing tab is drift and retried once (6888d057), unzoom re-evaluates through the zoom-aware state key (22a8edc2), only row and column count as axes (d9003a0e), README sentence split (106dad86). No regression seen: a machine space stays quiet, a superseded run submits nothing, a drifted tab after one retry stays quiet until the next focus change as planned.

Checks: 32 tests green (golden-ratio and package), rubocop and markdownlint clean. Every Proof test exists; no existing test weakened. The zero-size block mount and resize were proven live in the sandbox.

## Round 3 — 2026-11-11T19:47:31Z — a00095b0

Nothing found. Commit 28b8fe75 adds one `require_relative "isolated_git"` to the golden-ratio test; the helper exists at `test/isolated_git.rb`. a00095b0 only touches the change folder.

Checks: 32 golden-ratio tests green, rubocop clean. Every Proof test exists; no existing test weakened.
