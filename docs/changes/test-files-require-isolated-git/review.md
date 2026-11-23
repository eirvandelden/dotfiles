# Review: test-files-require-isolated-git

The repository has no `REVIEW.md` or `REVIEW.local.md`. This round runs the Bugs, Security, Compliance and Design passes against the playbook, `intent.md` and `plan.md`.

## Round 1 — 2026-11-23T10:53Z — ef0b7d3b

The branch is level with origin/main, and the working tree was clean. Checks: with rv's Ruby 4.0.9, `bin/test` on `test/isolated_git_test.rb`, `test/worktree_guard_test.rb` and `test/worktree_first_skill_test.rb` ran 71 tests with 0 failures and 0 errors. rubocop on the three changed files reports no offenses. Every `test/*_test.rb` holds `require_relative "isolated_git"`, and no Ruby file defines `WITHOUT_GLOBAL_GIT_CONFIG`. Bugs: the extracted assertion strips the root prefix from glob results that start with the same root, so the message names `test/<file>`; the constant check's regex does not match its own line. Both changed files require the helper before their class bodies, so the dropped explicit `GIT_CONFIG_GLOBAL` reaches every child through `ENV`; no call uses `unsetenv_others`. Compliance: the first, second and fourth acceptance criteria map to `test_a_file_without_the_helper_is_named_by_its_test_path`, `test_every_test_file_requires_the_helper` and `test_no_test_file_defines_its_own_git_config_constant`. The plan's departures record that `review_push_hook_test.rb` and `lefthook_rubocop_git_gem_test.rb` no longer exist on main, so the third criterion holds for `bi_test.rb` alone. Security: the change touches tests only and adds no shell, input or dependency.

- [ ] Nit: The `GitFixture` block still passes its own `{ "GIT_CONFIG_GLOBAL" => "/dev/null" }` to `git init`. It is the same partial copy the intent removes: the helper already sets both values in `ENV` before the class body runs. Drop the hash, as the branch did in the two `git` helpers — `test/worktree_guard_test.rb:22` → fixed (Drop the redundant GIT_CONFIG_GLOBAL from the guard test's git init)

## Round 2 — 2026-11-23 — c3fb1a5b

The branch contains origin/main, and the working tree holds only this file. Checks: with rv's Ruby 4.0.9, `bin/test` on `test/isolated_git_test.rb`, `test/worktree_guard_test.rb` and `test/worktree_first_skill_test.rb` reports 3 files, 0 failed. rubocop on the three files reports no offenses. Bugs: c3fb1a5b drops the hash from the `GitFixture` `git init`. `GitFixture.new` only stores the block, and `require_relative "isolated_git"` runs before the class body, so `git init` still sees both values from `ENV`. Round 1's nit is fixed. No other Ruby file defines `WITHOUT_GLOBAL_GIT_CONFIG`. Security: tests only; no shell, input or dependency change. Compliance and Design: no change from round 1.

No findings.
