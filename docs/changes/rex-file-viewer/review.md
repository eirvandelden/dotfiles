## Round 1 — 2026-11-06T08:02Z — 17fc5c6d

Checks: viewer tests 30 runs green, rex_config_test green, rubocop clean, shellcheck -S warning (the repo's lefthook level) clean. Compliance: every acceptance criterion and every test named in plan.md Proof exists. No weakened, skipped or deleted test. Design: no public method outside Signatures, no Demeter chain, no query loop, no Avoid word.

- [ ] Nit: `list.sh` runs under `set -e` in a command substitution, so a git failure there ends the viewer with no notice; the layer closes at once and the cause is hidden — `rex/.config/rex/viewer/pick.sh:53` → fixed (rex viewer: show a notice when the list fails)
- [ ] Nit: `os.getenv("HOME")` can be nil, and the concatenation then raises inside the action with no message — `rex/.config/rex/viewer.lua:24` → dismissed: `switcher.lua` opens its layer with the same `os.getenv("HOME")` call, and Rex runs actions with the login environment, so HOME is always set
- [ ] Nit: plain `shellcheck` (no `-S`) reports three SC2016 infos for the intentional single-quoted fzf binds; the repo gate is `-S warning`, so it passes, but a comment saying the quotes are deliberate would help — `rex/.config/rex/viewer/pick.sh:11` → dismissed: the repository gate is `-S warning`, which passes, and `switcher/pick.sh` has the same single-quoted binds without a comment

## Round 2 — 2026-11-06T08:04Z — 9b039334

Checks: viewer tests 31 runs green, shellcheck -S warning clean. Round 1 fix verified: a failing `list.sh` now shows the notice and never starts fzf, and `test_a_failing_list_shows_a_notice_and_never_starts_fzf` covers it and is listed in plan.md. Both dismissals accepted: `switcher.lua` and `switcher/pick.sh` set the precedent, and the repo gate passes. Nothing found.
