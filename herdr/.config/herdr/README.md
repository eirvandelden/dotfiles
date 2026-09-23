# herdr

Terminal workspace manager for coding agents. This package carries the config, the worker scripts, and the settings for the plugins herdr loads.

## Browsing and reading files

The `herdr-file-viewer` plugin is a read-only, git-aware file viewer: a tree on the left, and on the right whichever view the file deserves — a rendered markdown document, highlighted code, or a diff.

It is the answer to wanting to read a file without leaving the terminal for an editor preview, a browser, or Obsidian.

### Summoning it

| Key | Opens |
| --- | --- |
| `prefix+f` | A split beside the current pane. For a glance at a file while working. |
| `prefix+shift+f` | Its own tab, filling the terminal. For when reading is the task. |

Both are idempotent. The tab action switches to an existing viewer tab rather than opening a second, and toggles off when you are already on it.

The plugin is not installed by this repository. Install or update it with:

```bash
herdr plugin install smarzban/herdr-file-viewer
```

There is no `herdr plugin update` — re-running the install is the update. The renderers it delegates to (`glow` for markdown, `delta` for diffs, `bat` for code) are already declared in `packages.conf`, so a fresh machine gets them.

### Reading a file an agent wrote

**The viewer opens where the focused pane is.** It does not follow an agent's own `cd`, and worktrees created with `git worktree add` are invisible to it, because herdr was never told they exist. Sitting in the main checkout, that is what you get.

**Press `W` to fix it.** It opens a picker of the repository's git worktrees, marks the current one, and pre-selects the one with an active herdr agent. `↑`/`↓` move, `Enter` switches, `Esc` cancels. It re-roots the viewer only; it never checks out a branch or touches a file.

Reach a worktree that way rather than browsing into `.worktrees/`. The viewer computes git status, the diff baseline, and the changed-file filters against the root it opened, so walking in through the folder gives a plain tree with the wrong baseline. It is also why `.worktrees/` is absent from the tree at all: `~/.config/git/ignore.global` ignores it, and the viewer hides gitignored entries. The `i` key reveals them, at the cost of also showing every dependency and build directory.

### Keys worth knowing

| Key | Does |
| --- | --- |
| `W` | Switch to another git worktree, in place |
| `Z` | Full-screen the file, taking over the whole terminal |
| `v` | Cycle the view. A markdown file offers its rendered view and syntax content; a changed file adds a compact diff and a full-context one. The cycle starts from whichever is the automatic default |
| `w` | Toggle wrapping. On rendered markdown, switches between fitting tables to the pane and showing them at full width |
| `f` | Fuzzy-find any file in the tree |
| `p` | Pin the current file beside the active one and keep browsing; `Tab` then cycles tree, active, pin |
| `{` `}` | Shrink or grow the pinned preview's share |
| `]` `[` | Jump to the next or previous changed file |
| `c` | Filter the tree to changed files only |
| `e` | Open the file in `$EDITOR`; the viewer never writes it |
| `L` | Copy a `path:line` reference, or the selected lines |
| `?` | Help overlay, including the settings actually in effect |
| `q` `Esc` | Close |

A pin is a place to look, not a place to navigate to. Nothing jumps the tree cursor back to a pinned file — use `f`, or copy its path with `y` from the focused pin.

### What this repository sets

Both settings live in `plugins/config/herdr-file-viewer/config.toml`, with the reasoning in the file itself.

`changed_file_view = "content"` makes a changed file open in its normal view rather than as a diff, so markdown arrives rendered. This matters most for agent-written files: they are always git-changed, and a file an agent has just created is diffed against `/dev/null`, so it would otherwise arrive as a whole-file `+` diff that reads as plain source. Deleted paths stay diff-first, and `v` still reaches both diffs.

The cost is that this is one switch over every changed file. A changed Ruby file now opens as highlighted source too, so reviewing what moved costs a `v`. That trade is deliberate.

The markdown renderer is deliberately left unset. The plugin's default passes its own `assets/markdown-style.json`, which colours headings by ANSI palette index — which is what makes rendered markdown follow Ghostty's light and dark swap. Setting `markdown = "glow -s …"` would hardcode one palette and break it.

### When a change does not take

Two different reload paths, and forgetting either makes a correct change look broken.

`config.toml` in this directory needs `herdr server reload-config`. The running server does not reread it on its own.

`plugins/config/herdr-file-viewer/config.toml` is read once when the viewer launches. There is no reload — quit the viewer pane and reopen it.

Either way, the files only exist at these paths once the `herdr` package is stowed.

## Worker scripts

`scripts/hand-off-plan.sh` hands a written plan to a fresh Claude worker in a pane below the caller. `scripts/start-review.sh` asks a reviewer to look at the current branch in a pane beside it. Both refuse to run outside a herdr pane. They are covered by `test/herdr_worker_scripts_test.rb`.
