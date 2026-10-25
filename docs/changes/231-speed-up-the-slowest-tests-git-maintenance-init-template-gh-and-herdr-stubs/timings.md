# Timings

Same machine, same base (`main` 7713f122 plus `docs/changes/`), `bin/test` default `-j` (12). The machine is loaded, so runs are noisy. Spread = largest minus smallest. Baseline runs are in a clone of this branch before its first code commit.

## Baseline

| Run | Full `bin/test` | Four slow files | Seven harness files |
| --- | --- | --- | --- |
| 1 | 270 s | 133 s | 103 s |
| 2 | 261 s | 138 s | 99 s |
| 3 | 388 s | 151 s | 145 s |
| Median | 270 s | 138 s | 103 s |
| Spread | 127 s | 18 s | 46 s |

All three full runs: `87 files, 0 failed`. Counts: 1247 runs, 5796 assertions. Per-file counts of run 1 were kept for the final comparison.

Per-file seconds inside the full run (runs 1, 2, 3):

| File | Seconds |
| --- | --- |
| `herdr_worker_scripts_test.rb` | 208, 213, 301 |
| `deliver_test.rb` | 235, 215, 345 |
| `consent_guard_test.rb` | 221, 189, 340 |
| `worktree_create_test.rb` | 142, 189, 231 |
| `ship_test.rb` | 85, 76, 139 |
| `restore_test.rb` | 113, 101, 156 |
| `commit_plan_test.rb` | 40, 22, 33 |
| `commit_review_test.rb` | 39, 22, 43 |
| `open_pr_dash_test.rb` | 31, 23, 43 |
| `delivery_harness_test.rb` | 3.5, 1.8, 2.1 |

Four slow files = `herdr_worker_scripts`, `deliver`, `consent_guard`, `worktree_create`. Seven harness files = `deliver`, `ship`, `restore`, `commit_plan`, `commit_review`, `open_pr_dash`, `delivery_harness`.
