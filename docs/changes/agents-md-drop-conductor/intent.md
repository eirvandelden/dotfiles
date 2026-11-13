# Intent: Drop conductor from the repo agents file

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-13). Type: chore.
Delivery: autonomous. Codex review: no.

## Problem

CI on `main` is red. `RepoAgentsFileTest#test_names_no_package_that_packages_conf_dropped` fails, because the repo agents file (`agents.md`, line 7) still names the `conductor` stow package. Commit 7ebcd89f removed that package and dropped it from `STOW` in `packages.conf`. PRs #286 and #287 wait on a green `main`.

## Proposed outcome

The repo agents file names exactly the stow packages that `packages.conf` lists, and `main` CI is green again.

## Affected users and systems

- The repo agents file `agents.md`. The root `CLAUDE.md` is a symlink to it, so one edit covers both.
- GitHub Actions CI on `main`, and the open PRs #286 and #287 that rebase onto the fix.

## Constraints

- The existing test `test/repo_agents_file_test.rb` already fails for the right reason; it is the regression test. Do not change it.
- No new permissions needed: no dependencies, system tools, migrations or deploy files.

## In scope

- Remove `conductor` from the package list on line 7 of `agents.md`.

## Out of scope

- The wider Conductor cleanup, deferred to its own intent: Conductor text in `README.md`, `git/.config/git/worktree-tools/README.md`, playbook rule 22 and `docs/plans/worktree-init-hostname.md`; Conductor support in worktree-tools `lib/common.rb`, `lib/config.rb`, `lib/detect.rb` and their tests; the Codex trust entry for `~/Developer/conductor/repos/dotfiles` in `codex/.codex/config.toml`.
- Any change to `packages.conf` or the test.

## Acceptance criteria

- The package list in `agents.md` no longer names `conductor`, and still names every package in `STOW`.
- `bin/test test/repo_agents_file_test.rb` passes, and `bin/test` passes in full.
- CI on the fix's pull request is green.

## Decisions

- Split: CI fix now, cleanup intent later — main goes green fastest, PRs #286 and #287 unblock soon, and each PR stays one concern.
- Deliver autonomously, no Codex review — the fastest path to a green `main` for a one-line chore.

## Open questions

None.
