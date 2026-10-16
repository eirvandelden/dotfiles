# Plan: The no-fixme hook skips vendored skill references

From `intent.md` (2026-10-16). Status: accepted.

## Context

`lefthook.yml` has two `no-fixme` commands: one under `pre-commit` (greps `"{staged_files}"`), one under `pre-push` (greps `"{push_files}"`). Each runs `! grep --exclude="sorbet/**/*" --exclude="lefthook.yml" --line-number --with-filename --fixed-strings <marker> <files>`. PR #208 moved the vendored skills to `agents/.agents/skills/`. Two vendored reference documents hold the fix-me marker as upstream prose: `agents/.agents/skills/37signals-style/references/development-philosophy.md` and `agents/.agents/skills/rails-guides/references/command_line.md`. A branch that rebases onto `main` pushes them, and the pre-push `no-fixme` command refuses the push.

In this plan, "the marker" means the four-letter word FIX followed by ME, written as one word. This file never spells it, because the pre-commit check would refuse this file. Tests build it from parts (`"FIX" + "ME"`), as `test/lefthook_local_hooks_test.rb` already does.

## Design decisions

- Use one more grep `--exclude` line in each `no-fixme` command: `--exclude="agents/.agents/skills/*/references/*"`. It follows the two `--exclude` lines that are already there.
- Verified on macOS `/usr/bin/grep` (BSD grep 2.6.0-FreeBSD): with explicit file arguments, the pattern matches against the full relative path. It excludes `agents/.agents/skills/foo/references/a.md` and `agents/.agents/skills/foo/references/sub/c.md`. It does not exclude `agents/.agents/skills/foo/SKILL.md` or `bin/b.sh`. The `*` crosses `/`, because the match does not use `FNM_PATHNAME`.
- GNU grep (CI, `ubuntu-latest`) documents `--exclude` for command-line files as a wildcard match on the whole name or a name suffix, without a pathname flag. The same pattern is expected to match there. The CI run of the new test proves it (acceptance criterion 3).
- Put the tests in a new file, `test/no_fixme_hook_test.rb`. The repository has one test file per hook behaviour (`review_push_hook_test.rb`, `lefthook_posix_sh_test.rb`). `test/lefthook_local_hooks_test.rb` is already 274 lines, and its `stage_file` helper cannot write nested paths.
- The tests run a real `git commit` and a real `git push` through the global hook shim (`git/.config/git/hooks/`) and the real lefthook binary (`LefthookBinary.locate`). `PATH` is `<stub bin>:/usr/bin:/bin`, so the hook uses the system grep: BSD grep on macOS, GNU grep on CI. This matches the intent's macOS constraint.
- The pre-push hook also runs `review-report-fresh` from `~/.config/git/worktree-tools/`. That check is out of scope. The test writes a stub that exits 0 at `$HOME/.config/git/worktree-tools/review-report-fresh` in the temporary home, so only the no-fixme result decides the push.

## Integration points

- `lefthook.yml`: the `pre-commit.commands.no-fixme` and `pre-push.commands.no-fixme` commands.
- The global hook shim `git/.config/git/hooks/pre-commit` and `pre-push`: it falls back to `$HOME/Developer/dotfiles/lefthook.yml` when the repository has no own config. The tests copy `lefthook.yml` there, as the existing hook tests do.
- Every repository that uses the global fallback config. The new exclude names a path that only the dotfiles repository has, so other repositories see no change.
- CI: `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb` with lefthook installed. It picks up the new file without a workflow change.

## Files that change

- `test/no_fixme_hook_test.rb` — new. Commit and push tests through the real hooks, described under Proof.
- `lefthook.yml` — one added `--exclude="agents/.agents/skills/*/references/*"` line in each of the two `no-fixme` commands. Nothing else in the file changes.

## Order of work

