## Round 1 — 2026-09-29T12:35:15Z — ecee6f35

Scope: `origin/main...HEAD` (d3eada23..ecee6f35), no uncommitted changes. `ruby test/herdr_config_test.rb`: 2 runs, 0 failures (herdr installed, so the config check ran). `rubocop test/herdr_config_test.rb`: no offenses. Full suite: only `test/lefthook_pull_hooks_test.rb` fails (2 failures, hook script hashes and `rails db:migrate` log); this branch does not touch it, so it is not listed as a finding here. Checked that herdr honours `HERDR_CONFIG_PATH` (an invalid file at that path makes `herdr config check` exit 1), so the test checks the worktree file and not the stowed one. The reproduction commit 06315565 has `delivery = "system"` and the new test, so the test was red before the fix. Public-repo check: no work-related names in the diff; "the one project using fastlane" in `intent.md` is unnamed.

Compliance:

- herdr's config check accepts `delivery = "terminal"` without diagnostics → `HerdrConfigTest#test_herdr_accepts_the_config` together with `#test_notifications_go_through_the_terminal_so_no_notifier_program_can_block_the_client`. Skipped in CI, where herdr is not installed, as the plan states.
- When an agent finishes, a notification appears and the session still takes keyboard input → missing as an automated test. The plan makes it a manual check after merge (`herdr server reload-config`, then watch for a Ghostty notification).
- Proof tests named in `plan.md`: `test/herdr_config_test.rb` exists with both behaviours.
- Existing tests weakened, skipped, or deleted: none.

- [ ] Nit: `toast_delivery` returns nil or raises `NoMethodError` on nil when the file formats the key any other way (`delivery="terminal"`, extra spaces, a trailing comment, a `[ui.toast]` header with a comment), so a valid config can fail with an error message that does not explain the problem. Consider a clear failure message when the section or key is not found — `test/herdr_config_test.rb:24` →
- [ ] Nit: `assert_equal("config: ok", output.strip)` depends on herdr's exact success wording, which a herdr upgrade can change even though the config is still valid. The exit status assertion on the line above already proves the config is accepted — `test/herdr_config_test.rb:18` →
- [ ] Nit: the second acceptance criterion (notification appears, session keeps taking input) has no recorded result. Record the manual post-merge check before `finish`, so the spec has evidence for it — `docs/changes/herdr-terminal-notifications/plan.md:12` →
