# Review: remove-cspell

## Round 1 — 2026-10-05T13:00Z — d1965c71

Suite: all `test/*_test.rb` green except the known, out-of-scope error in `test/review_report_check_test.rb` (`test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, also red on main). `test/lefthook_local_hooks_test.rb`: 11 runs, 0 skips. `yamllint` and `rubocop` clean. Verification greps from `## Proof` print nothing.

Bugs: nothing found. The `node` symlink now sits only in the markdownlint-only directory, and the test that drops markdownlint exits before it needs `node`, as the plan says.

Security: nothing found. The deleted root `cspell.yml` was a tracked symlink to an absolute home path; removing it is an improvement.

Compliance, acceptance criteria:

- Committing a misspelled word succeeds → `test_pre_commit_uses_global_fallback_and_commits_an_unknown_word`.
- Commit in a repo with no `lefthook.yml` is not stopped by a spell check → same test (temp repo uses the fallback).
- `packages.conf` lists no `cspell` → verification grep (no test; plan says so).
- `cspell` directory gone → `git ls-files` check (no test; plan says so).
- CI has no cspell install step → verification grep (no test; plan says so).
- Hook tests pass with no `cspell` on PATH, no skip for it → `test/lefthook_local_hooks_test.rb` run: 0 skips; `CSPELL_DIR` and its skip removed.
- Markdownlint tests still run without `cspell` → `test_pre_commit_warns_about_a_wrapped_paragraph_and_still_commits`, `test_pre_commit_warns_about_a_wrapped_paragraph_in_a_markdown_extension_file`, `test_pre_commit_prints_no_hardwrap_warning_for_one_line_paragraphs`, `test_pre_commit_skips_the_hardwrap_check_when_the_markdownlint_package_is_not_stowed`.
- `grep -ri cspell` finds nothing outside `docs/changes/` → verification grep prints nothing (only `AutomaticSpellingCorrection` in `install/macos.sh`, excluded by design).
- `~/.config/cspell` gone and not a broken link → missing (see Important finding).

Every test named in `plan.md` `## Proof` exists. The one changed test, the unknown-word test, has its assertion inverted; the spec and plan ask for that, so it does not count as weakened. No test was skipped or deleted.

- [x] Important: Acceptance criterion "`~/.config/cspell` does not exist" is not met yet. The link `~/.config/cspell -> ../Developer/dotfiles/cspell/.config/cspell` still exists, and `cspell` is still on PATH. Plan step 10 (`stow -D -t "$HOME" cspell` from the main checkout) must run before the PR merges; after the merge the package directory is gone and the link breaks. Step 11 (`npm uninstall -g cspell`) follows the merge. — `docs/changes/remove-cspell/plan.md:33` → fixed (ran `stow -D -t "$HOME" cspell` from the main checkout on 2026-10-05; `~/.config/cspell` is gone and not a broken link)
- [x] Nit: The per-file test list in `plan.md` names the test "pre-commit commits an unknown word through the global fallback"; the test in the file is `test_pre_commit_uses_global_fallback_and_commits_an_unknown_word`. Same behaviour, different wording. — `docs/changes/remove-cspell/plan.md:60` → fixed (Name the real acceptance test in the remove-cspell plan)
