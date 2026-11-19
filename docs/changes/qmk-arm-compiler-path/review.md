# Review: qmk-arm-compiler-path

## Round 1 — 2026-10-27T06:32:54Z — dffe4a29

No findings.

The repository has no `REVIEW.md` or `REVIEW.local.md`, so this round uses the reviewer's default passes.

Bugs: none. The `[[ -d ]]` guard adds only existing directories. `typeset -gU path` drops duplicates. rv (step 4) still prepends its paths ahead of the new entries. `.zprofile` does not rebuild PATH, so login shells keep the entries after `path_helper`.

Security: none. The change appends two Homebrew-owned directories to the end of PATH, so it cannot shadow an existing tool.

Compliance:

- With both directories present, both are on PATH → `test/qmk_arm_path_test.rb` `test_both_arm_keg_bins_are_on_path_when_present` (passes).
- With both directories absent, neither is on PATH → `test/qmk_arm_path_test.rb` `test_no_arm_keg_bin_is_on_path_when_absent` (passes).
- On this Mac, `command -v arm-none-eabi-gcc` succeeds → the reviewer checked it against the worktree `paths.zsh` with `env -i HOME="$HOME" TERM=dumb zsh -f -c ...`. It printed `/opt/homebrew/opt/arm-none-eabi-gcc@8/bin/arm-none-eabi-gcc`, and `arm-none-eabi-objcopy` resolved from the binutils keg. The reviewer did not re-run `qmk compile`, because it writes build output into another repository.
- Every test that `plan.md` names in `## Proof` exists. No existing test was weakened, skipped or deleted.

Design: none. The diff adds no production Ruby. The loop follows the file's existing `[[ -d ]]` style and unsets its variable.

Checks: the full suite passes (`ruby -Itest test/*_test.rb`, one file at a time). `rubocop`, `shellcheck -S warning -s bash` and `zsh -n` report no problems. `test/lefthook_rubocop_git_gem_test.rb` failed once with an `IOError` from `Open3.capture2e` and then passed on re-run. Its push test took 1983 s. This file does not use `paths.zsh`, so the problem is outside this change.

## Round 2 — 2026-11-19T15:48:06Z — c9fba75f

No findings.

This round reviews the branch after its rebase onto `origin/main` (#291). Round 1 reviewed the pre-rebase tip `dffe4a29`. The committed diff against `origin/main` is the same change, plus `require_relative "isolated_git"` in the test. `test/isolated_git_test.rb` requires that line in every test file. The repository still has no `REVIEW.md` or `REVIEW.local.md`, so this round uses the reviewer's default passes.

Bugs: none. Since round 1, main changed `paths.zsh` step 0, step 1 (`prepend_homebrew_path`) and `.zprofile`. None of these removes PATH entries. `.zprofile` only prepends, so the appended keg directories survive `path_helper` in login shells. rv (step 4) still prepends its Ruby paths ahead of them.

Security: none. The loop appends two Homebrew-owned directories to the end of PATH, so it cannot shadow an existing tool. An empty `HOMEBREW_PREFIX` gives `/opt/...` paths, and the `[[ -d ]]` guard drops them.

Compliance:

- With both directories present, both are on PATH → `test/qmk_arm_path_test.rb` `test_both_arm_keg_bins_are_on_path_when_present` (passes).
- With both directories absent, neither is on PATH → `test/qmk_arm_path_test.rb` `test_no_arm_keg_bin_is_on_path_when_absent` (passes).
- On this Mac, `command -v` finds the compiler → `env -i HOME="$HOME" TERM=dumb zsh -f -c 'typeset -gU path; source <worktree>/zsh/.config/zsh/paths.zsh; command -v arm-none-eabi-gcc arm-none-eabi-objcopy'` printed `/opt/homebrew/opt/arm-none-eabi-gcc@8/bin/arm-none-eabi-gcc` and `/opt/homebrew/opt/arm-none-eabi-binutils/bin/arm-none-eabi-objcopy`. The reviewer did not re-run `qmk compile`, because it writes build output into another repository.
- Every test that `plan.md` names in `## Proof` exists. No existing test was weakened, skipped or deleted.

Design: none. The diff adds no production Ruby. The loop follows the file's `[[ -d ]]` style (as step 0 does) and unsets its variable.

Checks: `rubocop`, `shellcheck -S warning -s bash` and `zsh -n` report no problems. `test/qmk_arm_path_test.rb`, `test/node_path_order_test.rb`, `test/rv_ci_fallback_test.rb` and `test/isolated_git_test.rb` pass. `bin/test` ran 127 files and 2237 tests, with 2 failures outside this change:

- `test/herdr_app_look_test.rb` `test_the_cloned_tabs_mod_differs_from_tabs_only_in_the_padding` compares `tabs-cores` with the tabs mod of the herdr-app installed on this machine. The installed mod has newer code (a `clean` title helper). The test does not touch `paths.zsh`. Re-clone `tabs-cores` in a separate change, or update the local herdr-app install.
- `test/worktree_create_test.rb` failed once in the parallel run and passed on its own re-run.
