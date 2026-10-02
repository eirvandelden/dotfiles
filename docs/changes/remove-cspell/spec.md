# Spec: Remove the cspell spell checker

From `intent.md` (2026-10-01). Status: accepted.

## Requirements

1. No commit in the dotfiles repository, or in a repository that uses the fallback hooks, is stopped by a spell check.
2. A new machine installs no spell checker and links no spell checker configuration.
3. CI installs and runs no spell checker.
4. The hook tests need no spell checker and do not skip when none is installed.
5. No tracked file outside `docs/changes/` refers to cspell. The change folders of other changes are exempt, as the intent says.
6. This machine no longer has the `~/.config/cspell` link or the global `cspell` package. Claude removes the link before the PR merges and the package after it. Both steps are approved in the intent.

## Design decisions

- The `cspell` stow package, with its config and dictionary, is deleted whole. Nothing else reads it.
- Text that names cspell is deleted, not replaced with another tool.
- The markdownlint hook tests currently get `node` from the cspell directory on PATH. They must get it another way, or markdownlint fails on its `#!/usr/bin/env node` shebang.
- Hits for "spell" that are not cspell stay: Vim `Spell*` highlight groups, macOS `defaults` comments, and the word "spelling" in prose comments.
- `AGENTS.md` and `agents.md` do not mention cspell and stay unchanged.

## Integration points

- `lefthook.yml`: the `spelling` command and the commented-out `commit-msg` spell check. The fallback pre-commit hook reads this file.
- `packages.conf`: the `cspell` entries in the npm list and the stow list.
- `cspell/.config/cspell/`: the package to delete.
- `.github/workflows/dotfiles-tests.yml`: the "Install cspell" step. Etienne approved this edit on 2026-09-30.
- `test/lefthook_local_hooks_test.rb`: the cspell lookup, the skip and the PATH setup.
- `claude/.claude/skills/dotfiles-maintenance/SKILL.md`: the linter list.
- `~/.config/cspell` and the global npm package on this machine.
- Other repositories that use cspell are out of scope. Each gets its own change.

## Acceptance criteria

- Committing a file with a misspelled word in the dotfiles repository succeeds.
- A commit in a repository with no `lefthook.yml` of its own is not stopped by a spell check.
- `packages.conf` lists no `cspell` entry in either the npm or the stow list.
- The `cspell` directory is gone from the repository.
- The CI workflow has no step that installs cspell.
- The lefthook hook tests pass on a machine with no `cspell` on PATH, and none of them is skipped for that reason.
- The hook tests that need markdownlint still run it on a machine with no `cspell` on PATH.
- `grep -ri cspell` over tracked files, excluding `docs/changes/`, finds nothing.
- After the stow removal, `~/.config/cspell` does not exist and is not a broken link.

---
Domain skills applied: None.
