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

## Method change

The machine was at load average 30–225 for part of the work (other agent sessions, Microsoft Defender), so the first after-runs were useless: the four slow files took 379–631 s. The gate therefore uses interleaved pairs instead of the separate baseline above: base and branch alternate (base 1, branch 1, base 2, ...), three pairs, on the same quiet machine. Wall seconds and CPU seconds (user plus system of the whole `bin/test` tree) are both recorded. The base is a clone at `main` plus `docs/changes/`, or at the previous commit where a later speed-up is judged. The separate baseline above stays as the record of the first measurement.

The four slow files wait more than they compute: solo, `worktree_create_test.rb` takes 70 s wall and 25 s CPU on an idle machine. Most of the gap is process exec and file-system waiting (Defender scans), which test code cannot remove.

## Speed-up 1: git quiet settings and hookless template (kept)

Four slow files, base is `main`. Quiet machine (load about 4):

| Pair | Base wall / CPU | Branch wall / CPU |
| --- | --- | --- |
| 1 | 114 s / 145 s | 105 s / 147 s |
| 2 | 105 s / 142 s | 97 s / 134 s |
| 3 | 108 s / 141 s | 96 s / 134 s |
| Median | 108 s / 142 s | 97 s / 134 s |
| Spread | 9 s / 4 s | 9 s / 13 s |

Gate on wall time: median drop 11 s, larger spread 9 s, so it stays. The gain is small, about 10 % of wall time. CPU time drops 8 s, which is inside the CPU spread. An earlier set of pairs ran while the machine was loaded (load 50–225): base 726, 272, 143 s and branch 719, 144, 106 s, which proves nothing.

## Speed-up 2: shell stub for `gh` and `herdr` (dropped)

Seven harness files, base is the git-settings commit. The branch held the 12 new contract tests, which add about 4–8 s to `delivery_harness_test.rb`.

First design (a directory of files per response):

| Pair | Base wall / CPU | Branch wall / CPU |
| --- | --- | --- |
| 1 | 70 s / 67 s | 77 s / 72 s |
| 2 | 63 s / 67 s | 82 s / 72 s |
| 3 | 66 s / 67 s | 79 s / 73 s |

Slower: each `stub_response` rewrote about 40 small files, and `setup_harness` calls it five times (37 ms per test setup against 5 ms).

Second design (at most one file per response part, only when non-empty, incremental writes; setup 7 ms, stub call 45 ms against 63 ms):

| Pair | Base wall / CPU | Branch wall / CPU |
| --- | --- | --- |
| 1 | 65 s / 66 s | 64 s / 66 s |
| 2 | 63 s / 67 s | 62 s / 66 s |
| 3 | 71 s / 67 s | 70 s / 67 s |
| Median | 65 s / 67 s | 64 s / 66 s |
| Spread | 8 s / 1 s | 8 s / 1 s |

`deliver_test.rb` alone: base 64.5, 63.0, 71.3 s; branch 64.0, 61.5, 69.7 s. Gate: median drop 1 s, spread 8 s, so the speed-up is dropped. The Ruby stub already starts with `--disable-gems`, so a shell stub saves about 18 ms per call and loses it again in table writes. The change, its contract tests and the matching `plan.md` edits were not committed.

## Speed-up 3: `--disable-gems` for the Ruby stubs in `worktree_create_test.rb` (dropped)

Profile cause from step 7: the `gh` and `herdr` stubs there start Ruby with full RubyGems. One-line change to both shebangs. `worktree_create_test.rb`, base is the git-settings commit:

| Pair | Base wall / CPU | Branch wall / CPU |
| --- | --- | --- |
| 1 | 75 s / 27 s | 72 s / 24 s |
| 2 | 69 s / 26 s | 70 s / 23 s |
| 3 | 71 s / 25 s | 73 s / 23 s |
| Median | 71 s / 26 s | 72 s / 23 s |
| Spread | 6 s / 2 s | 3 s / 1 s |

Gate: wall median did not drop, so the change is dropped and not committed. CPU drops 3 s, but the file waits on the disk and on exec, not on CPU.

## Final: full `bin/test`

Interleaved pairs, base is `main` plus `docs/changes/`, branch is this change (speed-up 1 only):

| Pair | Base wall / CPU | Branch wall / CPU |
| --- | --- | --- |
| 1 | 160 s / 456 s | 160 s / 461 s |
| 2 | 178 s / 510 s | 161 s / 506 s |
| 3 | 181 s / 518 s | 171 s / 515 s |
| Median | 178 s / 510 s | 161 s / 506 s |
| Spread | 21 s / 62 s | 11 s / 54 s |

The median wall time after is lower than on `main` (161 s against 178 s, 10 %), the acceptance criterion. The gain is within one base spread, so it is small and not a strong result. CPU time is flat.

Every run: `87 files, 0 failed`. Per-file test and assertion counts equal the baseline for 86 files; `isolated_git_test.rb` grew from 8 runs and 16 assertions to 15 runs and 31 assertions (the new tests).

## Follow-ups

- The 4 slow files wait on process start-up and file-system scans, not on Ruby. Building a repository once per file and copying it, and splitting large files across workers, stay out of scope here and are the next candidates (`intent.md`).
- Each guard or script call in `consent_guard_test.rb` starts the Ruby script under test (about 0.65 s per test); that is the script's start-up, outside test code.
