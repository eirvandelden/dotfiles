# Review: unlock-scope-menu

## Round 1 — 2026-10-26T12:40Z — bf368ccf

No `REVIEW.md` at the repository root; the default passes from the `new-repo-setup` template apply. Bugs and Security found nothing: argument checks, the `|| return $?` chain and stderr-only messages match the plan. The touched test files, `shellcheck -S warning -s bash` and `rubocop` are green. `bin/test` ran 88 files with 2 timing failures in files this branch does not touch (`worktree_create_test.rb`, `worktree_sweep_on_pull_test.rb`); both tests pass when run alone. Step 7 of the plan has no recorded result on the branch; this round ran it in an interactive `zsh -f -i` on a pseudo-terminal with ZLE: bare `unlock` showed the menu and loaded the personal scope, `unlock personal` showed no menu, and `eval "$(secrets)"` showed the menu on the terminal and loaded the work scope.

Compliance, acceptance criteria:

- `unlock personal` exports personal, no work reads, no menu → `test_unlock_personal_exports_the_personal_secrets_and_reads_nothing_from_the_work_account` (no-menu part vacuous, see below)
- `unlock work` exports work, no personal reads, no menu → `test_unlock_work_exports_the_work_secrets_and_reads_nothing_from_the_personal_account` (no-menu part vacuous, see below)
- `unlock both` exports both sets → `test_unlock_both_exports_both_sets`
- Bare `unlock` on a terminal lists the menu in order and loads the choice → `test_a_bare_unlock_on_a_terminal_lists_cancel_personal_work_both_and_loads_the_choice`
- Cancel changes neither the environment nor PATH → `test_choosing_cancel_changes_neither_the_environment_nor_path`
- Bare `unlock` without a terminal prints the usage and applies nothing → `test_a_bare_unlock_without_a_terminal_prints_the_usage_and_applies_nothing`
- `eval "$(secrets)"` shows the menu on stderr and evals only exports → `test_eval_secrets_on_a_terminal_shows_the_menu_on_stderr_and_evals_only_exports`
- `unlock work` with the work account unset names the variable → `test_unlock_work_without_the_work_account_fails_naming_the_variable_and_applies_nothing` (empty, not unset, see below)
- `unlock bogus` prints the usage and applies nothing → `test_unlock_with_an_unknown_scope_prints_the_usage_and_applies_nothing`

Every test that `plan.md`'s `## Proof` names exists. No existing test was weakened, skipped or deleted; one was renamed as the plan says. The glossary has no `Avoid:` entries.

- [ ] Important: No test proves that `unlock personal` and `unlock work` skip the menu on a terminal. The two `refute_includes stderr, "scope?"` checks run under Open3, where stdin is not a terminal, so the menu can never show there. A regression that tests `[[ -t 0 ]]` before the argument count (`zsh/.config/zsh/functions/secrets.zsh:35`) passes the whole suite. A pseudo-terminal test in `test/secrets_scope_menu_test.rb` that runs `unlock personal` and asserts no prompt closes the gap — `test/secrets_loader_test.rb:203` → fixed (Test that scope arguments skip the menu on a terminal and bound the pty helpers)
- [ ] Nit: `run_on_terminal` sends each answer even when `expect` times out and returns nil, and `drain` reads to EOF with no timeout. A regression that asks again hangs the suite instead of failing it; the plan's step 4 asks to "close on timeout" — `test/secrets_scope_menu_test.rb:81` → fixed (Test that scope arguments skip the menu on a terminal and bound the pty helpers)
- [ ] Nit: The criterion says `SECRETS_WORK_OP_ACCOUNT` unset, but the test sets it to an empty string. The code treats both alike through `${...:-}`, and Open3 unsets a variable given `nil`, so `"SECRETS_WORK_OP_ACCOUNT" => nil` tests the stated case — `test/secrets_loader_test.rb:272` → fixed (Test that scope arguments skip the menu on a terminal and bound the pty helpers)

