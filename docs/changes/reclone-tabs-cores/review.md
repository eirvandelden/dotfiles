# Review: Re-clone the tabs-cores mod from the installed tabs mod

## Round 1 — 2026-11-19T15:16:51Z — 190f9a20

Nothing found. The repository has no root `REVIEW.md` or `REVIEW.local.md`; this round follows the four passes of `agents/.agents/skills/new-repo-setup/references/REVIEW.md`.

Bugs: `tabs-cores/main.js` equals the test's `cloned_main` transform of the shipped `~/.config/herdr-app/mods/tabs/main.js` byte for byte (`diff` empty), with herdr-app 0.1.16 installed. The padding stays `Math.max(10, (root.traffic_lights[0] + 64) / settings().zoom)` with no `sidebar?.size?.px`. The four `win-*.svg` files are byte-equal to the shipped ones (`cmp`). The new `main.js` code is the shipped mod's own, so the clone adds no behaviour of its own beyond the padding.

Security: no input handling, secrets or external calls are added; the guarded `localStorage` read comes from the shipped mod.

Compliance: the diff touches exactly the two files `plan.md` names, plus the change folder. `mod.json` changes only `cloned_from.version` to `0.1.16`, keeping its formatting. No test changed. Acceptance criteria: `ruby test/herdr_app_look_test.rb` (rv Ruby 4.0.9) runs 27 tests, 0 failures, 0 skips; `bin/test` reports 126 files, 0 failed. The `cloned_from.version` criterion has no test, as `plan.md`'s Proof states; its check prints `"0.1.16"`, and `intent.md` puts test changes out of scope. Lefthook pre-commit on the changed files passes; ESLint only warns that `main.js` is ignored by design. The branch sits on current `origin/main` (0 commits behind).

Design: no Ruby or JavaScript interface changes, so no signatures apply. No glossary `Avoid:` term appears in the added lines.
