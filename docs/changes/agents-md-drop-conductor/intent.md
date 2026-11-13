# Intent: Drop conductor from the repo agents file

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-13). Type: chore.
Delivery: autonomous. Codex review: no.

## Problem

CI on `main` is red. `RepoAgentsFileTest#test_names_no_package_that_packages_conf_dropped` fails, because the repo agents file (`agents.md`, line 7) still names the `conductor` stow package. Commit 7ebcd89f removed that package and dropped it from `STOW` in `packages.conf`. PRs #286, #287 and #285 merged into the red `main` meanwhile.

#285 added a second red test: `IsolatedGitTest#test_every_test_file_requires_the_helper` fails, because `test/state_dirs_install_test.rb` does not require `isolated_git`.

Locally, full `bin/test` also fails: `test/secrets_loader_test.rb` has 5 failures. Its `run_secrets` helper runs `zsh -c` without `-f`, so zsh sources the repo's `.zshenv`. That file puts `/opt/homebrew/bin` ahead of the test's `op` stub, and the real 1Password CLI answers. CI has no `op` there, so CI passes that file.

## Proposed outcome

The repo agents file names exactly the stow packages that `packages.conf` lists. Every test file requires `isolated_git`. The secrets loader tests use their `op` stub on every machine. `main` CI is green again, and full `bin/test` passes locally.

## Affected users and systems

- The repo agents file `agents.md`. The root `CLAUDE.md` is a symlink to it, so one edit covers both.
- `test/state_dirs_install_test.rb` and `test/secrets_loader_test.rb`.
- GitHub Actions CI on `main`, and local `bin/test` runs on a machine with the 1Password CLI installed.

## Constraints

- The existing tests `test/repo_agents_file_test.rb` and `test/isolated_git_test.rb` already fail for the right reason; they are the regression tests. Do not change them.
- `test/secrets_loader_test.rb` fails only on a machine with the real `op` on the Homebrew path; that local run is its regression proof.
- No new permissions needed: no dependencies, system tools, migrations or deploy files.

## In scope

- Remove `conductor` from the package list on line 7 of `agents.md`.
- Make `test/state_dirs_install_test.rb` require `isolated_git`.
- Make the secrets loader tests run against their `op` stub even when the real 1Password CLI is installed.

## Out of scope

- The wider Conductor cleanup, deferred to its own intent: Conductor text in `README.md`, `git/.config/git/worktree-tools/README.md`, playbook rule 22 and `docs/plans/worktree-init-hostname.md`; Conductor support in worktree-tools `lib/common.rb`, `lib/config.rb`, `lib/detect.rb` and their tests; the Codex trust entry for `~/Developer/conductor/repos/dotfiles` in `codex/.codex/config.toml`.
- Any change to `packages.conf`, `test/repo_agents_file_test.rb` or `test/isolated_git_test.rb`.
- Any change to the secrets loader itself (`zsh` package).

## Acceptance criteria

- The package list in `agents.md` no longer names `conductor`, and still names every package in `STOW`.
- `bin/test test/repo_agents_file_test.rb` passes.
- `bin/test test/isolated_git_test.rb` passes: every test file requires `isolated_git`.
- On this machine, with `/opt/homebrew/bin/op` installed, `bin/test test/secrets_loader_test.rb` passes, and no test reaches the real 1Password CLI.
- `bin/test` passes in full.
- CI on the fix's pull request is green.

## Decisions

- Split: CI fix now, cleanup intent later — main goes green fastest, PRs #286 and #287 unblock soon, and each PR stays one concern.
- Deliver autonomously, no Codex review — the fastest path to a green `main` for a one-line chore.
- Fold the one-line `isolated_git` require into this PR (2026-11-13, after review round 1) — no reason given; it makes `main` green with one merge.
- Fix the local secrets loader test failures in this PR (2026-11-13, after review round 1) — no reason given; full `bin/test` must pass, as the criterion says.

## Open questions

None.
