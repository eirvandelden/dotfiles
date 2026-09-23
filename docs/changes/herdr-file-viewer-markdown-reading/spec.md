# Spec: Read agent-written markdown without leaving the terminal

From `intent.md` (2026-09-22). Status: accepted. Written against herdr-file-viewer 1.17.0.

## Flagged concerns

**Requirement 5 is adjacent work, carried here by decision.** The stow-root guard is a repository invariant, not part of reading markdown. The playbook sends orthogonal improvements to their own branch. Asked, and the answer was to keep it on this branch in its own commit. Recorded so the next reader knows it was a choice rather than an oversight.

## Requirements

1. A markdown file with uncommitted changes opens rendered — headings, tables, inline code — with no keypress to get there. This includes a file an agent has just created and never committed: `src/git.rs` diffs an untracked path against `/dev/null` with `--no-index`, so a brand-new file is a whole-file `+` diff, which through delta reads as plain source. The diff stays reachable.
2. One key opens the file viewer full-width in its own tab, distinct from the existing split.
3. Someone reading this repository can find out how to reach an agent's worktree in the viewer and read what it wrote, without already knowing the keys.
4. All of it arrives on a fresh machine through stow, inside the existing `herdr` package, and lands nowhere unintended.
5. A file placed at a stow package root, which stow would link into the home directory, fails the test suite instead of appearing silently in `$HOME`.

## Design decisions

**Rendered-first lives in the plugin's own config file.** Source: `herdr/.config/herdr/plugins/config/herdr-file-viewer/config.toml`, holding `changed_file_view = "content"`. Stowed to `~/.config/herdr/plugins/config/herdr-file-viewer/config.toml`, the path `herdr plugin config-dir herdr-file-viewer` prints. That directory already exists and is empty, so stow folds into it and links the single file.

**The tab key is `prefix+shift+f`,** beside the existing `prefix+f` split. Free: herdr's defaults take shift with `r`, `n`, `g`, `w`, `d`, `t`, `x`, `p` and Tab, and this config takes `prefix+shift+1..9`. It binds the plugin action `herdr-file-viewer.open-file-viewer-tab`, which the manifest declares for macOS and Linux. The action is idempotent — it switches to an existing viewer tab rather than opening a second, and toggles off when already there.

**The package README goes at the stowed path,** `herdr/.config/herdr/README.md`, landing beside `config.toml` at `~/.config/herdr/README.md`. This matches the three package READMEs already in the repo, all of which sit at their stowed path. The package root is wrong, not merely unconventional: stow maps a package's top-level entries to the target root and `README.md` is not in `.stow-global-ignore`, so `herdr/README.md` would link to `~/README.md`.

**The top-level README gets a pointer, not the content,** mirroring how its Git Worktree Automation section links `git/.config/git/worktree-tools/README.md`.

**The renderer command stays unset.** The plugin's default passes its own bundled `assets/markdown-style.json`, which colors headings by ANSI palette index. That is what makes rendered markdown follow Ghostty's light and dark swap. Any explicit `markdown = "glow -s …"` would hardcode a palette.

**Reading wins over reviewing, deliberately.** `changed_file_view` is one switch over every changed file, not only markdown. Content-first means a changed Ruby file opens as highlighted source, so walking an agent's changes with `]` / `[` costs a `v` to reach each diff. Accepted: reading an agent's prose is the frequent act, reviewing its diff the rarer one, and `v` still reaches the diff either way.

**The guard reads the package list rather than globbing directories.** `packages.conf` declares which top-level directories stow actually installs, so parsing its `STOW=(…)` list checks exactly that set. Globbing the repository root instead would need a hand-maintained skip-list for `docs`, `test`, `install` and `github`, which rots the first time a directory is added.

**Reaching the agent's worktree stays manual, by `W`.** The viewer roots at the focused herdr pane's directory, and that pane sits in the main checkout. `herdr worktree list` confirms why: of eleven linked worktrees, none is open as a herdr workspace — only the main checkout has an `open_workspace_id`. The cause is that `worktree-first` creates worktrees with `git worktree add` and never tells herdr, so there is no pane to root at. Fixing that means opening each worktree as a workspace with `herdr worktree open`, which changes the `worktree-first` skill and how work is organised — larger than this change and briefed separately. Here, `W` is the answer and requirement 3 makes it findable.

**`show_ignored` stays off.** `W` reaches a worktree properly and keeps git status, the diff baseline, and the changed-file filters correct for that root. Revealing `.worktrees/` would give a plain tree with the wrong baseline, and surface dependency and build directories besides.

## Integration points

- `herdr/.config/herdr/config.toml` — gains one `[[keys.command]]` block. Needs `herdr server reload-config` to take effect; the running server does not reread it on its own.
- The plugin config is read at viewer launch only. There is no reload; the viewer must be quit and reopened.
- `packages.conf` already declares `herdr`, `glow`, `bat` and `git-delta`. Nothing to add — the renderers a fresh machine needs are already installed by the existing list.
- The plugin itself is installed by `herdr plugin install smarzban/herdr-file-viewer`, outside this repository and outside this change. Re-running that command is also how it updates; there is no `herdr plugin update`.
- Updated to 1.17.0 on 2026-09-23, before this spec was settled. The action id `open-file-viewer-tab`, the config directory, and `changed_file_view` are all unchanged by it, so every design decision above was re-verified against the installed version rather than the one first read.
- 1.17.0 also fixes a tree that could come up empty because the ancestor-`.gitignore` search climbed past the repository boundary, which it named a dotfiles-managed home directory as a trigger for. Nothing in this change depends on that, but it is the version this repository now documents.
- 1.17.0 adds `open_direction` (whether the summon key splits right or down) and `baseline` (which diff baseline the viewer starts on). Both are out of scope here; neither replaces `changed_file_view`.

## Acceptance criteria

Verified by hand in the viewer, because the system under test is an interactive TUI:

- Opening a markdown file that has uncommitted changes shows it rendered, with headings and tables, and no diff prefixes.
- Pressing `v` on that same file still reaches its diff.
- Opening a file the agent deleted still shows a diff, because there is no content left to render.
- Pressing `prefix+shift+f` opens the viewer filling the terminal in its own tab; pressing it again returns to where it was, without a second viewer tab appearing.
- `prefix+f` still opens the viewer in a split beside the current pane.

Verified by reading the repository:

- Someone who has never used the viewer can follow `herdr/.config/herdr/README.md` from a cold start to reading a file an agent just wrote in a worktree, including pressing `W`.
- The top-level README names the viewer and links to that file, and the link resolves.

Verified by the test suite, `ruby -Itest test/stow_package_roots_test.rb`:

- A package whose root holds only dot-prefixed entries passes.
- A package with a plain `README.md` at its root fails, and the failure names that file and the `~/README.md` it would become.
- The check covers exactly the packages `packages.conf` declares, so a package added to that list is covered without touching the test.

Verified by inspecting the stow result:

- After stowing, `~/.config/herdr/README.md` and `~/.config/herdr/plugins/config/herdr-file-viewer/config.toml` are symlinks into this repository, and no `~/README.md` has appeared.

---
Domain skills applied: `dotfiles-maintenance`.
