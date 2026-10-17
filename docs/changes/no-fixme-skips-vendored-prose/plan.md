# Plan: Pre-push checks scan only the branch's own changes and skip vendored files

From `intent.md` (2026-10-17). Status: accepted.

This plan never spells the two marker words in capitals, so that the plan itself passes the marker checks. "The fixme marker" and "the nocommit marker" mean the upper-case words that `no-fixme` and `no-nocommit` grep for.

## Design decisions

- **The pre-push file list comes from a hook-level `files:` command.** Lefthook 2.2.2 lets `pre-push` carry a `files:` shell command. Its output fills the `{files}` template, and each command's `glob` filters it. This was checked in a scratch repository: after a rebase, `{push_files}` held a file that only main added, and `{files}` held only the branch's own files. Every pre-push command that now uses `{push_files}` switches to `{files}`: stylelint, erb_lint, eslint, rubocop, minitest, rspec, shellcheck, shellcheck-zsh, yamllint, no-fixme, no-nocommit.
- **The `files:` command is inline POSIX sh in `lefthook.yml`, not a stowed script.** A missing script would give an empty list, and every file check would skip silently. Inline sh works in every repository that falls back to this config, with no stow step. The command:

  ```sh
  base=$(git rev-parse -q --verify refs/remotes/origin/HEAD ||
    git rev-parse -q --verify refs/remotes/origin/main ||
    git rev-parse -q --verify refs/remotes/origin/master) && base=$(git merge-base "$base" HEAD) ||
    base=$(git rev-parse -q --verify '@{push}') || exit 0
  git diff --name-only --diff-filter=d "$base" HEAD
  ```

  The base is the merge-base with origin's default branch, so files that only main changed never appear, before or after a rebase. `--diff-filter=d` leaves out deleted files, which no linter can read. A repository without any origin default branch falls back to `@{push}`, which is lefthook's own list today. When `@{push}` does not resolve either, the command exits 0 with no output, so the list is empty and the file checks skip. Both fallbacks were checked in the scratch repository.
- **Commands without a file template keep lefthook's own push-file gate.** brakeman, bundle-audit and browserslist have a `glob` but no template. Lefthook 2.2.2 gates them on `{push_files}` even when a hook-level `files:` is set. The scratch test showed this: a template-less command with `glob: "Gemfile"` skipped with "no matching push files" while `{files}` held `Gemfile`. They scan the whole project, not a file list, so this change leaves them as they are.
- **Vendored paths live in `.gitattributes`, as the `linguist-vendored` attribute.** It is GitHub Linguist's own convention, git reads it natively through `git check-attr`, and it supports globs. No new file format is needed. A path is vendored when `git check-attr linguist-vendored` reports `set` or `true`. A path with a `vendor` directory segment (`vendor/…` or `…/vendor/…`, the Linguist rule) is vendored unless the attribute is `unset` or `false`. So `vendor/` counts in every repository, and a repository can still opt one file back in with `-linguist-vendored`.
- **One shared Ruby script does the marker check: `git/.config/git/worktree-tools/marker-check`.** Usage: `marker-check <word> <file>...`. It drops vendored files through `git check-attr -z --stdin linguist-vendored`, which is safe for any file name. It also drops what the old grep excluded: the basename `lefthook.yml` and paths under `sorbet/`. Then it greps the rest for the fixed string, prints `path:line:text` per hit, and exits 1 on any hit, 0 otherwise. No files left means exit 0. Ruby matches the other worktree-tools scripts. `review-report-fresh` sets the precedent for a pre-push command from `~/.config/git/worktree-tools/`. A missing script fails loudly with exit 127, so a missing stow blocks the commit; it never passes silently.
- **The four marker commands call the script.** Pre-commit: `~/.config/git/worktree-tools/marker-check <word> {staged_files}`. Pre-push: the same with `{files}`. The `fail_text` lines stay as they are.
- **The dotfiles repository lists its vendored content in a new root `.gitattributes`.** One line per vendored skill folder (`agents/.agents/skills/<name>/** linguist-vendored`) and one for `vim/.vim/colors/solarized.vim`. The vendored skill folders are the ones whose `SKILL.md` carries an `<!-- upstream: … -->` comment: 37signals-style, android-intent-security, brakeman, compound, hwc-forms-validation, hwc-media-content, hwc-navigation-content, hwc-realtime-streaming, hwc-stimulus-fundamentals, hwc-ux-feedback, mobilebuildmcp, rails-guides, rails-upgrade, ruby, ruby-upgrade, sandi-metz-rules, systematic-debugging, using-sqlite-worktrees. A test keeps the list equal to that set, so a new snapshot cannot forget its line. That test needs a new helper, `vendored_skill_names`, that selects every folder with an upstream comment. The existing `snapshot_names` leaves out the superpowers-ruby folders on purpose and stays for the manifest checks. The attribute changes no file content, so the snapshots stay byte-identical. On GitHub it only removes these files from the language statistics.
- **Tests never spell the marker words.** Test sources build them as `"FIX" + "ME"` and `"NO" + "COMMIT"`, so the test files pass the marker checks themselves.

