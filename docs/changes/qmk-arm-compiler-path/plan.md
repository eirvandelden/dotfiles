# Plan: Put the QMK ARM compiler on PATH

From `intent.md` (2026-10-20). Status: accepted.

## Context

`qmk compile -kb keyboardio/model100` fails with `arm-none-eabi-gcc: command not found`. Homebrew installs `arm-none-eabi-gcc@8` and `arm-none-eabi-binutils` keg-only, so their `bin` directories are not on PATH. `zsh/.config/zsh/paths.zsh` builds PATH for every zsh, including non-interactive ones, because `.zshenv` sources it. Adding both keg `bin` directories there, only when they exist, removes the manual `export`.

## Design decisions

- Append, not prepend (confirmed by Etienne during planning; second-model critique skipped by his choice). Both directories hold only `arm-none-eabi-*` names, so order does not matter for them. Appending cannot shadow a system or Homebrew tool.
- Guard each directory with `[[ -d ... ]]`. A machine without the kegs (Linux, a fresh Mac, an empty `HOMEBREW_PREFIX`) gets no entry, as the intent requires.
- Use `"${HOMEBREW_PREFIX:-}"/opt/<keg>/bin`, not `/opt/homebrew/...`. Step 1 already sets `HOMEBREW_PREFIX`; an Intel Mac uses `/usr/local`.
- Loop over the two keg names with brace expansion. The loop variable is `_qmk_bin` and is `unset` after the loop, so a sourced file leaves no stray global.
- No conflict with intent's `## Decisions`: only the ARM compiler (no `avr-gcc@8`), and no `brew link`.

## Integration points

- `zsh/.config/zsh/paths.zsh` step 2 ("Extra PATH entries"), before rv in step 4. rv prepends its Ruby paths, so it stays ahead of these.
- `.zshenv` sets `typeset -U path`, so a repeated source adds no duplicates.
- macOS `path_helper` in login shells keeps existing entries, so the directories survive `.zprofile`. No `.zprofile` change.
- CI (`.github/workflows/dotfiles-tests.yml`) runs `ruby -Itest test/*_test.rb` on Linux, so the test must fake `HOMEBREW_PREFIX`, never use the real one.

## Files that change

- `test/qmk_arm_path_test.rb` — new. Runs `zsh -f -c` with a clean env, a temp `HOMEBREW_PREFIX`, `typeset -gU path`, sources `paths.zsh`, prints `$path` one per line. Follows `test/node_path_order_test.rb`'s `run_zsh` pattern (`Open3.capture3`, `unsetenv_others: true`).
- `zsh/.config/zsh/paths.zsh` — in step 2, after the existing two `export PATH` lines:

  ```zsh
  # QMK's ARM compiler (Keyboardio Model 100). Homebrew installs both kegs keg-only.
  for _qmk_bin in "${HOMEBREW_PREFIX:-}"/opt/{arm-none-eabi-gcc@8,arm-none-eabi-binutils}/bin; do
    [[ -d "$_qmk_bin" ]] && path+=("$_qmk_bin")
  done
  unset _qmk_bin
  ```

## Order of work

1. Write `test/qmk_arm_path_test.rb` with both tests. Run `ruby -Itest test/qmk_arm_path_test.rb`. Watch the "present" test fail and the "absent" test pass.
2. Add the loop to `paths.zsh` step 2. Run the test file again; both pass.
3. Run `ruby -Itest test/node_path_order_test.rb` and `ruby -Itest test/rv_ci_fallback_test.rb`; they also source `paths.zsh`. Then the full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`.
4. Lint: `rubocop test/qmk_arm_path_test.rb`; `shellcheck -S warning -s bash zsh/.config/zsh/paths.zsh` (as lefthook's `shellcheck-zsh` job does); `zsh -n zsh/.config/zsh/paths.zsh`.
5. Manual check on this Mac against the worktree file (the stowed `~/.config/zsh/paths.zsh` points at the main checkout, which has not changed yet):
   - `env -i HOME="$HOME" TERM=dumb zsh -f -c 'typeset -gU path; source /Users/etienne.vandelden/Developer/dotfiles/.worktrees/qmk-arm-compiler-path/zsh/.config/zsh/paths.zsh; command -v arm-none-eabi-gcc'` prints `/opt/homebrew/opt/arm-none-eabi-gcc@8/bin/arm-none-eabi-gcc`.
   - The same shell, with `cd ~/Developer/keyboardio-config && qmk compile -kb keyboardio/model100 -km eirvandelden` instead, succeeds.
6. Re-read the diff; commit as one change.

## Risks

- `path+=` inside `[[ ]] &&` leaves a non-zero status when the last directory is absent. Later lines run anyway; `paths.zsh` is not checked for exit status. Accepted.
- `shellcheck -s bash` might flag `path+=(...)`. The file already assigns `path=(...)` without warnings, so this is unlikely. If it does flag it, use `path=("${path[@]}" "$_qmk_bin")`.
- Rejected: `brew link` (intent decision). Rejected: a zsh glob qualifier (`.../bin(N/)`): shorter but less readable than the explicit `-d` guard the file uses elsewhere.
- The new zsh in criterion 3 uses the stowed main checkout, so the "new shell" form of that check holds only after merge. Step 5 proves it against the worktree file before then.

## Out of scope

- `avr-gcc@8` and `avr-binutils`.
- `dos2unix` and any other `qmk doctor` finding.
- `.zprofile`, `brew link`, any other file.

## Proof

- With both directories present under `HOMEBREW_PREFIX`, a shell that sources `paths.zsh` has both on PATH → `test/qmk_arm_path_test.rb` `test_both_arm_keg_bins_are_on_path_when_present`
- With the directories absent, a shell that sources `paths.zsh` has neither on PATH → `test/qmk_arm_path_test.rb` `test_no_arm_keg_bin_is_on_path_when_absent`
- On this Mac, a new zsh finds `arm-none-eabi-gcc` with `command -v`, and `qmk compile -kb keyboardio/model100 -km eirvandelden` succeeds without an extra `export` → check: step 5's two commands, against the worktree `paths.zsh`.

Per changed file, the unit tests expected, named as behaviour:
- `zsh/.config/zsh/paths.zsh`: covered by the two tests above (adds each keg `bin` that exists; adds none that is missing).

Test setup: a `Dir.mktmpdir` fake `HOMEBREW_PREFIX`. The "present" test creates `opt/arm-none-eabi-gcc@8/bin` and `opt/arm-none-eabi-binutils/bin`. The "absent" test creates no `opt/` and asserts no `$path` entry contains `arm-none-eabi`. No `bin/rv` or chnode in the fake prefix, so steps 4 and 5 skip.

---
Domain skills applied: None. The `paths.zsh` header comments and `test/node_path_order_test.rb` set the conventions followed.
