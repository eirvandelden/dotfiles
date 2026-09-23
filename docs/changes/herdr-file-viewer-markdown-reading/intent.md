# Intent: Read agent-written markdown without leaving the terminal

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature.

## Problem

Reading a markdown file well means leaving Ghostty. Today that is an editor preview pane, a browser, Obsidian, or Quick Look — whichever is nearest. Every one is a context switch out of the terminal where the work is happening, and back again.

The files being read are no longer typed by hand. An agent writes them, in a worktree, while its pane is still open. Two things follow.

They are always git-changed files, and the viewer opens a changed file as a diff. Prose read as a diff is unreadable: every paragraph prefixed, unchanged context interleaved with changes, headings and tables gone. The one view that would keep the reading in the terminal is the one an agent's output never gets.

They also sit in a worktree the viewer does not open at. The viewer roots at the focused herdr pane's directory, and that pane is in the main checkout. `W` re-roots to any worktree of the repo and pre-selects the one a herdr agent is working in — verified working. Nothing said so. The capability was there and unreachable, because no document in this repo mentions the viewer at all.

Last, there is no way to give a file the whole terminal. The split shares a pane with the work and hands part of that column to the tree; the viewer's own-tab action exists but nothing is bound to it.

## Proposed outcome

Browsing and reading a file an agent just wrote happens inside Ghostty and herdr, and stays there.

A markdown file opens rendered — headings, tables, inline code, in the terminal's own palette — without a keypress to get there. One key opens the viewer full-width in its own tab, for when reading is the task rather than a glance beside the work.

A README in the `herdr` package explains how to reach an agent's worktree and read what it wrote, so the next person to want this does not have to rediscover `W`. The repo's top-level README points at it.

Good enough to stop reaching for the other four readers on an ordinary read. Not a claim to match a browser or Obsidian on typography.

The settings live in the dotfiles repo and arrive through stow, so a fresh machine gets them.

## Affected users and systems

This machine's herdr setup: the `herdr` stow package and the `herdr-file-viewer` plugin it drives. The top-level README gains a pointer.

## Constraints

Scope is the already-installed `herdr-file-viewer`. Tuning and documenting it, not replacing it and not surveying other terminal readers.

Every file belongs inside the existing `herdr` stow package, so no new stow package is created.

The package README goes at the stowed path, `herdr/.config/herdr/README.md`, matching the three that already exist in this repo. Not the package root: stow maps a package's top-level entries to the target root and `README.md` is not in `.stow-global-ignore`, so `herdr/README.md` would link to `~/README.md`.

The plugin's bundled markdown style colors headings by ANSI palette index, which is what makes rendered markdown follow Ghostty's light and dark swap. Overriding the `markdown` renderer command would hardcode a palette and break that, so the renderer stays untouched.

A terminal renderer will not match a browser on images, fonts, or full typography. The bar is the ordinary read, not every read.

Tree width stays at its defaults; full-screen reading is what `Z` is for.

Gitignored entries stay hidden. `.worktrees/` is ignored by `~/.config/git/ignore.global`, but `W` reaches a worktree properly and keeps git status, diff baseline, and the changed-file filters correct for that root. Revealing the folder instead would give a plain tree with the wrong baseline, and would also surface build output and dependency directories.

## Open questions

None.
