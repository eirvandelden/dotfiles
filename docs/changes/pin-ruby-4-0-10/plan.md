# Plan: Pin both repositories to Ruby 4.0.10

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-24). Type: chore. Delivery: step-by-step.

One plan, two pull requests, branch `pin-ruby-4-0-10` in each repository: `~/Developer/dotfiles` and `~/Developer/dotfiles-work`, each in its own worktree.

## Problem

Neither repository has a root `.ruby-version`. Both only inherit Ruby 4.0.10 by accident: `~/.ruby-version` is a stow link to `dotfiles/ruby/.ruby-version`, and `rv` finds it by walking up from `~/Developer/<repo>`. A pane or a CI job that does not walk through the home directory picks another Ruby. The overlay's implement pane just saw 2.7.8.

## Proposed outcome

Each repository holds a root `.ruby-version` with the single line `4.0.10`. `rv` resolves Ruby 4.0.10 inside it with no help from `~`.

## In scope

- `~/Developer/dotfiles/.ruby-version`, new, content `4.0.10`.
- `~/Developer/dotfiles-work/.ruby-version`, new, content `4.0.10`.
- Facts already checked: Ruby 4.0.10 is installed under `rv` (marked `*`), so nothing is installed or switched. RuboCop 1.92.3 knows target Ruby 4.0, so reading the file as a target version is valid.

## Out of scope

- `ruby/.ruby-version` in dotfiles. It is the global default and already says `4.0.10`.
- The two CI workflows, which pin `ruby-version: "3.4"` through `ruby/setup-ruby`. Editing `.github/workflows/` needs separate approval (playbook rule 13). A reviewer may propose a follow-up.
- Installing or switching any Ruby (rule 8), and running `stow`.
- The open overlay branch `drop-intent-from-overlay`.

## Acceptance criteria

- In each repository, `cat .ruby-version` prints `4.0.10`.
- In each repository, `rv ruby run -- ruby -v` (or the `rv` form the repository's docs use) reports 4.0.10 with `~/.ruby-version` out of the lookup. The check runs in a temporary directory copy with the file present and `HOME` pointing at an empty directory, or the exact `rv` command that shows the resolved version.
- dotfiles: `bin/test` and `rubocop` stay green with the file present. `test/rubocop_fallback_test.rb` says that in CI no `.ruby-version` sits above its config, so it is the test to watch.
- dotfiles-work: the eight test files pass under `rv run ruby -Itest -e 'Dir["test/*_test.rb"].each { load _1 }'`.

## Order of work

1. dotfiles worktree: write `.ruby-version`, run `bin/test` narrowest-first (`test/rubocop_fallback_test.rb`, then the full run) and `rubocop`. Commit: `Pin Ruby 4.0.10 in the repository`.
2. dotfiles-work worktree: write `.ruby-version`, run its tests. Commit: `Pin Ruby 4.0.10 in the repository`.
3. Review each branch, deliver two draft pull requests.

## Risks

- A committed `.ruby-version` changes RuboCop's inferred target in CI to 4.0, while CI runs Ruby 3.4. A Ruby 4 syntax feature could pass lint and break CI. `bin/test` runs on the pull request's CI, so a red check shows it. The fix then is the CI Ruby version, a separate approved change.
- `~/.ruby-version` and the repository file can drift. This change does not guard that. A later change could add a test that both agree.

## Proof

- Pin present → check: `cat .ruby-version` in each worktree.
- Resolution without `~` → check: the `rv` command above.
- dotfiles stays green → check: `bin/test` and `rubocop`.
- dotfiles-work stays green → check: the test command above.

Configuration has no tests of its own.
