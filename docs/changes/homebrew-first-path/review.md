## Round 1 — 2026-11-03T12:57:27Z — 31760a91

Passes: Bugs, Security, Compliance, Design (defaults from `agents/.agents/skills/new-repo-setup/references/REVIEW.md`; the repository has no `REVIEW.md`). No Important finding.

Compliance: all four planned files changed as planned, nothing unplanned. Every `## Proof` test exists. No existing test is weakened; the `path_helper` stand-in is now stricter. At `2443984e` the new tests fail (7 failures, 2 errors); at `31760a91` the file passes (29 runs). Acceptance criteria: non-login, login, interactive, stripped PATH, inherited `HOMEBREW_PREFIX` and rv order each map to a named test; `python3 --version` and Claude Code's Bash tool are manual (checks 1–4, and check 6 after merge).

Evidence: the reviewer replayed manual checks 1, 2, 4 and 5 against the worktree files. `git`, `python3`, `openssl` resolve to `/opt/homebrew/bin`, `curl` to `/opt/homebrew/opt/curl/bin`, `ruby` to rv's 4.0.9; `git version 2.56.0`, `Python 3.15.2`; check 5 prints `/opt/homebrew`. Check 6 still waits for the merge.

Checks: `bin/test test/node_path_order_test.rb` and `test/secrets_loader_test.rb` green; `shellcheck -S warning -s bash zsh/.config/zsh/paths.zsh` clean; RuboCop clean on both test files with the `rubocop-rbs_inline` cops removed, because that plugin is not installed on this Mac.

Outside this diff: the full `bin/test` has one failure, `test/herdr_config_test.rb:11` (expects `delivery = "terminal"`, finds `"system"`). Commit `8363835d` on `origin/main` made that change, so CI on this branch goes red too. Playbook rule 25 sends it to its own worktree and pull request.

- [ ] Nit: the git test asserts through `assert_first_node`, a helper named for node; a neutral name (or a small `assert_first_tool`) reads truer — `test/node_path_order_test.rb:265` → dismissed: the helper already served the ruby and codex tests before this change; a rename would churn about 25 unrelated lines (rule 21)
- [ ] Nit: `resolved_tools` re-sorts `command -v` output that already comes in argument order; the sort adds a lookup per line and turns an unknown line into an `ArgumentError` instead of a plain assertion failure — `test/node_path_order_test.rb:329` → fixed (test: tighten the Homebrew order tests)
- [ ] Nit: the stripped-PATH test checks `/usr/bin` after Homebrew but never `/bin`, which the acceptance criterion also names — `test/node_path_order_test.rb:278` → fixed (test: tighten the Homebrew order tests)
- [ ] Nit: "shim" is an `Avoid:` word in `GLOSSARY.md` (for Binstub); the new test name and the `.zprofile`/`paths.zsh` comments use "codex shim". The plan keeps the term on purpose and left a `Decision needed`; close this finding with that decision — `test/node_path_order_test.rb:305` → dismissed: "unlocked codex shim" is the repo's established name in the paths.zsh header and tests, and the plan kept it on purpose; Etienne can add a glossary term later

## Round 2 — 2026-11-03T13:40:00Z — 3f1eb50f

Passes: Bugs, Security, Compliance, Design (defaults from `agents/.agents/skills/new-repo-setup/references/REVIEW.md`; the repository has no `REVIEW.md`). No Important finding. No nit.

Since round 1: `3f1eb50f` changes `test/node_path_order_test.rb` only. The stripped-PATH test now checks `/bin` and `/usr/bin` after Homebrew, and `resolved_tools` keeps `command -v` order as printed. Both round 1 fixes hold. The two dismissed nits stay dismissed with their reasons.

Bugs: `brew shellenv` under `PATH=/usr/bin:/bin` prints `export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}"`, so the eval expands this shell's PATH, not the brew command's. The `HOMEBREW_PATH` guard in `shellenv.sh:10` no longer fires. `environment.zsh` (`set_local_bin_path`) strips only `.git/*bin` entries and does not move Homebrew.

Security: nothing new. No secrets, no external input.

Compliance: the diff still matches `plan.md`; every `## Proof` test exists; no test is weakened.

Evidence: replayed manual check 2 (login, real `/etc/zprofile`) against the worktree files. `git`, `python3`, `openssl` resolve to `/opt/homebrew/bin`, `curl` to `/opt/homebrew/opt/curl/bin`, `ruby` to rv's 4.0.9; `git version 2.56.0`, `Python 3.15.2`. Check 6 still waits for the merge.

Checks: `bin/test test/node_path_order_test.rb` (29 runs) and `test/secrets_loader_test.rb` (28 runs) green; `shellcheck -S warning -s bash zsh/.config/zsh/paths.zsh` clean; RuboCop clean on both test files with the `rubocop-rbs_inline` cops removed, because that plugin is not installed on this Mac.

Outside this diff: the full `bin/test` still has one failure, `test/herdr_config_test.rb:11` (expects `delivery = "terminal"`, finds `"system"`), from `8363835d` on `origin/main`. `origin/main` has no newer commit that fixes it. Playbook rule 25 sends it to its own worktree and pull request.
