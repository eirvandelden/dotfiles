# Review: no-fixme-skips-vendored-prose

## Round 1 — 2026-10-17T07:40Z — 5df132fd (codex)

No findings.

## Round 2 — 2026-10-17T07:53Z — 5df132fd

Checks: the full suite (`for file in test/*_test.rb`), yamllint on both lefthook configs and rubocop on the eight changed Ruby files are green. Compliance: every acceptance criterion in `intent.md` maps to its named test in `test/lefthook_branch_files_test.rb`, every test named in the `## Proof` section of `plan.md` exists, and no existing test is weakened (the four touched tests only add `marker-check` stubs or links).

- [ ] Important: In a linked worktree the `files:` command's last line (`git rev-parse --git-path HEAD`) prints an absolute path under the main checkout's `.git/worktrees/`, outside the worktree root, and lefthook 2.2.2 drops it. A branch with no own changes against origin's default branch then gets an empty list, so every pre-push command skips, `no-push-to-main` and `review-report-fresh` included. Reproduced in a scratch repository: the same `files:` line gives `FILES=[.git/HEAD]` and runs a template-less command in the main checkout, while in a linked worktree both commands skip with "no files for inspection". Scenario: from a fresh `.worktrees/<name>` checkout, `git push origin --delete main` or a push of an older commit to `main` no longer meets the branch guard. Every agent works in such worktrees, and the tests use plain clones only, so they miss it — `lefthook.yml:154` → fixed (fix: the pre-push checks also run in a linked worktree without own changes)

## Round 3 — 2026-10-19T09:09Z — 108d05ed (codex)

No findings.

## Round 4 — 2026-10-19T09:56Z — b4ed5986

Checks: the full suite (`for file in test/*_test.rb`), yamllint on both lefthook configs and rubocop on the ten changed Ruby files are green. Compliance: every acceptance criterion in `intent.md` maps to a named test, every test in the `## Proof` section of `plan.md` exists, and the touched existing tests only add `marker-check` stubs or links. `test_the_fallback_config_duplicates_the_guard_commands_exactly` now strips the `: {files}` line before it compares, so it still pins the rest of the guard. The round 2 fix holds: `test_a_linked_worktree_without_own_changes_cannot_push_to_main` passes. Security: `marker-check` runs `git check-attr` with an argument list and no shell. A non-ASCII file name reaches `{files}` unquoted, the same as `{push_files}` (checked on lefthook 2.2.2).

- [ ] Important: `test_a_vendored_skill_file_with_a_marker_commits_and_pushes` does not prove its criterion. Its file, `agents/.agents/skills/37signals-style/references/development-philosophy.md`, matches the existing `exclude: "**/skills/*/references/**"` on both `no-fixme` commands, so lefthook drops it before `marker-check` reads `.gitattributes`. Reproduced: a copy of the repository with an empty `.gitattributes` still passes this test (`test_a_marker_in_a_non_vendored_skill_blocks_the_push` passes there too, as it should). A missing or broken vendored list for the dotfiles skills goes unnoticed. Use a vendored skill path outside `references/`, for example `agents/.agents/skills/37signals-style/SKILL.md` — `test/lefthook_branch_files_test.rb:124` → fixed (test: prove the vendored skill list with a file outside references/)

## Round 5 — 2026-10-19T10:13Z — 1a3ec1ea (codex)

- [ ] Important: On a first push with no origin default-branch ref and no `@{push}`, the `files:` command emits only the git sentinel, which every file check skips, so a pushed marker that the old configuration rejects now passes. Fall back to every tracked file or fail explicitly; this affects every repository on the global fallback — `lefthook.yml:159` → fixed (fix: a first push without any base checks every file)

## Round 6 — 2026-10-19T10:21Z — 4320662f (codex)

No findings.

## Round 7 — 2026-10-19T10:43Z — 4320662f

Checks: the full suite (`for file in test/*_test.rb`) is green with no skips, yamllint on both lefthook configs and rubocop on the ten changed Ruby files are green. Compliance: every acceptance criterion in `intent.md` maps to a named test in `test/lefthook_branch_files_test.rb`, every test in the `## Proof` section of `plan.md` exists, and the touched existing tests only add `marker-check` stubs or links or strip the `: {files}` no-op before they compare. Security: `marker-check` passes paths to `git check-attr` on stdin with `-z` and runs no shell.

- [ ] Important: `test_a_repository_without_an_origin_default_branch_falls_back_to_the_push_target` no longer proves the `@{push}` fallback. Since the empty-tree fallback (fix: a first push without any base checks every file), both fallbacks list `notes/own.txt`, so the test cannot tell them apart. Reproduced: a copy of the branch with `base=$(git rev-parse -q --verify '@{push}') ||` removed from `lefthook.yml` still passes it. A lost `@{push}` fallback would make every rebased branch in such a repository check all its files again, and nothing would catch it. Make the test fail under the empty tree, for example: push a marker in an earlier file with `LEFTHOOK=0`, then push a clean own file and assert that the push succeeds — `test/lefthook_branch_files_test.rb:104` → fixed (test: tell the push target fallback from the empty tree)

## Round 8 — 2026-10-19T10:54Z — 4fdef5a3 (codex)

- [ ] Important: `no-push-to-main` now always runs, so a deletion-only push from an unchanged `main` checkout (`git push origin --delete feature`) fails with "Direct push to main", although it does not update main; the base config allows it. Exempt deletions of unprotected refs from the current-branch check and keep protecting main/master targets — `lefthook.yml:290` → fixed (fix: a push that only deletes a branch passes the main checkout guard)

## Round 9 — 2026-10-19T10:58Z — b083e3c3 (codex)

No findings.

## Round 10 — 2026-10-19T11:17Z — b083e3c3

Checks: the full suite (`for file in test/*_test.rb`) is green with no skips, yamllint on the three lefthook configs and rubocop on the ten changed Ruby files are green. Compliance: every acceptance criterion in `intent.md` maps to a named test in `test/lefthook_branch_files_test.rb`, every test in the `## Proof` section of `plan.md` exists, and the touched existing tests only add `marker-check` stubs or links, or strip the `: {files}` no-op before they compare. The round 8 fix holds: `test_deleting_a_feature_branch_from_an_unchanged_main_checkout_pushes` passes, and a deletion of `main` still meets the remote-ref check. Security: `marker-check` passes paths to `git check-attr` on stdin with `-z` and runs no shell.

- [ ] Important: `marker-check` crashes under the macOS system ruby (`/usr/bin/ruby` 2.6.10), because `Enumerable#filter_map` needs Ruby 2.7. The script runs through `/usr/bin/env ruby` with the PATH the hook inherits, and the global hook already expects a PATH without lefthook (it falls back to an absolute rv path). Reproduced: `env PATH=/usr/bin:/bin git/.config/git/worktree-tools/marker-check <fixme marker> README.md` exits 1 with `undefined method 'filter_map'`. Scenario: a commit from a GUI client or IDE without rv's ruby on PATH, in any repository on the global fallback, fails at pre-commit with the misleading no-fixme failure text, although the old grep check passed. Use only Ruby 2.6 methods (for example `each_line.with_index(1)` with `select` and `map`), and add a test that runs the script with the system ruby where it exists — `git/.config/git/worktree-tools/marker-check:26` → dismissed: Etienne runs everything on rv's Ruby 4; the macOS system ruby 2.6 is not a supported runtime for these scripts.
