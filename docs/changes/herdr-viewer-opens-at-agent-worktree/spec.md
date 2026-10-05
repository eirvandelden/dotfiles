# Spec: the file viewer opens where the agent is working

From `intent.md` (2026-09-29). Status: accepted.

## Flagged concerns

- **The viewer runs outside herdr's plugin pane.** The plugin's own pane takes its folder from herdr's launch context, and that context is always the target pane's folder: `--cwd` and an overriding `HERDR_PLUGIN_CONTEXT_JSON` are both ignored (tested 2026-09-29). Moving the viewer pane after opening it does nothing inside one tab (`herdr pane move` reported `changed: false`). So to open the viewer beside the agent at the worktree, the launcher opens an ordinary herdr pane in the worktree and runs the plugin's installed viewer program in it. The plugin is not changed, but the launcher depends on the program's path (`<plugin_root>/target/release/herdr-file-viewer`, found through `herdr plugin list --json`) and on the viewer rooting at its working folder when herdr gives it no launch context. A future plugin release could change either. Tradeoff: accepted, because the alternative is a plugin change, which the intent rules out.
- **A new file in the `git` stow package needs a restow.** `~/.config/git/worktree-tools/` holds one link per file, so the new launcher only appears there after the user runs `stow -t "$HOME" git`. Agents never run stow; the user does it once after merge.

## Requirements

1. `worktree-create` records, for the herdr pane it runs in, which worktree it created or reused. It records only inside herdr (`HERDR_PANE_ID` set), and also when `--no-pane` is given. A later call from the same pane replaces the earlier record.
2. `prefix+f` and `prefix+shift+f` run a launcher from this repository instead of the plugin's own actions.
3. When the focused pane has an agent and a usable record, the launcher opens the viewer at the recorded worktree: as a split beside the focused pane for `prefix+f`, in its own tab for `prefix+shift+f`.
4. A record is usable only when its worktree folder still exists and belongs to the same repository as the focused pane's folder. Otherwise the launcher treats the pane as having no record.
5. When the focused pane has an agent but no usable record, the launcher opens the viewer at the pane's own folder and then opens the `W` worktree picker in it.
6. When the focused pane has no agent, the launcher behaves exactly as the plugin's own actions do today.
7. When a viewer is already open in the focused tab, the launcher behaves as the plugin does today: it focuses that viewer, or closes it when it already has focus. The tab key switches to an existing viewer tab.
8. The split opens in the direction the viewer's own `open_direction` setting names, as today.
9. The viewer the launcher opens behaves like one the plugin opens: labelled `Files`, reading its settings from the plugin's config folder, and closing its pane on `q`.
10. The README's "Reading a file an agent wrote" section describes the new behaviour.

## Design decisions

- **Where the record lives:** one small file per herdr pane under `${XDG_STATE_HOME:-~/.local/state}/worktree-tools/agent-worktrees/`, named after the pane id, holding the worktree path. One file per pane means two agents never write the same file. Reading the agent's own session files is ruled out (intent).
- **Which folder counts as "the same repository":** the recorded worktree and the focused pane's folder have the same git common directory. This stops a record left over from an earlier herdr server, whose pane ids may be reused, from opening another repository's worktree.
- **Where the launcher lives:** `git/.config/git/worktree-tools/worktree-viewer`, in Ruby like `worktree-pane`. It sits next to the other tools that know about worktrees and herdr panes, and it shares the record code with `worktree-create`. herdr's config calls it with `type = "shell"`.
- **"Behaves as today" is delegated, not copied.** For a pane without an agent, and for an existing viewer in the tab, the launcher runs the plugin's own `scripts/open-file-viewer.sh` or `scripts/open-file-viewer-tab.sh` from `plugin_root`. This keeps today's behaviour exact without copying the plugin's toggle logic.
- **Opening the picker:** after the viewer has drawn its first screen, the launcher sends it the `W` key (`herdr pane send-keys <pane> W`). It waits with `herdr pane wait-output` for at most 5 seconds. If the viewer has not drawn by then, it leaves the viewer open without the picker. Tested 2026-09-29: sending `W` opens the picker.
- **An agent pane that is itself in a worktree** (a worker started by `hand-off-plan.sh`, or a pane opened by `worktree-pane`) uses its record if it has one, and otherwise its own folder. Its own folder is then already a worktree, so the picker is not shown. Rule 5 applies only when the pane's folder is the main checkout.

## Integration points

- `git/.config/git/worktree-tools/worktree-create`: writes the record.
- `git/.config/git/worktree-tools/lib/`: shared code for reading and writing the record.
- `git/.config/git/worktree-tools/worktree-viewer` (new): the launcher.
- `herdr/.config/herdr/config.toml`: `prefix+f` and `prefix+shift+f` become `type = "shell"` commands. Takes effect after `herdr server reload-config`.
- `herdr/.config/herdr/README.md`: documents the new behaviour, and that the old workarounds (`W`, focusing the worktree pane) are still available.
- herdr CLI, used as it is: `pane list`, `pane split`, `pane rename`, `pane run`, `pane wait-output`, `pane send-keys`, `tab create`, `plugin list --json`, `plugin config-dir`.
- The `herdr-file-viewer` plugin, used as it is: its installed program, its launcher scripts, `--open-direction`.
- Tests: `test/worktree_create_test.rb` (extended) and `test/worktree_viewer_test.rb` (new), both with a stub `herdr` on `PATH`, as the existing worktree tests do.

## Acceptance criteria

1. Creating a worktree from an agent's herdr pane records that worktree for that pane.
2. Reusing an existing worktree from the same pane replaces the pane's record with the reused worktree.
3. Creating a worktree with `--no-pane` still records it.
4. Creating a worktree outside herdr records nothing.
5. With a usable record, `prefix+f` in the agent's pane opens a split beside that pane, rooted in the recorded worktree, labelled `Files`.
6. With a usable record, `prefix+shift+f` opens a new tab rooted in the recorded worktree, with its viewer pane labelled `Files`.
7. A record whose worktree folder has been removed is ignored: the viewer opens at the pane's folder with the worktree picker showing.
8. A record pointing at a worktree of another repository is ignored in the same way.
9. With an agent in a main-checkout pane and no record, the viewer opens at the pane's folder and the worktree picker appears once the viewer has drawn.
10. When the viewer does not draw within 5 seconds, the launcher stops waiting, sends no key, and leaves the viewer open.
11. An agent pane in a worktree with no record opens the viewer at its own folder without the picker.
12. In a pane without an agent, `prefix+f` runs the plugin's own split launcher and `prefix+shift+f` its own tab launcher.
13. With a viewer already open in the focused tab, both keys hand over to the plugin's own launcher, which focuses or closes that viewer as today.
14. With `open_direction = "down"` in the viewer's settings, the split opens below the agent's pane.
15. The launcher's viewer reads its settings from the folder `herdr plugin config-dir herdr-file-viewer` prints.
16. Pressing `q` in the launcher's viewer closes its pane.
17. The README explains that the viewer opens at the agent's worktree, and what happens when there is none.
18. `prefix+f` and `prefix+shift+f` run the launcher, not the plugin's own actions.

---
Domain skills applied: dotfiles-maintenance.
