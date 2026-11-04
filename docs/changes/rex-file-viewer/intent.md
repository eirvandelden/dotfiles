# Intent: Changed-files viewer for Rex

Author: Etienne van Delden. Status: accepted. Type: feature. Delivery: autonomous. Codex review: no.

## Problem

An agent in a Rex pane says it finished writing something. In Rex there is no way to see which files it changed and read them. The herdr setup had `herdr-file-viewer` for this, with markdown rendered in the terminal. It does not exist in Rex.

## Proposed outcome

One key opens a viewer over the screen. It lists every file the agent changed in its worktree. Selecting a file shows it. Markdown is rendered. Other files show their diff. A key closes the viewer and returns to the agent.

## Affected users and systems

Etienne, in Rex on macOS. The `rex` stow package: `init.lua`, a new Lua action and a new shell script, like the agent switcher. Tools used: `fzf`, `glow`, `delta`, `bat`, `git`. All are installed.

## Constraints

- Built on top of the `rex-agent-switcher` branch; the PR stacks on it.
- No new dependency. No herdr dependency.
- Ruby 4 scripts only if Ruby is needed; shell and Lua are preferred, like the switcher.
- Rex's layer API opens the viewer, like `agent_switcher` does.
- Autonomous delivery needs no permissions: no dependency, deploy file, migration or system tool.

## In scope

- A Rex action `file_viewer` and a key bind to open it as a floating layer.
- The root is the git toplevel of the focused pane's working directory.
- The list holds files changed against the merge-base with the base branch, plus uncommitted and untracked files.
- Preview of the selected file: markdown through `glow`; other text files as a `delta` diff; deleted files as a diff; untracked files as highlighted content through `bat`.
- A key that switches the preview between diff and content for the selected file.
- Keys to move, scroll the preview and close the viewer.
- Tests for the pure parts, like the switcher's row tests.

## Out of scope

- Editing files, staging, committing, or posting review comments.
- A directory tree of unchanged files; the herdr viewer's worktree picker, pinned previews and note-sending.
- Opening as a tab or split.
- Any change to the herdr setup or `worktree-viewer`.
- Live refresh while the viewer is open.

## Acceptance criteria

- Pressing the key in an agent pane opens a layer that lists the files the agent changed, committed or not.
- Selecting `docs/changes/x/plan.md` shows it rendered as markdown, with headings and lists styled.
- Selecting a changed Ruby file shows its diff first; the toggle key shows the highlighted file.
- A file the agent created and did not commit appears in the list and opens as content.
- A deleted file appears in the list and opens as a diff.
- With no changes, the viewer shows "No changed files" and closes on any key.
- In a directory that is not a git repository, the viewer shows "Not a git repository" and closes on any key.
- The close key removes the layer and returns focus to the agent pane.

## Decisions

- List branch changes and uncommitted changes together — agents commit often, so uncommitted-only would show nothing.
- Open as a floating layer — it matches the agent switcher.
- Show the diff first for non-markdown files — answering "what did it change" is the goal.
- Standalone fzf script, not the herdr binary — chosen over reusing the herdr plugin; no herdr dependency.

## Open questions

None.
