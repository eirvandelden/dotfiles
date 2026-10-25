# Profile: where the four slow files spend their time

Measured on `main` (7713f122) plus `docs/changes/` only, on a loaded 12-core Mac (load average 18–25 at the start). Solo runs: `ruby -Itest test/<file> -v`, all four at once. One-test traces: `GIT_TRACE=<file> ruby -Itest test/<file> -n <test>`.

No test dominates a file. Every test costs two to six seconds, so the time is per-test process start-up, repeated in every test: `git init`, a commit or two, and the script under test with its stubs.

## `herdr_worker_scripts_test.rb` — 87 tests, 118 s solo, 208–301 s in the full run

- Slowest: `test_done_means_wording_is_only_in_the_implement_stage` 4.6 s, `test_every_stage_splits_its_pane_below` 3.8 s, `test_the_plan_worker_commits_intent_and_plan_then_pushes` 3.5 s. The tenth is 2.3 s.
- One test (`test_every_stage_splits_its_pane_below`): 80 git commands, 2 `git init`, 1 commit, and 15 `git maintenance run --auto --quiet --detach` children. Real time 7.0 s.
- The `herdr` and `git` stubs here are already `sh` scripts. The cost is git: the repository set-up in `setup`, the scripts' own git calls, and the detached maintenance children. The git-settings speed-up targets this file.

## `deliver_test.rb` — 30 tests, 88 s solo, 215–345 s in the full run

- Slowest: `test_fills_the_body_from_the_repository_template` 4.2 s, then 20 tests between 3 and 4 s. About 3 s per test.
- One test (`test_fills_the_body_from_the_repository_template`): 60 git commands, 2 `git init`, 7 commits, 27 maintenance children. Real time 17.2 s while the other three traces ran.
- Each `gh`/`herdr` call boots Ruby (`test/delivery_harness.rb` Ruby stub), and the script under test makes dozens of them. Both speed-ups, git settings and shell stub, target this file.

## `consent_guard_test.rb` — 122 tests, 78 s solo, 189–340 s in the full run

- Slowest: `test_install_in_any_command_position_is_refused` 3.4 s, then every test under 1.8 s. About 0.65 s per test.
- One test (`test_a_push_hidden_behind_shell_syntax_is_still_checked`): 17 git commands, 1 `git init`, no commit, no maintenance. Real time 2.2 s.
- `setup` runs `git init` on every test, and each guard call starts the Ruby guard script, which is the script under test and stays unchanged. The git-settings speed-up (template) removes the sample-hook copy from the `git init`. The test file has no stub of its own.

## `worktree_create_test.rb` — 37 tests, 91 s solo, 142–231 s in the full run

- Slowest: `test_a_branch_pushed_under_its_own_name_goes_once_origin_holds_its_work` 6.2 s, `test_reusing_a_worktree_replaces_the_panes_record` 4.4 s, `test_a_fetch_slower_than_the_sweep_time_limit_still_brings_origin_main_up_to_date` 4.0 s.
- One test (`test_creates_a_worktree_off_the_default_branch_and_prints_its_path`): 33 git commands, 1 `git init`, 2 clones, 1 commit, 9 maintenance children. Real time 5.7 s.
- `setup` builds a bare origin and a clone, and installs a Ruby `gh` stub and a Ruby `herdr` stub that each `require "json"`. The script sweeps worktrees with many git calls. The git-settings speed-up targets the maintenance children and sample hooks (two `init`/`clone` per test). The Ruby stubs are a candidate for step 7.