1. Write `test/no_fixme_hook_test.rb` with only `test_pre_push_passes_a_vendored_reference_with_the_marker`. Run `ruby -Itest test/no_fixme_hook_test.rb`. Watch it fail: the push is refused, and the output names the no-fixme check and the reference file.
2. Add `test_pre_commit_passes_a_vendored_reference_with_the_marker`. Run it. Watch it fail for the same reason.
3. Add `test_pre_commit_rejects_the_marker_in_a_skill_file_outside_references` and `test_pre_push_rejects_the_marker_outside_references_pushed_with_a_vendored_reference`. Run them. They pass already: they guard that the exclude stays narrow.
4. Add the exclude line to the `pre-push` `no-fixme` command. Run the file: the pre-push tests pass, the pre-commit vendored test still fails.
5. Add the exclude line to the `pre-commit` `no-fixme` command. Run the file: all four tests pass.
6. Run `test/lefthook_local_hooks_test.rb` and `test/lefthook_posix_sh_test.rb`: they exercise the same `lefthook.yml` and must stay green.
7. Lint: `yamllint lefthook.yml` and `rubocop test/no_fixme_hook_test.rb`. Fix every finding in the code; add no disable comment.
8. Run the full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`.
9. Verify as a human would: from this worktree, run `lefthook run pre-push --command no-fixme --file agents/.agents/skills/rails-guides/references/command_line.md --no-auto-install` (lefthook 2.2.2 takes `--file`; confirm with `lefthook run --help`). The no-fixme command must pass. Record the output in the change folder's evidence or the PR body.
10. Re-read the diff. Commit the test and the `lefthook.yml` change as one logical change.

## Risks

- GNU grep could match the pattern differently from BSD grep. CI runs the new tests on GNU grep, so a difference shows as a red CI run, not as a silent pass.
- A pass test can pass for the wrong reason: lefthook can skip a command when its file list is empty. Step 1 watches the push fail before the exclude exists, which proves the file reaches grep. The two "rejects" tests prove the same after the change.
- The pattern covers every skill's `references/` folder, not only vendored skills. Repository-owned skills have one too, for example `dotfiles-maintenance/references/` and `new-repo-setup/references/`. A marker there is no longer refused. This is the scope `intent.md` agreed (`agents/.agents/skills/*/references/`). A narrower list built from `VENDORED-SKILLS.yml` would change that agreed scope, so it is not done here.
- The `*` in the pattern crosses `/`. A deeper path such as `agents/.agents/skills/a/b/references/x.md` is excluded too.
- A first push of a branch to an origin without refs can give lefthook an unexpected file list. The test clones a bare origin whose `HEAD` is a trunk branch, pushes the trunk with `LEFTHOOK=0`, then pushes a feature branch through the hook, as `test/review_push_hook_test.rb` does.
- Rejected: lefthook's own `exclude:` option on the command. It would work without grep, but it breaks the pattern of the neighbouring `--exclude` lines, and lefthook's glob matching differs between versions. Rejected: rewording the vendored documents, which the intent forbids.

## Out of scope

- The `no-nocommit` commands and every other hook command.
- Any change to vendored skill files or to `VENDORED-SKILLS.yml`.
- `lefthook-local.yml` and `lefthook-branch-guard.yml`; neither has a `no-fixme` command.
- Rebasing PR #209.
- `.github/workflows/`; no workflow change is needed.

## Proof

- A pushed branch that contains `rails-guides/references/command_line.md` with its marker passes the `no-fixme` check → `test/no_fixme_hook_test.rb` `test_pre_push_passes_a_vendored_reference_with_the_marker`
- A pushed or committed file outside the vendored references that contains the marker is still refused → `test/no_fixme_hook_test.rb` `test_pre_commit_rejects_the_marker_in_a_skill_file_outside_references` and `test_pre_push_rejects_the_marker_outside_references_pushed_with_a_vendored_reference`
- The pull request's `Dotfiles tests` CI run is green → check: `gh pr checks <pr>` shows `Dotfiles tests` passing, with `test/no_fixme_hook_test.rb` in its log.

Per changed file, the unit tests expected:

- `test/no_fixme_hook_test.rb`: `pre-push passes a vendored reference with the marker`, `pre-commit passes a vendored reference with the marker`, `pre-commit rejects the marker in a skill file outside references` (`agents/.agents/skills/rails-guides/SKILL.md`; the output holds the no-fixme fail text and names that path), `pre-push rejects the marker outside references pushed with a vendored reference` (the reference file and `outside.txt` in one push; the output holds the no-fixme fail text and names `outside.txt`, not the reference file). Use a `.txt` file: a `.sh` file also triggers `shellcheck`, which could refuse the push for another reason.
- `lefthook.yml`: covered by the tests above; no own unit test.

Test setup: every fixture commit for a pre-push test uses `LEFTHOOK=0`, because the real pre-commit hook would refuse the marker; only the `git push` runs through the hooks. A temporary `HOME` with `Developer/dotfiles/lefthook.yml` copied from the repository, `.config/git/hooks` pointing at `git/.config/git/hooks`, and a stub `review-report-fresh` that exits 0. A bare origin with `HEAD` on `trunk`, cloned into a work directory. `PATH` holds a `lefthook` wrapper around the real binary, then `/usr/bin:/bin`. Git config isolation comes from `require_relative "isolated_git"`; `LEFTHOOK_BIN` is cleared. The test skips with `LefthookBinary::MISSING_MESSAGE` when lefthook is missing, as the other hook tests do. The marker is always built as `"FIX" + "ME"`.

---
Domain skills applied: dotfiles-maintenance (lefthook config and test layout), rails-testing (Minitest conventions, one behaviour per test).

## Critique

### Round 1 (codex exec -p terra)

- Step 9 uses `--files`, but lefthook 2.2.2 takes `--file` → fixed (step 9 now runs `lefthook run pre-push --command no-fixme --file <path> --no-auto-install`)
- The pre-push fixture commit would be refused by the real pre-commit hook first → fixed (Test setup now says every pre-push fixture commit uses `LEFTHOOK=0`; only the push runs through the hooks)
- The pre-push negative test uses `bin/tool.sh`, which also triggers `shellcheck`, so the push could fail for another reason → fixed (the test uses `outside.txt` and asserts the no-fixme fail text and the path)
- The pre-commit negative test uses `SKILL.md`, so a broad `*.md` exclude would pass it; use `outside.txt` → dismissed: a `*.md` exclude would also exclude `SKILL.md`, so this test then fails and catches the mistake; `SKILL.md` sits next to `references/` and guards the real boundary. The test now also asserts the no-fixme fail text and the path.
- The risk text says every matched reference is vendored, but `dotfiles-maintenance/references/` and `new-repo-setup/references/` are repository-owned → fixed (Risks now states the pattern covers owned skills too, that this is the scope `intent.md` agreed, and that a narrower list would change it)
