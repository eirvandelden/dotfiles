# Plan: Remove the cspell spell checker

From `intent.md` and `spec.md` (2026-10-02). Status: accepted.

## Context

The cspell pre-commit check stops commits on correct words and has found no real typo in 6 months. This change removes cspell from the dotfiles repository: the hook, the stow package, the install lists, CI, the hook tests, and the skill text. It also removes the `~/.config/cspell` link and the global npm package on this machine. Other repositories that use cspell are out of scope.

## Files that change

- `test/lefthook_local_hooks_test.rb` — invert the unknown-word test so it expects the commit to succeed. Remove `locate_cspell_dir`, `CSPELL_DIR`, the cspell skip in `setup`, and `@cspell_only_dir`. Put the `node` symlink in `@markdownlint_only_dir` next to `markdownlint`, because markdownlint needs `node` for its `#!/usr/bin/env node` shebang. Rewrite the comment above `setup_lint_bin_dirs` to say that.
- `lefthook.yml` — delete the `spelling` pre-commit command. Delete the commented-out `commit-msg` block and its `# TODO: fix loading of extra words` line. Delete the four `--exclude="project-dictionary.txt"` lines in `no-fixme` and `no-nocommit` (pre-commit and pre-push), because that file is deleted.
- `cspell/` — delete the whole stow package (`cspell.yml`, `user-dictionary.txt`).
- `cspell.yml` (repo root) — delete. It is a tracked symlink to `~/.config/cspell/cspell.yml`, and is broken once the stow package is gone. The spec did not list it.
- `project-dictionary.txt` (repo root) — delete. Only cspell reads it. The spec did not list it.
- `packages.conf` — delete `cspell` from `NPM_PACKAGES` and from `STOW`.
- `.github/workflows/dotfiles-tests.yml` — delete the "Install cspell" step (3 comment lines and the `run`). Approved on 2026-09-30.
- `claude/.claude/skills/dotfiles-maintenance/SKILL.md` line 18 — change "Herb and cspell where they add value" to "and Herb where it adds value".

Unchanged on purpose: `install/macos.sh` (`NSAutomaticSpellingCorrectionEnabled` contains the letters "cspell" but is a macOS `defaults` key), Vim `Spell*` groups, `AGENTS.md`, `agents.md`, and `docs/changes/ai-native-workflow/` (exempt; its own `finish` removes it).

## Order of work

1. Write the acceptance test: in `test/lefthook_local_hooks_test.rb`, replace `test_pre_commit_uses_global_fallback_and_rejects_an_unknown_word_outside_js_rb_md` with `test_pre_commit_uses_global_fallback_and_commits_an_unknown_word`, which asserts the commit succeeds. In the same step, remove the cspell lookup, the cspell skip and `@cspell_only_dir`, and move the `node` symlink into `@markdownlint_only_dir`. Run `ruby -Itest test/lefthook_local_hooks_test.rb`. Watch the new test fail: the `spelling` command finds no `cspell` on the test PATH, so the commit is rejected. All other tests in the file must pass, and no test may skip for cspell.
2. Delete the `spelling` command and the commented-out `commit-msg` block from `lefthook.yml`. Run the test file again. All pass.
3. Delete `cspell/`, the root `cspell.yml` symlink and `project-dictionary.txt` (`git rm`). Delete the four `--exclude="project-dictionary.txt"` lines from `lefthook.yml`. Run the test file again; the `no-fixme` tests (pre-push fixme rejection) prove the excludes were not load-bearing.
4. Delete both `cspell` entries from `packages.conf`. Run `ruby -Itest test/stow_package_roots_test.rb` and `ruby -Itest test/skill_parity_test.rb`.
5. Delete the "Install cspell" step from `.github/workflows/dotfiles-tests.yml`.
6. Edit `claude/.claude/skills/dotfiles-maintenance/SKILL.md` line 18.
7. Run the full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. Run `yamllint lefthook.yml .github/workflows/dotfiles-tests.yml` and `rubocop test/lefthook_local_hooks_test.rb`.
8. Run the verification commands in `## Proof`. Each must print nothing.
9. Manual proof, with `cspell` still installed globally: in the worktree, commit a scratch file holding `zzqxklmnop` on a throwaway branch, confirm the hook passes, then delete the branch. Then commit the real work, one logical change per commit.
10. From the main checkout (`~/Developer/dotfiles`, on `main`), before the PR merges: `stow -D -t "$HOME" cspell`. Confirm `ls -la ~/.config/cspell` reports "No such file". Approved in the intent.
11. Open the PR. After it merges: `npm uninstall -g cspell`, then confirm `command -v cspell` prints nothing. Approved in the intent.

