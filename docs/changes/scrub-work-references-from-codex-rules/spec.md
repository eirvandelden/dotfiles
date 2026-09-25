# Spec: Take the employer's details back out of the public dotfiles

From `intent.md` (2026-09-24). Status: accepted.

## Requirements

1. No tracked file in the working tree names the employer, its division, its repositories, its internal issue numbers, its hosts, or its infrastructure.
2. Nothing but those rules is removed.

## Design decisions

**Whole lines go.** Each match is a self-contained `prefix_rule(...)` on one line, asserted before deletion rather than assumed.

**The scan is wider than the obvious name.** Matching the employer's name alone found 8 of 17. The internal issue number, the bug's test filename and the private repo path carry just as much, and none contain that name.

## Acceptance criteria

- A wide scan of the file returns nothing. The pattern covers the employer's name and division word, its three private repository names, its package registry host, its 1Password account host, the internal issue number, the bug's test filename and its codename. It is not written out here: this file is public too. To repeat the scan, read the pattern from the removal commit's diff, which shows every string that triggered it.

- The private work dotfiles checkout is deliberately **not** a target, in either form. The bare name appears in roughly twenty tracked files by design — the 2026-09-08 cleanup established naming the private repo while naming no employer — and the absolute path adds only a local username that the rest of this file already carries throughout. One rule mentioning that path still goes, for the employer's package registry in the worktree name beside it, not for the path.
- The diff is deletions only, no insertions.
- The rest of the repository's tracked files are clean under the same scan.

---
Domain skills applied: `dotfiles-maintenance`.
