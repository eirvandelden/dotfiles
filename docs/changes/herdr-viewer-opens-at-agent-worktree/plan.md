# Plan: the file viewer opens where the agent is working

From `intent.md` and `spec.md` (2026-09-29). Status: accepted.

This plan lives at `docs/changes/herdr-viewer-opens-at-agent-worktree/plan.md` in the worktree `/Users/etienne.vandelden/Developer/dotfiles/.worktrees/herdr-viewer-opens-at-agent-worktree` (branch `herdr-viewer-opens-at-agent-worktree`). All work happens in that worktree. `spec.md` acceptance criterion 18 (both keys run the launcher) was added after a critique showed requirement 2 had none.

## Context

An agent in a herdr pane creates a worktree with `worktree-create` and writes files there, but its pane stays in the main checkout. `prefix+f` / `prefix+shift+f` open the `herdr-file-viewer` plugin at the focused pane's folder, so the viewer shows the main checkout and the agent's new file is missing. This change makes both keys open the viewer at the worktree that agent created or reused last. When the agent has no usable worktree, the viewer opens at the pane's folder with the `W` worktree picker showing. The plugin itself is not changed in any way (not its code, not its installed copy, no upstream contribution).

Facts established by testing against real herdr on 2026-09-29 (these shape the design):
- The plugin's own pane (`herdr plugin pane open`) roots at herdr's launch context (`HERDR_PLUGIN_CONTEXT_JSON.focused_pane_cwd`, parsed in the plugin's `src/host.rs`). `--cwd` and an overriding `--env HERDR_PLUGIN_CONTEXT_JSON=…` are both ignored. `--target-pane <pane in the worktree>` works but places the viewer beside that pane, and `herdr pane move` inside one tab reports `changed: false`.
- An ordinary pane works: `herdr pane split --pane <agent pane> --direction right --cwd <worktree> --env HERDR_PLUGIN_CONFIG_DIR=<config dir> --no-focus`, then `herdr pane rename <id> Files`, then `herdr pane run <id> "exec '<plugin_root>/target/release/herdr-file-viewer'"`. The viewer roots at the worktree (no launch context → it falls back to its process folder), the pane sits beside the agent, and `q` closes the pane because of `exec`.
- `herdr pane send-keys <viewer> W` opens the worktree picker once the viewer has drawn.
- `herdr plugin list --json` gives `result.plugins[].plugin_root` for `plugin_id == "herdr-file-viewer"`. `herdr plugin config-dir herdr-file-viewer` prints its config folder.
- The plugin program answers `--launch-decision` / `--launch-decision-tab` (pane-list JSON on stdin → `OPEN`, `FOCUS <id>`, `CLOSE <id>`, `SWITCHTAB <id>`) and `--open-direction` (prints `right` or `down`). It recognises viewers by the pane label `Files`.
- herdr `[[keys.command]]` supports `type = "shell"` (runs detached in the background).

## Files that change

- `git/.config/git/worktree-tools/lib/agent_worktree.rb` (new) — `WorktreeTools::AgentWorktree`: reads and writes the record "herdr pane → worktree path". One file per pane under `${XDG_STATE_HOME:-$HOME/.local/state}/worktree-tools/agent-worktrees/`, file name = the pane id with every character outside `[A-Za-z0-9_-]` replaced by `_`, content = JSON `{"terminal_id": …, "path": …}`. The `terminal_id` comes from `herdr pane get <pane id>` (`result.pane.terminal_id`, e.g. `term_65c9d368dfedfe`, seen 2026-09-29) and ties the record to the pane's terminal, so a pane id reused after a herdr restart does not inherit an old record. `#record(pane_id, terminal_id, path)` and `#usable_for(pane_id, terminal_id, beside:)` (returns the path only when the terminal id matches, the folder exists, and `git_common_dir` of path equals that of `beside`; `git_common_dir` is in `lib/common.rb`).
- `git/.config/git/worktree-tools/worktree-create` — after `create_worktree` (covers both create and reuse, and runs whether or not `--no-pane` is given), when `ENV["HERDR_PANE_ID"]` is set and non-empty: read its `terminal_id` with `herdr pane get`, and record the path. If `herdr pane get` fails, record nothing and carry on.
- `git/.config/git/worktree-tools/worktree-viewer` (new, plain `#!/usr/bin/env ruby`, same shape as `worktree-pane`: `WorktreeTools::Viewer.run!(ARGV)`, argument `split` or `tab`). Steps:
  1. Find `plugin_root`. If it is unknown or its `scripts/open-file-viewer*.sh` are missing, exit with a warning. If the plugin program is missing, or any of its flags fails later, warn and hand over to the plugin's own script (see Risks).
  2. Read `herdr pane list` (full JSON); find the focused pane.
  3. Pipe the list to `<program> --launch-decision` (split) or `--launch-decision-tab` (tab). Anything other than `OPEN` → `exec bash <plugin_root>/scripts/open-file-viewer.sh` (or `open-file-viewer-tab.sh`). Same when the focused pane has no `agent`.
  4. Root = `AgentWorktree#usable_for(focused pane id, focused terminal_id, beside: focused cwd)` or else the focused pane's `cwd`. (`pane list` entries carry `terminal_id`.)
  5. Split: direction from `HERDR_PLUGIN_CONFIG_DIR=<config dir> <program> --open-direction`; `herdr pane split --pane <focused> --direction <dir> --cwd <root> --env HERDR_PLUGIN_CONFIG_DIR=<config dir> --focus`. Tab: `herdr tab create --cwd <root> --label Files --env HERDR_PLUGIN_CONFIG_DIR=<config dir> --focus`, then find the new tab's pane id (from the command's JSON; its shape is confirmed in step 2 of the order of work).
  6. `herdr pane rename <id> Files`; `herdr pane run <id> "exec '<program>'"`.
  7. Picker: only when no usable record was found and the root is the main checkout (`main_worktree?` in `lib/common.rb`). `herdr pane wait-output <id> --regex '┌' --source visible --timeout 5000`; on success `herdr pane send-keys <id> W`; on failure send nothing.