## Round 2 — 2026-10-29T12:44Z — 79046075

No `REVIEW.md` at the repository root; the default passes apply. This round compares against `origin/main` after a fetch. The branch is 10 commits behind `origin/main`. The three round 1 findings hold: `test_unlock_personal_on_a_terminal_skips_the_menu` and `test_unlock_work_on_a_terminal_skips_the_menu` run on a pseudo-terminal, `expect_prompt` and `drain` stop the shell after 5 seconds, and the work-account test passes `nil`. Bugs and Security found nothing new: the resolver validates the scope with a `case` before any caller uses it, and every message goes to stderr. `shellcheck -S warning -s bash` and `rubocop` on the touched files are green. The three touched test files pass (28, 9 and 10 runs). `bin/test` ran 88 files with 1 failure in `test/worktree_sweep_test.rb`, which this branch does not touch; that file passes alone (19 runs, 0 failures), so it is a timing failure under parallel load.

Compliance: every acceptance criterion and every test that `plan.md`'s `## Proof` names still exist, as listed in round 1. No existing test was weakened, skipped or deleted.

- [ ] Important: `GLOSSARY.md` conflicts with `origin/main`. Both sides add the file (add/add), and `git merge-tree HEAD origin/main` reports a conflict. Main's file holds nine terms; this branch's file holds only Scope and Scope menu. A rebase that takes this branch's side drops main's nine terms. Rebase on `origin/main` and keep both lists, sorted, under one `# Glossary` heading — `GLOSSARY.md:1` → fixed (docs: glossary terms for unlock-scope-menu)
- [ ] Nit: The test name says `unlock both` and "loads personal", but the body runs `secrets both` and asserts no personal export. Rename it to `secrets both`, or assert `export PERSONAL_TOKEN=` in stdout — `test/secrets_loader_test.rb:42` → fixed (Name the secrets both test correctly and assert the work-overlay failure reads nothing)
- [ ] Nit: The name says "applies nothing", but the test does not assert `op_calls` is empty or that `WORK_TOKEN` is unset. A regression where `work` reads the personal file before it fails passes this test; `assert_equal "", op_calls` closes it, as the sibling usage tests do — `test/secrets_loader_test.rb:291` → fixed (Name the secrets both test correctly and assert the work-overlay failure reads nothing)

## Round 3 — 2026-10-29T13:09Z — f82670fa

No `REVIEW.md` at the repository root; the default passes apply. This round compares against `origin/main` after a fetch. The branch is rebased: 0 commits behind `origin/main`, and `git merge-tree` reports no conflict. The three round 2 findings hold: `GLOSSARY.md` keeps main's terms and adds Scope and Scope menu in sorted order, `test_secrets_both_without_the_work_account_warns_and_loads_personal` runs `secrets both` and asserts the personal export, and the work-account test asserts that `op_calls` is empty and `WORK_TOKEN` is unset. Bugs and Security found nothing new: `_secrets_scope` checks the word with a `case` before any caller uses it, every message goes to stderr, and `unlock` applies nothing before `secrets` succeeds. `shellcheck -S warning -s bash` and `rubocop` on the touched files are green. The three touched test files pass (28, 9 and 10 runs). `bin/test` ran 92 files with 0 failures.

Compliance: every acceptance criterion maps to the test listed in round 1, and each test still exists. The plan's unit test `test_unlock_both_without_the_work_account_warns_and_loads_personal` exists as `test_secrets_both_without_the_work_account_warns_and_loads_personal`, renamed in round 2 because the body runs `secrets both`. No existing test was weakened, skipped or deleted.

Design: the glossary lists `Avoid: shim` and `Avoid: binary` for the lefthook terms. The added lines use "shim" only for the existing codex shim (`SHIM_DIR`, `CodexShimSupport`, the `unlock` comment), a different meaning, so it is no conflict. The nested loaders follow the existing `_secrets_emit_file` pattern.

No findings.
