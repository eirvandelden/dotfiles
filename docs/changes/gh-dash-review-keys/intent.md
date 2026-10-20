# Intent: Make gh-dash reviews fit my keyboard

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-20). Type: chore. Delivery: autonomous.

## Problem

Reviewing pull requests in gh-dash is slow with Etienne's keyboard. He types Dvorak and navigates with arrow keys on a separate layer, never with vim keys. The PR preview only scrolls with `ctrl+d`/`ctrl+u`, so reading a description needs a chord that does not fit the arrow layer. The diff opens as a unified view, but he reads side-by-side diffs. Merging takes `m`, `y`, Enter, and then three more Enter presses to answer the `gh pr merge` prompts for method, branch deletion and submit.

## Proposed outcome

- `ctrl+↓` and `ctrl+↑` page the PR preview down and up.
- The diff opens side-by-side in delta.
- `ctrl+m`, then one Enter, merges the selected PR and deletes its branch. No other prompt follows.
- `M` does the same as `ctrl+m`, for terminals that cannot tell `ctrl+m` from Enter.
- The merge method comes from git config: a setting per repository or per owner. Without a setting, the merge is a merge commit.

## Affected users and systems

- Etienne, on every machine that stows the `github` package.
- `github/.config/gh-dash/config.yml` in this repository.
- `gh pr merge`, which the merge key runs.
- Git config: global, and any included config such as dotfiles-work's `work-remotes.config`.

## Constraints

- The dotfiles repository is public. No work org, repository or host names may appear in the change.
- gh-dash v4.26.2 is the installed version. The keybinding and pager options it supports set the limits.
- `ctrl+m` reaches gh-dash only when the terminal supports the kitty keyboard protocol. Ghostty does. Herdr is unverified.
- Permissions: the change needs no new dependency, system tool, migration or deploy file.

## In scope

- The pager setting for a side-by-side diff.
- The `ctrl+↑`/`ctrl+↓` preview scroll bindings.
- The `ctrl+m` and `M` merge bindings, with one Enter to confirm and any other answer to cancel.
- Reading the merge method from git config, per repository first, then per owner, then the merge-commit default.
- Documentation of the new gh-dash keys, and of how to set, change and remove the merge method: for all repositories of an owner, for one repository, and the default when nothing is set.
- That documentation serves humans and AI agents. A human finds it in the README. An agent working in any repository, Claude or Codex, finds it when asked to change the merge method.

## Out of scope

- The setting that makes work repositories squash. It belongs in dotfiles-work, as a separate change.
- Keeping the PR description expanded. gh-dash has no option for it; that needs an upstream change.
- Hiding the one-line footer. gh-dash has no option for it.
- The existing `org:` work references in the section filters. Removing them is a separate change.
- The existing `C` octo.nvim binding and the section definitions.

## Acceptance criteria

- With a PR selected, `ctrl+↓` shows the next page of its description and `ctrl+↑` the previous one.
- Pressing `d` on a PR shows its diff with the old and new code side by side.
- In a repository with no setting, `ctrl+m` and Enter merge the PR with a merge commit and delete its branch, with no further prompt. After `r`, gh-dash shows the PR as merged.
- When the owner's setting says squash, `ctrl+m` and Enter squash-merge the PR.
- When a repository's own setting says merge but its owner's says squash, the PR gets a merge commit.
- `ctrl+m` followed by `n` and Enter leaves the PR open and shows no error.
- `M` behaves exactly like `ctrl+m`.
- Following only the README, Etienne sets squash for one owner, overrides one repository back to merge commits, and removes both settings again. Each step changes the next `ctrl+m` merge as described.
- In a different repository, an agent asked "squash-merge this repository's PRs from gh-dash" sets the right setting without further help.

## Decisions

- Keep the three improvements as one change — they all serve one review flow.
- Delete the branch after a merge — no reason given.
- The merge method comes from git config, overridable per repository — Etienne wants to set it per repository without naming work repositories in the public dotfiles.
- Work repositories squash; all others use merge commits — the work convention and his personal one.
- Document how to configure, change and remove the merge method, for humans and AI agents — both must be able to set it.
- Press `r` after a merge to see the merged row (settled 2026-10-20) — gh-dash v4.26.2 cannot refresh the row after a custom command, and the builtin merge brings back the prompts.
- Restow `github`, `agents` and `claude` is approved for the checks after implementation (settled 2026-10-20) — the script and skill reach `~` only through stow.
- Autonomous delivery — Etienne's choice for this personal repository.
- `ctrl+↑`/`ctrl+↓` for preview scrolling — vim keys do not fit Dvorak; plain arrows already move between PRs and sections.

## Open questions

None.