- `herdr/.config/herdr/config.toml` — `prefix+f` and `prefix+shift+f` become `type = "shell"` with `command = "\"$HOME/.config/git/worktree-tools/worktree-viewer\" split"` / `… tab`. Update the comment above `prefix+shift+f`.
- `herdr/.config/herdr/README.md` — "Reading a file an agent wrote": the keys now open at the agent's worktree; the picker shows when there is none; `W` and the worktree pane still work; one-time `stow -t "$HOME" git` and `herdr server reload-config` after merge.
- `test/agent_worktree_test.rb` (new), `test/worktree_viewer_test.rb` (new), `test/worktree_create_test.rb` (extended).

## Order of work

1. Write the acceptance test for criterion 5 (`test_with_a_usable_record_prefix_f_opens_a_split_beside_the_agent_rooted_in_the_worktree`) in `test/worktree_viewer_test.rb` with its stubs; run `ruby test/worktree_viewer_test.rb -n /usable_record_prefix_f/`; watch it fail because `worktree-viewer` does not exist.
2. Confirm real herdr output shapes before stubbing them: run `herdr tab create --cwd <worktree> --label Files --no-focus` and `herdr pane get "$HERDR_PANE_ID"` once, note the JSON paths for the new tab's pane id and `terminal_id`, close the test tab. Build the stub on those shapes.
3. RED/GREEN `AgentWorktree` unit tests (`test/agent_worktree_test.rb`), then the class.
4. RED/GREEN criteria 1–4 in `test/worktree_create_test.rb`, then the recording line in `worktree-create`.
5. GREEN criterion 5: minimal `worktree-viewer` split path.
6. One criterion at a time, RED then GREEN: 14, 15, 16, 6, 7, 8, 9, 10, 11, 12, 13. Refactor after each green.
7. Criterion 17: README test, then the README text. Then criterion 18: the bindings test, then the `config.toml` bindings.
8. Real herdr check, run from the worktree without stow: in a herdr pane, `ruby git/.config/git/worktree-tools/worktree-viewer split` and `… tab` with (a) a record written for the current pane, (b) no record in the main checkout, (c) a non-agent pane. Confirm root, label `Files`, placement, picker, `q` closes the pane. Close every test pane afterwards.
9. Full suite: `for f in test/*_test.rb; do ruby "$f" || break; done`; `rubocop` on every touched Ruby file; markdownlint and cspell on the README (lefthook runs them). Re-read the diff. Commit in small steps along the way (record lib, create recording, launcher, bindings, README).

## Risks

- A future plugin release moves `target/release/herdr-file-viewer`, drops `--launch-decision*` / `--open-direction`, or stops falling back to its process folder. Decided with the user: whenever the launcher cannot use the program (missing, a flag fails, or the plugin root is unknown), it prints a warning on stderr and hands over to the plugin's own `scripts/open-file-viewer.sh` / `open-file-viewer-tab.sh`, so the keys still open the viewer as today. Only when even `plugin_root` is unknown does it exit with the warning alone. Rejected alternative: patching or contributing to the plugin (ruled out by the intent).
- `type = "shell"` commands may run with a different `PATH` or without `HERDR_*` variables. The launcher uses only `herdr` on `PATH` and `herdr pane list`'s `focused` flag, never `HERDR_PANE_ID`. Checked in step 8.
- The picker keypress races the viewer's first draw; `wait-output` with a 5-second limit guards it. If it times out, the viewer stays open without the picker.
- herdr pane ids may be reused after a server restart. The record stores the pane's `terminal_id` and is ignored when it no longer matches; the same-repository check is a second guard. If herdr ever reuses terminal ids too, a stale same-repository record could still open; `W` switches.
- The new launcher file only reaches `~/.config/git/worktree-tools/` after the user runs `stow -t "$HOME" git`. Until then the new bindings fail silently. The README and the PR description say so. Agents never run stow.
- Rejected: reading an agent's own session files to find its worktree (Claude-only, undocumented format). Rejected: `herdr plugin pane open --target-pane <worktree pane>` (viewer lands beside the worktree pane, not the agent).

