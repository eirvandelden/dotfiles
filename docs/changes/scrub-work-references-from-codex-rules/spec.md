# Spec: Take the employer's details back out of the public dotfiles

From `intent.md` (2026-09-24). Status: accepted.

## Requirements

1. No tracked file in the working tree names the employer, its repositories, its internal issue numbers, its hosts, or the private work dotfiles path.
2. Nothing but those rules is removed.

## Design decisions

**Whole lines go.** Each match is a self-contained `prefix_rule(...)` on one line, asserted before deletion rather than assumed.

**The scan is wider than the obvious name.** Matching the employer's name alone found 8 of 17. The internal issue number, the bug's test filename and the private repo path carry just as much, and none contain that name.

## Acceptance criteria

- A wide scan of the file returns nothing. The pattern covers the employer's name, its three private repository names, its package registry host, its 1Password account host, the internal issue number, the bug's test filename, its codename, and the private dotfiles path. It is not written out here: this file is public too.
- The diff is deletions only, no insertions.
- The rest of the repository's tracked files are clean under the same scan.

---
Domain skills applied: `dotfiles-maintenance`.
