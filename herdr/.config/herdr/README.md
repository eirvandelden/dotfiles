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

**The keys open the viewer at the agent's worktree.** `prefix+f` and `prefix+shift+f` run `worktree-viewer` from the `git` package. When the focused pane has an agent that created or reused a worktree with `worktree-create`, the viewer opens there: beside the agent for `prefix+f`, in its own tab for `prefix+shift+f`. `worktree-create` records the worktree per herdr pane, also with `--no-pane`. A record is ignored once its folder is gone or belongs to another repository.

**Without a worktree, the picker shows.** When the agent has no usable record and sits in the main checkout, the viewer opens at the pane's folder and then opens the `W` worktree picker. An agent pane that is already in a worktree opens there without the picker. A pane without an agent, or a viewer already open in the tab, is handled by the plugin's own actions as before.

**Any other worktree: press `W`.** The keys only know worktrees made with `worktree-create`. A worktree an agent made with plain `git worktree add`, or entered with its own `cd`, has no record, so the viewer opens at the pane's folder instead. `W` opens a picker of the repository's git worktrees, marks the current one, and pre-selects the one with an active herdr agent. `↑`/`↓` move, `Enter` switches, `Esc` cancels. It re-roots the viewer only; it never checks out a branch or touches a file.

Reach a worktree that way rather than browsing into `.worktrees/`. The viewer computes git status, the diff baseline, and the changed-file filters against the root it opened, so walking in through the folder gives a plain tree with the wrong baseline. It is also why `.worktrees/` is absent from the tree at all: `~/.config/git/ignore.global` ignores it, and the viewer hides gitignored entries. The `i` key reveals them, at the cost of also showing every dependency and build directory.

**Setting it up.** After merging, run `stow -t "$HOME" git` once so `worktree-viewer` appears in `~/.config/git/worktree-tools/`, then `herdr server reload-config` so the new key bindings load.

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
| `y` `Y` | Copy the file's repo-relative or absolute path. From a focused pin, the pin's own path |
| `i` | Show gitignored entries, `.worktrees/` among them, along with every dependency and build directory |
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

## Resizing the focused pane

The `vv.golden-ratio` plugin resizes the focused pane to the golden ratio (61.8% of the tab on each axis) on every focus change. `plugins/config/vv.golden-ratio/config.toml` sets `auto = true`, so no key is needed. Auto mode needs herdr 0.9.1 or newer. The plugin reads its config on every invocation, so a change applies at once.

The dotfiles setup installs and enables the plugin from `HERDR_PLUGINS` in `packages.conf`, through `install/tasks/52_install_herdr_plugins.sh`. It builds with Go 1.24+, which `packages.conf` also installs.

To install it by hand, run `herdr plugin install vigneshwerv/herdr-golden-ratio`, then `herdr server reload-config`. `herdr plugin update` updates it.

herdr-app has its own `golden-ratio` mod, because the TUI plugin never fires there. After the focus rests on a pane for `debounce_ms`, the mod reads the tab tree from herdr-core and resizes each container on the focus path so the focused pane gets the ratio on every axis it shares with a sibling. Its props are `ratio` (0.05 to 0.95, default 0.618), `debounce_ms` (0 to 2000, default 120) and `min_delta` (0 to 0.5, default 0.02, the share difference below which a pane is left alone). It skips zoomed tabs, single-pane tabs and spaces on a remote machine. The `cores` layout mounts it as a zero-size block with those props. It works once the `herdr-app` package files are linked, so restow after pulling.

## Worker scripts

`scripts/hand-off-plan.sh <stage> <change-slug>` starts a named stage (`intent`, `plan`, or `implement`) of a change in a fresh Claude worker rooted in the change's worktree. `intent` opens in a pane below the caller, a new row. `plan` and `implement` open as the next column of the change's row, right of its last pane. `scripts/open-column.sh` places each column and appends it to the row record, `<git-common-dir>/herdr/stage-panes-<slug>`, which `deliver` reads. Every stage but `implement` starts the next one itself once its artifact is accepted. `scripts/start-review.sh` asks a reviewer to look at the current branch as the next column of the change's row, right of its last pane (right of the caller on a branch with no change folder). `open-pr-dash.sh` opens gh-dash the same way, unlisted, so `deliver` never closes it. `hand-off-plan.sh` and `start-review.sh` refuse to run outside a herdr pane and are covered by `test/herdr_worker_scripts_test.rb`. `open-pr-dash.sh` prints the pull request URL there instead and is covered by `test/open_pr_dash_test.rb`. `open-column.sh` is covered by `test/herdr_open_column_test.rb`.

## Notification sounds

herdr has no volume setting and plays each `[ui.sound]` file at full level. `config.toml` therefore points at quieter copies in `~/Documents/Tones/herdr/`, made at 0.3 of the original level, the same as `afplay -v 0.3`. The tones are copyrighted, so neither they nor the copies are in this repository.

`scripts/quieter-tones.sh <source.mp3>...` writes one copy per source under the same file name. The source is only read. Run it again after a tone swap, or after a source tone changes:

```bash
herdr/.config/herdr/scripts/quieter-tones.sh ~/Documents/Tones/Warcraft/Humans/jobs-done.mp3
```

herdr plays only mp3, so the script refuses anything else. It also refuses a file that already sits in the copies folder. It needs `ffmpeg`. After changing the `[ui.sound]` paths, run `herdr server reload-config`. The script is covered by `test/herdr_quieter_tones_test.rb`.

## Solunized theme tables

herdr 0.9.5 has no include and `theme.name` takes built-in names only, so the generated `solunized/dist/herdr/` files cannot load. `config.toml` therefore carries a copy of the light and dark tables between `# BEGIN solunized` and `# END solunized`.

`scripts/sync-solunized-theme.sh` rewrites that block from `$SOLUNIZED_DIR/dist/herdr/` (default `~/Developer/solunized`). It skips black and white, leaves every other line alone, and writes nothing when the block already matches. Run it after Solunized changes, then `herdr server reload-config`:

```bash
herdr/.config/herdr/scripts/sync-solunized-theme.sh
```

The script refuses a config without exactly one BEGIN before one END, and a dist table without its mode header. It becomes obsolete if herdr adds `include` or theme files. `test/herdr_config_test.rb` fails when the block drifts from `dist/herdr` and skips when there is no Solunized checkout. The script is covered by `test/herdr_sync_solunized_theme_test.rb`.