Out of scope: why `worktree-create` did not open a worktree pane below the caller on 2026-09-29 (separate fix); any change to the plugin; Windows launchers; recording worktrees an agent enters without `worktree-create`.

## Proof

- 1 Creating a worktree from an agent's pane records it → `test/worktree_create_test.rb` `test_inside_herdr_it_records_the_new_worktree_for_the_calling_pane`
- 2 Reuse replaces the record → `test/worktree_create_test.rb` `test_reusing_a_worktree_replaces_the_panes_record`
- 3 `--no-pane` still records → `test/worktree_create_test.rb` `test_no_pane_flag_still_records_the_worktree`
- 4 Outside herdr records nothing → `test/worktree_create_test.rb` `test_outside_herdr_nothing_is_recorded`
- 5 Split at the recorded worktree beside the agent, labelled `Files` → `test/worktree_viewer_test.rb` `test_with_a_usable_record_prefix_f_opens_a_split_beside_the_agent_rooted_in_the_worktree`
- 6 Tab at the recorded worktree, labelled `Files` → `test/worktree_viewer_test.rb` `test_with_a_usable_record_prefix_shift_f_opens_a_tab_rooted_in_the_worktree`
- 7 Removed worktree ignored → `test/worktree_viewer_test.rb` `test_a_record_for_a_removed_worktree_opens_at_the_pane_folder_with_the_picker`
- 8 Other repository ignored → `test/worktree_viewer_test.rb` `test_a_record_for_another_repository_opens_at_the_pane_folder_with_the_picker`
- 9 No record in main checkout → picker after draw → `test/worktree_viewer_test.rb` `test_an_agent_in_the_main_checkout_without_a_record_gets_the_picker_once_the_viewer_draws`
- 10 No draw within 5 s → no key → `test/worktree_viewer_test.rb` `test_when_the_viewer_does_not_draw_in_time_no_key_is_sent`
- 11 Agent pane in a worktree, no record → no picker → `test/worktree_viewer_test.rb` `test_an_agent_pane_in_a_worktree_without_a_record_opens_there_without_the_picker`
- 12 No agent → plugin's own launcher → `test/worktree_viewer_test.rb` `test_a_pane_without_an_agent_hands_over_to_the_plugins_own_launchers`
- 13 Existing viewer → plugin's own launcher → `test/worktree_viewer_test.rb` `test_an_open_viewer_in_the_tab_hands_over_to_the_plugins_own_launcher`
- 14 `open_direction = "down"` → split below → `test/worktree_viewer_test.rb` `test_the_split_follows_the_viewers_open_direction_setting`
- 15 Settings from the plugin config folder → `test/worktree_viewer_test.rb` `test_the_viewer_reads_its_settings_from_the_plugin_config_folder`
- 16 `q` closes the pane → `test/worktree_viewer_test.rb` `test_the_viewer_replaces_the_panes_shell_so_quitting_closes_the_pane` (asserts `exec`; real behaviour confirmed in order-of-work step 8)
- 17 README explains it → `test/worktree_viewer_test.rb` `test_the_readme_describes_opening_at_the_agents_worktree`
- 18 (from spec requirement 2) Both keys run the launcher → `test/worktree_viewer_test.rb` `test_prefix_f_and_prefix_shift_f_run_the_launcher`

Per changed file, the unit tests expected:
- `lib/agent_worktree.rb`: `AgentWorktree#record writes the path for the pane`, `#record replaces an earlier path`, `#usable_for returns the recorded path within the same repository`, `#usable_for refuses a missing folder`, `#usable_for refuses another repository`, `#usable_for returns nil without a record`, `#usable_for refuses a record from another terminal`, `a pane id with a colon maps to a safe file name`.
- `worktree-create`: criteria 1–4 above.
- `worktree-viewer`: criteria 5–17 above, plus `hands over to the plugin's own launcher with a warning when the viewer program is missing`, `hands over to the plugin's own launcher with a warning when --open-direction fails`, `exits with a warning when the plugin is not installed`.

Test setup: real temporary git repositories with linked worktrees (the helpers already in `test/worktree_create_test.rb`: `origin_and_clone`, `add_worktree`). A stub `herdr` on `PATH`, extended from the one in `test/worktree_create_test.rb`, that logs every call and answers `pane list` (configurable focused pane, agent, cwd, tab, existing `Files` pane), `plugin list --json` (a fake `plugin_root` in a temp dir), `plugin config-dir`, `pane split`, `tab create`, and `pane wait-output` (exit status configurable). The fake plugin root holds a stub program answering `--launch-decision*` and `--open-direction` from environment variables, and stub `scripts/open-file-viewer*.sh` that log their call. `XDG_STATE_HOME` points at a temp dir.
