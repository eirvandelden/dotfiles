# Intent: Pre-push checks scan only the branch's own changes and skip vendored files

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-17). Type: bugfix. Delivery: autonomous.

## Problem

"The fixme marker" and "the nocommit marker" mean the upper-case words that `no-fixme` and `no-nocommit` grep for. This file never spells them, so it passes those checks.

A branch that has a remote copy cannot push after a rebase over main. The pre-push checks scan every file that main changed since the last push, not only the branch's own changes. Lefthook builds that list with `git diff --name-only HEAD @{push}`. After PR #208 moved the skills to `agents/.agents/skills/`, that list holds 374 files. The `no-fixme` check then rejects prose lines with the fixme marker in vendored skills: `37signals-style/references/development-philosophy.md:89` and `rails-guides/references/command_line.md:1077–1100`. PR #194 had to push with `LEFTHOOK_EXCLUDE=fixme`. A fresh branch off origin/main passes, because lefthook then falls back to `git diff --name-only origin/main...HEAD`.

A second cause makes it worse. Vendored content keeps upstream text, and that text can mention the fixme or nocommit marker as prose. Any commit or push that touches such a file fails, even when nobody added a marker. `vim/.vim/colors/solarized.vim` has the same risk.

## Proposed outcome

Every pre-push check scans only the files that the branch itself changes against main, before and after a rebase. The marker checks (`no-fixme`, `no-nocommit`) skip vendored files, at pre-commit and at pre-push. A repository names its vendored paths in one agreed place. `vendor/` counts as vendored in every repository. Nobody needs `LEFTHOOK_EXCLUDE` to push a rebased branch.

## Affected users and systems

- `lefthook.yml` in the dotfiles repository. It is also the global fallback config for every repository without its own lefthook config (`git/.config/git/hooks/*`).
- Every pre-push command that uses `{push_files}`: `no-fixme`, `no-nocommit`, shellcheck, yamllint, rubocop, rspec.
- The dotfiles vendored content: the superpowers-ruby skills, the snapshots in `VENDORED-SKILLS.yml`, and `vim/.vim/colors/solarized.vim`.
- Etienne and every agent that pushes a rebased branch.

## Constraints

- The change reaches every repository that uses the global fallback. It must not weaken the checks for a repository's own files.
- Vendored snapshots stay byte-identical to upstream.
- Linters still check vendored files; only the marker checks skip them.
- Approved permissions: none needed. No dependency, system tool, migration or deploy file changes.

## In scope

- The pre-push file list: the branch's own changes against main, also after a rebase, for every pre-push command.
- A per-repository list of vendored paths, with `vendor/` vendored by default in every repository.
- `no-fixme` and `no-nocommit` skip vendored paths, at pre-commit and at pre-push.
- The dotfiles repository lists its vendored skills and `solarized.vim`.
- Tests for each acceptance criterion.

## Out of scope

- Rewording the vendored prose.
- Moving vendored content into a `vendor/` directory.
- Stacked branches with a base other than main.
- Other lefthook hooks (post-merge, commit-msg).
- The Linux `[[ ]]` bug in `no-push-to-main`.

## Acceptance criteria

- A branch pushed before main moved the skills, then rebased over main, pushes without a fixme-marker failure from files that only main changed.
- A branch that adds the fixme marker to one of its own files is still rejected at push and at commit.
- A branch that changes a vendored skill file whose upstream text mentions the fixme marker commits and pushes cleanly.
- In a repository with a `vendor/` directory, a fixme marker under `vendor/` does not block a commit or a push.
- In a repository that lists a vendored path, a nocommit marker in that path does not block a commit or a push.
- A fixme marker added to a non-vendored skill in the dotfiles repository still blocks the push.
- After a rebase, shellcheck and yamllint check only the files that the branch changes, not the files that main changed.
- A fresh branch off origin/main without a remote copy behaves as today.

## Open questions

None.
