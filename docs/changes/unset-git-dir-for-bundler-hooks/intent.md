# Intent: Bundler hook jobs work in linked worktrees

Author: Etienne van Delden. Status: accepted (2026-10-16). Type: bugfix. Delivery: autonomous

## Problem

In a linked worktree of a Ruby project with git-sourced gems, several lefthook jobs fail before they check anything. sticker-app (appkit, mvpa-css, rubocop-eirvandelden from git) shows it: `brakeman` (pre-push), `erb_lint` (pre-commit and pre-push) and `minitest` (pre-push) stop with "Your bundle is locked to appkit (...) but that version can no longer be found in that source" or "Unable to find gem rubocop-eirvandelden". Git exports `GIT_DIR` to hooks in a linked worktree, and Bundler then runs git for git-sourced gems against the wrong repository. The `rubocop` jobs (PR #200) and `bundle-audit` already clear it; the other Bundler jobs do not. This blocks the push of sticker-app branch `update-dependencies`, and skipping the brakeman hook is not acceptable.

A fix in `lefthook.yml` also does not reach most repositories by itself. They load it through lefthook `remotes`, from a cached copy in `.git/info/lefthook-remotes/dotfiles` that only changes when someone updates it by hand.

## Proposed outcome

Every lefthook job that loads the bundle runs the same in a linked worktree as in the main checkout. A new Bundler job that would run with the hook's `GIT_DIR` fails the dotfiles test suite. One command brings every cached remote copy on this machine up to date with dotfiles `main`.

## Affected users and systems

Etienne, in every Ruby repository that uses the dotfiles `lefthook.yml`, directly or through lefthook `remotes`. Systems: `lefthook.yml` in the dotfiles repo, and the cached remote copies in the 11 repositories under `~/Developer` that have one (ambx, caren, cityofbrass, clocky, ddicompendium, dm-adventure-book, journal_administration, mvpa.css, ons-client-old, rspec-testing-101, sticker-app).

## Constraints

- Bugfix: a regression test that fails first, following `test/lefthook_rubocop_git_gem_test.rb`.
- The jobs keep working in a main checkout.
- No `--no-verify`, no skipped hook, no new dependency, no `lefthook install` in another repository.
- The refresh command lives in an existing stow package; no new stow package.
- A sticker-app pre-push job that fails on a real finding (not a missing gem) stops the delivery and asks Etienne.
- Approved permissions: push sticker-app branch `update-dependencies` to its `origin` for the live proof; run `stow -t "$HOME"` for the package that holds the refresh command.

## In scope

- Jobs: `brakeman`, both `erb_lint` jobs, `minitest`, `rspec`, and the `migrations` `bundle` and `migrate` jobs.
- Any other `lefthook.yml` job that loads the bundle.
- A test that fails when a `lefthook.yml` Bundler job runs with the hook's `GIT_DIR`.
- A reusable command that updates every `lefthook-remotes/dotfiles` cache under `~/Developer`, work and personal alike. A cache that cannot fast-forward is reset to its origin. Etienne runs it after the merge.
- The live proof in sticker-app before the merge: point its cache at the feature branch, push `update-dependencies`, then put the cache back on `main`.
- Absorbs the draft intent in worktree `pre-push-minitest-unset-git-dir`.

## Out of scope

- `lefthook-local.yml` and `lefthook-branch-guard.yml` (no Bundler jobs).
- Running the refresh command over all caches after the merge (Etienne does that).
- A static version in mvpa-css.
- Removing the `pre-push-minitest-unset-git-dir` worktree (Etienne does that).

## Acceptance criteria

- In a linked worktree of a Rails repository with a git-sourced gem, the pre-push `brakeman` job analyses the application instead of failing with "can no longer be found in that source".
- In that worktree, the `erb_lint` jobs (pre-commit and pre-push), `minitest` and `rspec` check the changed files instead of failing on a missing gem.
- In that worktree, a pull that changes `Gemfile.lock` or adds a migration runs the post-merge `bundle` and `migrate` jobs without a missing-gem error. A rebase does the same through post-rewrite.
- The same jobs still pass in the main checkout of that repository.
- A new `lefthook.yml` job that loads the bundle without clearing the hook's `GIT_DIR` makes the dotfiles test suite fail, and the failure names the job.
- After the merge, the refresh command brings every cache under `~/Developer` to dotfiles `main` and lists each one it updated.
- A cache with local changes or a diverged history ends up equal to its origin's `main` after the refresh command.
- A cache whose origin is unreachable is named in the output, the other caches still update, and the command exits non-zero.
- From its linked worktree, `git push` of sticker-app branch `update-dependencies` passes every pre-push job without `--no-verify`. Afterwards sticker-app's cache is back on dotfiles `main`.

## Open questions

None.
