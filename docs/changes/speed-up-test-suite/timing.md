# Timing: speed up the dotfiles test suite

Measured on this Mac (12 CPUs) with `bin/test`, one run each, under heavy machine load (load average above 50, Microsoft Defender at about 180% CPU). Both runs use the runner from PR #229. Treat the numbers as indicative.

| Tree | Files | Failed | Wall time |
| --- | --- | --- | --- |
| `origin/main` (b9e446c5), exported with `git archive` | 86 | 3 | 515 s |
| This branch | 87 | 0 | 281 s |

The three failures on the exported `main` are `herdr_config_test.rb`, `rbs_inline_tooling_test.rb` and `skill_parity_hook_test.rb`. They fail because an export has no `.git`. They are an effect of how the baseline was taken, not a defect of `main`.

Slowest files on `main`: `branch_guard_test.rb` 484 s, `deliver_test.rb` 418 s, `worktree_create_test.rb` 415 s, `herdr_worker_scripts_test.rb` 409 s and `consent_guard_test.rb` 348 s.

Slowest files on this branch: `herdr_worker_scripts_test.rb` 241 s, `deliver_test.rb` 233 s, `consent_guard_test.rb` 216 s and `worktree_create_test.rb` 186 s. `branch_guard_test.rb` no longer leads. The four slowest files do not depend on hooks and are the next target.