## Integration points

- `git/.config/git/hooks/pre-commit` and `pre-push` load `~/Developer/dotfiles/lefthook.yml` as `LEFTHOOK_CONFIG` for every repository without its own lefthook config. The change reaches all of them.
- `~/.config/git/worktree-tools/` is the stowed `git/.config/git/worktree-tools/`. The new script is there after the existing `git` package link; no new stow package and no restow.
- `lefthook-branch-guard.yml` and `test/branch_guard_test.rb` hold only `no-push-to-main`. They do not change.
- `lefthook-local.yml` (the dotfiles' own extra pre-push checks) uses glob gates without templates. It does not change.
- `test/vendored_skills_test.rb` defines a snapshot folder by its upstream comment. The new sync test reuses that rule.

## Files that change

- `lefthook.yml` — add the hook-level `files:` command to `pre-push`. Switch every `{push_files}` to `{files}`. Replace the four grep blocks in `no-fixme` and `no-nocommit` (pre-commit and pre-push) with `marker-check`. Add a short comment that names `.gitattributes` `linguist-vendored` as the place for vendored paths.
- `git/.config/git/worktree-tools/marker-check` — new executable Ruby script, described above.
- `.gitattributes` — new. The vendored skill folders and `solarized.vim`, with a header comment that says what the attribute does here.
- `test/marker_check_test.rb` — new. Unit tests of the script in temporary repositories.
- `test/lefthook_branch_files_test.rb` — new. Real `git commit` and `git push` through the global `pre-commit` and `pre-push` hooks and the copied `lefthook.yml`. The harness follows `test/review_push_hook_test.rb`, but links both hooks, not only `pre-push`. It also holds one structural test: no `pre-push` command in `lefthook.yml` uses `{push_files}`.
- `test/vendored_skills_test.rb` — add the `vendored_skill_names` helper and the `.gitattributes` sync tests.

## Order of work

1. Write the acceptance test for the first criterion in `test/lefthook_branch_files_test.rb`: a branch pushed, main then adds a file with the fixme marker, the branch rebases over main and pushes. Run it and watch it fail on `no-fixme` with main's file.
2. Add the `files:` command to `pre-push` and switch every `{push_files}` to `{files}`. Watch step 1 pass.
3. Write the shellcheck and yamllint test (stubs that log their arguments), the fresh-branch test, the no-origin-default test and the structural no-`{push_files}` test. Run them. They pass from step 2; confirm each fails when step 2 is reverted locally, then restore it.
4. Write the `marker-check` unit tests in `test/marker_check_test.rb`. Watch them fail: the script does not exist.
5. Write `marker-check` until its unit tests pass. Run rubocop on it.
6. Write the acceptance tests for the vendored criteria: a `vendor/` path, a listed path with the nocommit marker, and an own file with the fixme marker, each at commit and at push. Watch the vendored ones fail.
7. Switch the four marker commands in `lefthook.yml` to `marker-check`. Watch step 6 pass.
8. Write the `.gitattributes` sync tests in `test/vendored_skills_test.rb` and the dotfiles-list acceptance tests (a vendored skill file passes, a non-vendored skill file is rejected, a vendored `.sh` file with a marker still reaches the shellcheck stub). Watch them fail.
9. Write `.gitattributes`. Watch step 8 pass.
10. Run the full suite as CI does (`for file in test/*_test.rb; do ruby -Itest "$file"; done`), yamllint on `lefthook.yml`, rubocop on the new Ruby files, and `test/lefthook_posix_sh_test.rb` for the new sh under dash.
11. Verify by hand in a scratch clone: rebase a branch over a main that adds a marker file, push, and see it pass with no `LEFTHOOK_EXCLUDE`.

## Risks

- **A repository whose origin has no `HEAD`, `main` or `master` ref** falls back to `@{push}`, so it keeps today's behaviour and today's rebase problem. Accepted: such repositories are rare, and the intent puts other bases out of scope.
- **A stale `origin/main`.** A branch rebased onto a local main that is ahead of `origin/main` lists main's newer files too. The `sync` skill rebases onto a freshly fetched `origin/main`, so this needs a manual rebase onto an unpushed main.
- **The `git` stow package not linked on a machine.** Then `marker-check` is missing, and the marker commands fail with "not found" on every commit. Loud, not silent, so the safe direction. The same holds today for `review-report-fresh`.
- **`--exclude` on the old grep may not have matched on BSD grep.** The script now applies the `lefthook.yml` and `sorbet/` exclusions itself. That can only skip those paths, which was the old intent.
- **This branch's own change folder.** `intent.md` spells both marker words in capitals. It is the branch's own file, so `no-fixme` and `no-nocommit` reject its commits and pushes until `deliver` removes the folder, also after this fix. The plan does not exempt `docs/changes/`; that would change the agreed behaviour. Rewording the accepted intent is outside the plan stage; the coordinator decides.
- **Rejected: a separate list file such as `.vendored`.** A new format that git cannot read. `.gitattributes` is the convention GitHub already reads.
- **Rejected: moving vendored content under `vendor/`.** Out of scope in the intent.
- **Rejected: lefthook's `exclude:` option.** It is static in `lefthook.yml`, so it cannot differ per repository that falls back to this config.

## Proof

- A branch pushed before main moved files, rebased over main, pushes without a fixme failure from main's files → `test/lefthook_branch_files_test.rb` `test_a_rebased_branch_pushes_past_markers_that_only_main_added`
- A branch that adds the fixme marker to its own file is rejected at push → `test/lefthook_branch_files_test.rb` `test_a_marker_in_an_own_file_blocks_the_push_after_a_rebase`
- … and at commit → `test/lefthook_branch_files_test.rb` `test_a_marker_in_an_own_file_blocks_the_commit`
- A branch that changes a vendored skill file whose upstream text holds the fixme marker commits and pushes → `test/lefthook_branch_files_test.rb` `test_a_vendored_skill_file_with_a_marker_commits_and_pushes`
- A fixme marker under `vendor/` blocks neither commit nor push → `test/lefthook_branch_files_test.rb` `test_a_marker_under_vendor_commits_and_pushes`
- A nocommit marker in a listed vendored path blocks neither commit nor push → `test/lefthook_branch_files_test.rb` `test_a_nocommit_marker_in_a_listed_vendored_path_commits_and_pushes`
- A fixme marker added to a non-vendored dotfiles skill still blocks the push → `test/lefthook_branch_files_test.rb` `test_a_marker_in_a_non_vendored_skill_blocks_the_push`
- After a rebase, shellcheck and yamllint get only the branch's own files → `test/lefthook_branch_files_test.rb` `test_after_a_rebase_shellcheck_and_yamllint_check_only_own_files`
- … and no pre-push command still reads the old list → `test/lefthook_branch_files_test.rb` `test_no_pre_push_command_uses_push_files`
- A fresh branch off origin/main without a remote copy behaves as today → `test/lefthook_branch_files_test.rb` `test_a_fresh_branch_checks_exactly_its_own_files`

Per changed file, the unit tests expected, named as behaviour:

- `git/.config/git/worktree-tools/marker-check`: `test_reports_a_marker_with_path_and_line_and_exits_1`, `test_exits_0_when_no_file_holds_the_marker`, `test_exits_0_with_no_files`, `test_skips_a_path_marked_linguist_vendored`, `test_skips_a_path_under_a_vendor_directory`, `test_checks_a_vendor_path_marked_not_vendored`, `test_skips_lefthook_yml_and_sorbet_paths`, `test_handles_a_file_name_with_spaces`
- `.gitattributes`: `test_every_upstream_skill_folder_is_marked_vendored`, `test_no_own_skill_folder_is_marked_vendored`, `test_solarized_colour_scheme_is_marked_vendored`
- `lefthook.yml`: covered by the acceptance tests above, plus `test_a_repository_without_an_origin_default_branch_falls_back_to_the_push_target`, `test_a_vendored_shell_file_still_reaches_shellcheck`; `test/lefthook_posix_sh_test.rb` keeps passing.

Test setup: temporary bare origin plus clone, a fake `HOME` with the global `pre-commit` and `pre-push` hooks linked, `~/.config/git/worktree-tools` linked to the repository's copy and `lefthook.yml` copied to `~/Developer/dotfiles/`, as in `test/review_push_hook_test.rb`. `shellcheck` and `yamllint` are stub scripts on `PATH` that append their arguments to a log file. Main's commits, the "pushed before" state and the deliberately bad commits for push-only tests are made with `LEFTHOOK=0`; the commit tests run the hooks. The dotfiles-list tests copy the real `.gitattributes` into the temporary repository. Marker words are built by concatenation in the test source.

## Out of scope

- Rewording vendored prose, or moving it under `vendor/`.
- Stacked branches with a base other than origin's default branch.
- brakeman, bundle-audit and browserslist gating, post-merge, post-rewrite, commit-msg.
- The Linux `[[ ]]` bug in `no-push-to-main`.
- Exempting `docs/changes/` from the marker checks.

---
Domain skills applied: dotfiles-maintenance (stow layout, global fallback config; it has no vendored-skills section, so the sync test and the `.gitattributes` header carry the rule), ruby-style (script shape), rails-testing (Minitest conventions only).

## Critique

### Round 1 (codex exec -p terra)

- The plan cannot commit its artifacts, because the accepted intent spells both marker words; reword the intent and re-accept it. → dismissed: the intent is accepted and outside this stage's write scope; the risk is recorded under Risks and raised to the coordinator as a decision.
- The `.gitattributes` sync test cannot reuse `snapshot_names`, which leaves out the 16 superpowers-ruby folders. → fixed (new `vendored_skill_names` helper; `snapshot_names` stays for the manifest checks)
- The harness copied from `test/review_push_hook_test.rb` links only `pre-push`, so it cannot prove the commit criteria. → fixed (the harness links `pre-commit` and `pre-push`; `LEFTHOOK=0` only builds deliberately bad commits for push tests)
- A hook-level `files:` changes the glob gate of brakeman, bundle-audit, browserslist and the `lefthook-local.yml` commands too. → dismissed: the scratch run on lefthook 2.2.2 showed a template-less `glob: "Gemfile"` command skip with "no matching push files" while `{files}` held `Gemfile`, so their gate stays on the push files; the design note now cites that run.
- Only shellcheck and yamllint are exercised, so a missed `{push_files}` elsewhere or a linter skipping vendored files would go unnoticed. → fixed (structural test that no pre-push command uses `{push_files}`, and a vendored `.sh` file must still reach the shellcheck stub)
- The `@{push}` fallback runs `git diff` against an unresolved revision when there is no push target. → fixed (the fallback resolves `@{push}` with `git rev-parse -q --verify` first and exits 0 with no output when it fails; checked in the scratch repository; new test for a repository without an origin default branch)

Reproduction: committed