## Risks

- Markdownlint tests lose `node`. The old PATH got `node` from the cspell directory. If `node` is not moved into `@markdownlint_only_dir`, the three markdownlint tests fail with `env: node: No such file`. Step 1 covers it.
- `test_pre_commit_skips_the_hardwrap_check_without_markdownlint` drops the markdownlint directory, so it then has no `node` either. That is fine: the hook exits before calling markdownlint.
- On CI, without cspell installed, the local hook tests used to skip whole. They now run on CI for the first time. A CI-only failure there is a real finding, not noise; fix it in this branch.
- Step 10 `stow -D` must run from the main checkout, which still has `cspell/` until the PR merges. Running it after merge fails, because the package directory is gone, and leaves a broken link. That is why the order is fixed.
- Rejected: replacing cspell with another spell checker. The spec says delete, not replace.
- Rejected: a permanent test that greps the repository for "cspell". It guards a removed tool forever. The grep runs once, as verification.

Out of scope: the other repositories with cspell (appkit, happiness, clocky, ddicompendium, mvpa.css, sticker-app, my-rails-template). Work repositories. `docs/changes/` of other changes.

## Proof

- Committing a file with a misspelled word succeeds (dotfiles repo uses the same `lefthook.yml`) → `test/lefthook_local_hooks_test.rb` `test_pre_commit_uses_global_fallback_and_commits_an_unknown_word`, plus the manual commit in step 9.
- A commit in a repository with no `lefthook.yml` of its own is not stopped by a spell check → `test/lefthook_local_hooks_test.rb` `test_pre_commit_uses_global_fallback_and_commits_an_unknown_word` (its temp repo has no `lefthook.yml`; it uses the fallback).
- The hook tests pass with no `cspell` on PATH and none skips for that reason → `ruby -Itest test/lefthook_local_hooks_test.rb -v` shows 0 skips when lefthook and markdownlint are present; the test PATH holds no cspell directory.
- The hook tests that need markdownlint still run it with no `cspell` on PATH → `test_pre_commit_warns_about_a_wrapped_paragraph_and_still_commits`, `test_pre_commit_warns_about_a_wrapped_paragraph_in_a_markdown_extension_file`, `test_pre_commit_prints_no_hardwrap_warning_for_one_line_paragraphs`, `test_pre_commit_skips_the_hardwrap_check_when_the_markdownlint_package_is_not_stowed`.
- `packages.conf` lists no `cspell` → verification grep below.
- The `cspell` directory is gone → `git ls-files | grep -i cspell` prints nothing outside `docs/changes/`.
- CI has no cspell install step → verification grep below.
- No tracked file outside `docs/changes/` refers to cspell → `git grep -n -i -E '(^|[^a-z])cspell' -- ':!docs/changes'` prints nothing. The `[^a-z]` guard skips `AutomaticSpellingCorrection` in `install/macos.sh`, which a plain `grep -ri cspell` would wrongly flag.
- `~/.config/cspell` does not exist and is not a broken link → `test ! -e ~/.config/cspell && test ! -L ~/.config/cspell` after step 10.

Per changed file, the unit tests expected:
- `test/lefthook_local_hooks_test.rb`: `pre-commit commits an unknown word through the global fallback`; all existing tests unchanged in behaviour.
- `lefthook.yml`, `packages.conf`, workflow, skill text, deleted files: no unit tests; covered by the tests above and the verification greps.

Test setup: unchanged temp HOME, temp repo, fallback hooks copied from `git/.config/git/hooks`, real lefthook via a stub. Only difference: `node` is symlinked into the markdownlint-only bin directory instead of a cspell-only one.
