# Intent: Rubocop hooks work when Bundler loads a gem from git

Author: Etienne van Delden. Status: accepted. Type: bugfix.

## Problem

Many repositories run the hook jobs from the dotfiles `lefthook.yml`. A repository without a lefthook config of its own gets it as the global fallback. A repository whose lefthook config lists `git@github.com:eirvandelden/dotfiles` under `remotes` gets a copy of it.

The pre-commit and pre-push `rubocop` jobs in that file fail in any repository whose `.rubocop.yml` loads a gem that Bundler installs from git. Example: clocky's `.rubocop.yml` has `inherit_gem: rubocop-eirvandelden`, and its Gemfile loads that gem from GitHub. Both hooks stop with `Unable to find gem rubocop-eirvandelden; is the gem installed?`. The same `rubocop` command works by hand. Some repositories carry their own `rubocop` jobs, and these fail the same way.

Today Etienne cannot commit or push Ruby files in such a repository without skipping the hook. Skipping needs his approval every time, so the work stalls.

Cause, verified on 2026-10-06 in clocky: git exports `GIT_DIR` to hook processes, and lefthook passes it on to every job. Bundler checks a git-sourced gem by running git inside the gem's checkout. With `GIT_DIR` set, those git commands read the project's repository instead of the gem's. The revision does not match, so Bundler treats the gem as missing.

Repro, from clocky:

- `rubocop config/application.rb` reports no offenses.
- `GIT_DIR=$(git rev-parse --absolute-git-dir) rubocop config/application.rb` reports `Unable to find gem rubocop-eirvandelden`.

## Proposed outcome

In every eirvandelden repository checked out in `~/Developer`, the pre-commit and pre-push `rubocop` jobs check the files and pass or fail on the code alone, also when RuboCop loads its config from a gem installed from git. Pre-commit autocorrection still lands in the commit. Nobody needs to skip a hook for this reason again.

## Affected users and systems

- Etienne, in every eirvandelden repository checked out in `~/Developer`.
- The `rubocop` jobs under `pre-commit` and `pre-push` in the dotfiles `lefthook.yml`.
- Repositories that pull the dotfiles config through `remotes`, known on 2026-10-06: clocky, ddicompendium, dm-adventure-book, fizzy, journal_administration, mvpa.css, sticker-app, writebook.
- Repositories with a `rubocop` job of their own, known on 2026-10-06: appkit, cityofbrass, happiness (already prefixes `env -u GIT_DIR`), journal_administration, my-rails-template.
- mvpa.css skips the remote's pre-commit `rubocop` job in its `lefthook-local.yml`. This bug may be the reason.

## Constraints

- Hook commands run under `sh -c`, which is dash on Linux. They must work on macOS and Linux: POSIX sh only, no GNU-only or BSD-only flags.
- Tests run offline. The git-sourced gem comes from a local repository, never from GitHub or rubygems.org.
- The dotfiles repository is public: no work references in any diff.
- Work repositories stay untouched (playbook rule 15).
- Pull requests target `origin`. No GitHub comment goes out without Etienne's approval of the exact text.

## In scope

- The dotfiles pre-commit `rubocop` job, including its `stage_fixed: true` re-staging.
- The dotfiles pre-push `rubocop` job.
- An acceptance test in the dotfiles repository that fails before the fix and passes after it.
- A fresh check of every eirvandelden repository in `~/Developer` for its own `rubocop` jobs and for the dotfiles remote.
- After the dotfiles fix merges: refresh the remote copy in each repository that pulls the dotfiles config, and show that a Ruby commit there passes the `rubocop` job.
- A separate change for each repository with its own `rubocop` job, also where no gem loads from git yet. Each runs its own intent, plan and implement chain after the dotfiles pull request, and ends in its own pull request. happiness is already fixed and needs a check only.
- mvpa.css: find out why it skips the pre-commit `rubocop` job. Remove the skip in its own change only when this bug was the reason.

## Out of scope

- Every other job in the dotfiles config: erb_lint, minitest, rspec, brakeman, bundle-audit and the post-merge bundle job.
- `GIT_WORK_TREE` and `GIT_INDEX_FILE`, unless the fix needs them.
- The generated hook scripts in `git/.config/git/hooks/`.
- Known unrelated failures: `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, and the `[[ ]]` bash-ism in the `lefthook.yml` `no-push-to-main` job on Linux.
- Work repositories.
- rails-console-on-nomad: it has no GitHub remote, so nothing ties it to eirvandelden.
- Other problems the per-repository check finds, such as a pre-push job that reads `{staged_files}`. Those get proposed as separate changes.

## Acceptance criteria

Criteria 1–5 hold in a repository that uses the dotfiles hook config and loads its RuboCop config from a gem installed from git:

1. Committing a Ruby file with no offenses succeeds, and RuboCop inspected that file.
2. Committing a Ruby file with an offense RuboCop can fix succeeds. The commit holds the fixed file, and no change to it stays unstaged.
3. Pushing a branch with a clean Ruby file succeeds.
4. A Ruby file with an offense RuboCop cannot fix blocks the commit, and it blocks the push.
5. Without the fix, the acceptance test fails with `Unable to find gem`.

Criteria 6–9 hold across the repositories in `~/Developer`:

6. In clocky, after the dotfiles fix merges and clocky's remote copy refreshes, committing and pushing a Ruby file passes both `rubocop` jobs.
7. In every other repository that pulls the dotfiles config, after its remote copy refreshes, a Ruby commit passes the `rubocop` job.
8. Every eirvandelden repository in `~/Developer` with its own `rubocop` job has an open pull request whose `rubocop` jobs pass while git leaks `GIT_DIR`, or it is shown to pass already.
9. mvpa.css runs the pre-commit `rubocop` job again when this bug caused the skip. Otherwise the skip stays, and its change records the real reason.

## Flagged concerns

- Breadth against small changes: fixing every repository at once conflicts with one logical change per pull request. Chosen side: the dotfiles fix ships alone; each other repository gets its own change chain and pull request.

## Open questions

None.
