# Plan: herdr-app phase 3, keys

From `intent.md` (2026-11-10, phase 3 updated 2026-11-11). Status: accepted.

Scope: phase 3 only — the `;` leader key map in `keys.json`, the done and blocked agent lists, Linux-safe bindings, and two runbook fixes. Phases 4 (look) and 5 (pipeline) are out of scope.

## Design

### Domain terms

- **herdr-app**, **Space**, **Machine**, **Core**, **Running agent**: as `GLOSSARY.md` defines them. "Workspace" means the herdr TUI and is not used for herdr-app.
- **Leader** (new): the `;` key that starts every herdr-app shortcut sequence of this phase, such as `; t`.
- **Agent list** (new): a herdr-app popup that lists the running agents of one status and shows the one picked. `agents-done` (`; d`) lists done agents, `agents-blocked` (`; b`) blocked ones.
- `picker` appears only as the code name of herdr-app's shipped mod, in backticks. The glossary's **Switcher** avoids "picker" for the Rex panel; this plan never uses it as a concept.

### Diagrams

```mermaid
classDiagram
  class KeysJson {
    global: leader sequences
    terminal: "; space" types "; ", copy and paste
  }
  class AgentsDoneModJson {
    overlay.props.status = done
  }
  class AgentsBlockedModJson {
    overlay.props.status = blocked
  }
  class AgentList {
    init(props, cx)
    rows() AgentInfo[]
    go(row)
    close()
    render()
  }
  class HerdrModule {
    agents() AgentInfo[]
    props() object
    run(name, args)
    closeOverlay(id)
  }
  KeysJson --> AgentsDoneModJson : "; d" mod.open:agents-done
  KeysJson --> AgentsBlockedModJson : "; b" mod.open:agents-blocked
  AgentsDoneModJson --> AgentList : loads agents-done/main.js
  AgentsBlockedModJson --> AgentList : main.js is a symlink to the same file
  AgentList --> HerdrModule : reads agents and props, runs agent.focus
```

```mermaid
sequenceDiagram
  participant E as Etienne
  participant K as keys.json
  participant W as herdr-app window
  participant L as AgentList
  E ->> K : ; b
  K ->> W : mod.open name=agents-blocked
  W ->> W : mod_overlay reads mod.json "overlay" (props.status=blocked)
  W ->> L : open popup, props {status, title, overlay}
  L ->> W : agents(), keep status == props().status
  E ->> L : down, Enter
  L ->> W : closeOverlay(props().overlay)
  L ->> W : run agent.focus {terminal: address}
```

### Signatures

`AgentList` — the default export of `mods/agents-done/main.js`, cloned from herdr-app's shipped `picker` mod and cut down to one flat list of agents of one status. JavaScript, so the types are JSDoc against Herdr's generated `herdr.d.ts`:

```js
/** @param {object} _props @param {Context} cx @returns {void} */ init(_props, cx)  // selection, this.handle = cx.focus_handle(), focused at once and again after 600 ms
/** @returns {AgentInfo[]} */                                     rows()            // agents().filter(a => a.status === props().status), Herdr's order
/** @param {AgentInfo|undefined} row @returns {void} */           go(row)           // no row: return; else closeOverlay(props().overlay), then run("agent.focus", {terminal: row.address})
/** @returns {void} */                                            close()           // closeOverlay(props().overlay)
/** @returns {Element} */                                         render()          // title from props().title, rows, empty line; on_key_down: enter → go(rows[this.at]), up/down wrap, escape → close
```

The shipped picker gets Enter and focus from its filter input. With the input removed, the list tracks `this.handle` and handles `enter` itself in `on_key_down`. Up and down do nothing on an empty list, because the picker's `(this.at + 1) % length` gives NaN at 0 rows, and an empty blocked list is the normal case.

Ruby tests use inline `#:` signatures.

Not checked: the dotfiles repository declined Steep; the JavaScript has no type checker here, `herdr-app check <mod folder>` loads the mods and `keys.error` reports `keys.json` problems instead.

### Complexity

- `rows()`: one `agents()` host read and one O(A) filter per render, A = number of agents. No `hc` subprocess, no shared state, no sort.
- `go()`: two host calls.
- `keys.json`: about 70 leader bindings, loaded once per change; no runtime cost per key beyond GPUI's keymap match.

### Invariants

1. `agents-blocked/main.js` is a relative symlink to `../agents-done/main.js`, so one file holds the agent list code — `test/herdr_app_package_test.rb`.
2. Each agent list's `mod.json` names its status in `overlay.props.status` (`done`, `blocked`) — `test/herdr_app_package_test.rb`.
3. The agent list code imports no relative path (`./` or `../`) and names no `mods/agents-` path: herdr-app's loader refuses a relative import that resolves outside the mod folder, and every file in a stowed mod resolves into the repository — `test/herdr_app_package_test.rb`.
4. An agent list shows only agents whose status equals `props().status`; a missing status shows one line naming the missing `mod.json` key, never every agent — the filter and guard in `rows()`; proof is a manual check in the sandbox window.
5. Every row of the intent's key map is bound in `keys.json` to its action — `test/herdr_app_keys_test.rb`.
6. In a terminal, `; space` types `; ` and `; ;` types `;` — `keys.json` `terminal` and `global` sections; `test/herdr_app_keys_test.rb` plus the sandbox check.
7. herdr-app's own `cmd-…` defaults stay — `test/herdr_app_keys_test.rb`.

### Alternatives

1. Chosen: one `main.js` shared through a relative git symlink, the status passed by each folder's `mod.json` `"overlay": {"props": {...}}`. Verified in the herdr-app source: `mod.open` builds the overlay from `mod.json`'s `"overlay"` object (`src/window.rs` `mod_overlay`, `open_overlay` passes `props`), and `props()` returns it. The entry `main.js` is read through links, as `spaces-cores/main.js` already is.
2. Rejected: two independent clones, byte-identical except for a constants block, kept in step by a drift test. Simpler mechanics, but every fix lands twice.
3. Rejected: one folder with a relative import, or one mod switched by `<mod>.<command>`. herdr-app's QuickJS loader refuses a relative import that canonicalises outside the mod folder, which every stowed file does; `<mod>.<command>` reaches only a mod that is already shown, and `mod.open` takes only a name.

## Design decisions

- The leader sequences live in the `global` section once. GPUI's `global` context applies inside terminals too; the `terminal` section only overrides `; space` (types `; `). The intent says "in both the `global` and `terminal` sections"; the behaviour is the same. Step 1 checks it in a sandbox window; if a `global` sequence does not fire in a terminal, the implementer copies the leader sequences into `terminal` as well.
- `; ;` is `send:;` in `global`: it types `;` into the focused terminal.
- `; x` and `; w` both bind `pane.close`. herdr-app's `pane.close` already closes the tab when the pane is its last one (`src/window.rs`, `"pane.close"`), which is exactly `; w`'s rule; `; x` keeps the TUI's habit.
- `; shift-b` toggles the sidebar and `; b` opens the blocked list — Etienne's decision of 2026-11-11.
- Shifted keys get both spellings where Linux needs them: `; shift-1`…`; shift-9` and `; !`…`; (`, and `; ?` plus `; shift-/`. macOS matches both spellings to one keypress; herdr-app's own Linux defaults bind both (`ctrl-?`, `ctrl-shift-/`).
- Linux: no herdr-app action may need the Super key. The leader covers the key map. For the bound actions outside the map, `keys.json` adds herdr-app's own Linux defaults: `global` gets `ctrl-=`, `ctrl-+` and `ctrl--` (zoom in and out), `ctrl-0` (zoom reset), `ctrl-shift-l` (`layout.switch`) and `ctrl-shift-k` (`mod.open:picker`, the picker from inside a terminal, where `; space` types `; ` and `cmd-p` is Super). `terminal` gets `ctrl-shift-c` (copy) and `ctrl-shift-v` (paste). On macOS these keys stop reaching terminal programs; none of them is on herdr-app's list of keys programs rely on.
- `; f` runs `layout.toggle:panel`. `Layout::select` (`src/layout.rs`) only sets a stack's active child and never shows a hidden column, and the `cores` layout's `panel` column starts hidden with `files` as the active child of `panel-body`.
- Pre-merge checks run in a sandbox window, not in Etienne's running window as the intent's phase 3 says ("verify in the running app"). Reasons: his window reads the main checkout, so the worktree's files are not live there before merge; and keystrokes sent into his window could reach his shells or live agents. The behaviour checked is the same. After merge and restow, Etienne walks the map in his own window.
- In herdr-app's text inputs (picker filter, rename fields, settings), `;` followed by a bound key fires that binding, and `; ;` types nothing, because `send:` acts only in terminals (`src/window.rs`, `run_action`). Typing a `;` then a space in a tab name opens the picker. This follows from "leader everywhere" (intent `## Decisions`) and is recorded in the runbook. The sandbox probes it with the full `keys.json`.
- `; shift-f` runs `{"command":"tab.new","args":{"mod":"files","name":"Files"}}`; `; g` runs `{"command":"pane.split","args":{"direction":"right","argv":["lazygit"]}}`; `; shift-g` runs `{"command":"tab.new","args":{"name":"lazygit","argv":["lazygit"]}}`.
- The agent list drops the shipped picker's filter input, space colours, "earlier", "new tab" and "new space" rows, `hc machine ls`, fixed-strip scrolling and `ctrl+d`. A list of one status is short; arrows, Enter and Esc are enough.
- The plan's critique is a Claude critique, not Codex — Etienne's decision of 2026-11-11, recorded in `intent.md`.
- Conflicts with `intent.md`: the sandbox replaces the running window for pre-merge checks (above, with the reason). Nothing else in `## Decisions` conflicts.

## Integration points

- herdr-app reads `~/.config/herdr-app/keys.json` and `~/.config/herdr-app/mods/*` live; both are stow links into the main checkout of the dotfiles repository (`STOW_SHARED`, `--no-folding`).
- `stow` must link the two new mod folders' files; the delivery step restows `herdr-app` with `-t "$HOME"` (approved in the intent).
- herdr-app commands used: `tab.new`, `tab.select`, `tab.next`, `tab.prev`, `tab.close`, `tab.rename`, `space.select`, `space.next`, `space.prev`, `space.new`, `space.rename`, `space.close`, `agent.next`, `agent.prev`, `agent.focus`, `pane.go`, `pane.swap`, `pane.split`, `pane.close`, `pane.zoom`, `layout.toggle`, `layout.switch`, `mod.open`, `terminal.search`, `terminal.copy`, `terminal.paste`, `app.palette`, `app.help`, `app.settings`, `app.zoom_in`, `app.zoom_out`, `app.zoom_reset`.
- herdr-app reports a bad `keys.json` in `$HERDR_APP_HOME/keys.error` and in `herdr-app status`; one bad binding makes the whole file fail to load, and the window then has no bindings at all. `herdr-app check` checks a mod folder, not `keys.json`.
- The runbook `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md`.

## Files that change

- `herdr-app/.config/herdr-app/keys.json` — the leader map and the Linux `ctrl-…` defaults in `global`; `; space`, `ctrl-shift-c` and `ctrl-shift-v` in `terminal`. Existing bindings stay.
- `herdr-app/.config/herdr-app/mods/agents-done/main.js` — new: the agent list, cloned from `picker` with `herdr-app do mod.clone '{"name":"picker","as":"agents-done"}'` in the sandbox, then cut down.
- `herdr-app/.config/herdr-app/mods/agents-done/mod.json` — new: the picker's popup overlay with `"props": {"status": "done", "title": "Done agents"}`, title "Done agents", and the `cloned_from` that `mod.clone` writes.
- `herdr-app/.config/herdr-app/mods/agents-blocked/main.js` — new: relative symlink to `../agents-done/main.js`.
- `herdr-app/.config/herdr-app/mods/agents-blocked/mod.json` — new: same overlay with `"status": "blocked"`, title "Blocked agents".
- `test/herdr_app_keys_test.rb` — new: the key map table as data; asserts each row is bound, the terminal overrides, that every bound action is reachable without `cmd` from a terminal, that each object binding's `command` and `args` names match herdr-app's command table (a snapshot of `herdr-app commands` names and argument names, kept in the test), and that the `cmd-…` defaults stay.
- `test/herdr_app_package_test.rb` — the tracked file list grows by the four mod files; tests for the symlink, the status props, no relative imports and the generated files being ignored in the new folders.
- `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md` — `layout.switch --name cores`; start, restart or stop a core only from a plain terminal, never from an agent shell or a `!` command, because the core's holder copies that shell's `CLAUDE_*` variables into every terminal; plus one paragraph on the leader and the agent lists.
- `GLOSSARY.md` — the terms Leader and Agent list.

## Order of work

1. Sandbox setup. Copy the worktree's `herdr-app/.config/herdr-app/` (resolving links) to a scratch home and start a second window with `HERDR_APP_HOME=<scratch home> HC_SESSION=hac3` (a short name: the socket path limit is 103 bytes). Note the sandbox app's own pid. Keystroke safety: Etienne's window is also a process named "Herdr". Before each batch of `osascript` keystrokes, bring the sandbox to the front by its unix id (`first process whose unix id is <pid>`), read back the frontmost process's unix id, and abort the batch on a mismatch. If Accessibility permission is missing or the check fails, stop and ask Etienne to type the checks in the sandbox window instead.
2. Write `test/herdr_app_keys_test.rb` from the intent's key map (with the decisions above). Run it; watch it fail on the missing bindings.
3. Edit `keys.json`. Run the test until green. Copy it into the sandbox home; require that `<scratch home>/keys.error` does not exist and that `HERDR_APP_HOME=<scratch home> /Applications/Herdr.app/Contents/MacOS/Herdr status` names no keys error.
4. Sandbox key checks with the full `keys.json`, results read with `HERDR_APP_HOME=<scratch home> /Applications/Herdr.app/Contents/MacOS/Herdr ls` and `HC_SESSION=hac3 hc read <t>`: `; t` from a terminal and from the sidebar adds a tab; `echo a; echo b` typed into a shell runs unchanged; `; ;` types one `;`; `; space` in a shell types `; ` and from the sidebar opens the picker; `; w` in a two-pane tab closes one pane, then the tab; `; f` shows the Files panel; `a;b` typed into a rename field opens the blocked list (the recorded text-input effect). If a `global` sequence does not fire in a terminal, copy the leader sequences into `terminal` too. Record each result for the delivery account.
5. Add the package tests for the agent lists to `test/herdr_app_package_test.rb`; watch them fail.
6. In the sandbox, `mod.clone` `picker` as `agents-done`; copy its `main.js` and `mod.json` into the package; cut `main.js` down to `AgentList`; write both `mod.json` files; add the `agents-blocked/main.js` symlink (`ln -s ../agents-done/main.js`). Run the package tests until green. Copy the folders into the sandbox home and run `HERDR_APP_HOME=<scratch home> /Applications/Herdr.app/Contents/MacOS/Herdr check <mod folder>` for both.
7. Sandbox check of the agent lists. "done" turns into "idle" once the agent is looked at, so the reports come from terminals in tabs that are not shown: create three terminals in two background tabs and make them report the agent status herdr-app reads (the OSC 7501 report; find the exact sequence in the herdr-app source), two done and one blocked. From a third tab, `; d` lists two, `; b` lists one; Enter shows the picked agent, which then leaves the done list; Esc closes; an empty list shows its empty line and arrows do nothing.
8. Stop the sandbox: its app by its own pid (never `app.quit`, which closes Etienne's window too), then `HC_SESSION=hac3 hc server stop`, then kill the `hac3` holder after checking that its arguments name `hac3`. Never touch another session's core or holder.
9. Runbook and glossary edits.
10. `bin/test`, `rubocop`, `markdownlint`, `shellcheck` where touched; re-read the diff.
11. After Etienne's `/finish` merges the PR, the coordinator (this delivery's session): fast-forward the main checkout to `origin/main`, which makes the new `keys.json` live, then restow at once (`stow -R --no-folding -t "$HOME" herdr-app`, approved in the intent) so the four mod files link. Check `~/.config/herdr-app/keys.error` is absent and `herdr-app status` names no keys error, then ask Etienne to walk the key map in his window.

## Risks

- Live testing: the stow links point into the main checkout, so the worktree's files are not live in Etienne's window until merge and restow. All pre-merge checks run in a sandbox window with its own `HERDR_APP_HOME` and `HC_SESSION`. A sandbox `app.quit` closes every window: stop it by pid.
- A sandbox core started from an agent shell leaks the agent's variables into its terminals. Harmless in the sandbox; never restart Etienne's cores.
- Text inputs: `;` followed by a bound key fires the binding there (see Design decisions). If the sandbox shows worse, such as `;` lost before an unbound key, report it as a `Decision needed:` instead of guessing.
- One bad binding makes herdr-app drop the whole `keys.json`, leaving Etienne's window with no shortcuts. The sandbox `keys.error` check before merge and the same check after the restow guard this.
- Dvorak: GPUI matches the produced character, so `;`, `[`, `]`, `-`, `/` and `,` follow Etienne's layout. The sandbox check runs on this Mac with that layout.
- Linux (Steam Deck): no Deck is available to the agent. The Linux spellings follow herdr-app's own Linux defaults; the Steam Deck criterion is a manual check by Etienne after delivery.
- `keys.json` stops receiving new herdr-app defaults once edited (already true since phase 1).
- The `agents-blocked/main.js` symlink: stow `--no-folding` links the package symlink itself, and the chain resolves inside the repository. `git` stores it as a symlink; Windows is not a target.
- herdr-app upgrades may change the mod API (`agents()`, `props()`, `run`, `closeOverlay`, `View`); the clone gets no updates. `herdr-app check` after an upgrade shows breakage.

Rejected: porting the TUI plugins beyond the key map; a type-to-filter box in the agent lists; per-OS `keys.json` files (herdr-app reads one file).

## Proof

- `; t` opens a new tab, from a terminal and from the sidebar → `test/herdr_app_keys_test.rb` `test_the_leader_map_binds_every_row` + check: sandbox step 4 (`; t` from a terminal and with the sidebar focused adds a tab in `herdr-app ls`).
- `; w` in a tab with two panes closes the focused pane; with one pane it closes the tab → `test/herdr_app_keys_test.rb` `test_the_leader_map_binds_every_row` + check: sandbox step 4, `; w` in a two-pane tab then again in the one-pane tab, `herdr-app ls` after each.
- `; space` from the sidebar opens the picker; `; space` in a shell types `; ` → `test/herdr_app_keys_test.rb` `test_space_in_a_terminal_types_semicolon_space` + check: sandbox step 4.
- With two done agents and one blocked agent, `; d` lists only the two done, `; b` only the blocked one; Enter shows that agent → `test/herdr_app_package_test.rb` `test_each_agent_list_names_its_status` + check: sandbox step 7.
- In a shell, `; ;` types one `;`, and `echo a; echo b` runs unchanged → `test/herdr_app_keys_test.rb` `test_semicolon_twice_types_one_semicolon` + check: sandbox step 4 (`hc read` shows `a` and `b`).
- Every row of the key map does what it says → `test/herdr_app_keys_test.rb` `test_the_leader_map_binds_every_row` + check: Etienne walks the map in his window after restow, recorded in the delivery account.
- On the Steam Deck, the `;` leader keys work, and no herdr-app action needs the Super key → `test/herdr_app_keys_test.rb` `test_every_action_is_reachable_without_cmd` and `test_terminal_copy_and_paste_work_without_super` + check: Etienne on the Steam Deck after delivery.
- The runbook says `layout.switch --name cores` and to start cores only from a plain terminal → check: `grep -n 'layout.switch --name cores' agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md` and `grep -n 'plain terminal'` on the same file.
- Invariant: one file holds the agent list code, enforced by the symlink → `test/herdr_app_package_test.rb` `test_the_blocked_list_shares_the_done_list_code`.
- Invariant: the agent list code imports no relative path and names no `mods/agents-` path → `test/herdr_app_package_test.rb` `test_the_agent_list_imports_only_builtin_modules`.
- Invariant: herdr-app's `cmd-…` defaults stay → `test/herdr_app_keys_test.rb` `test_the_cmd_defaults_stay`.
- Departures of the test commit `1ea687f1` from this plan:
  - `test_every_action_is_reachable_without_cmd` skips a `send:` of exactly one C0 control byte (cmd-left, cmd-right, cmd-backspace), besides `app.quit`, `app.hide` and `app.hide_others`.
  - `test_object_bindings_name_real_commands_and_arguments` refuses an empty object list.
  - A `<mod>.<command>` string passes only for a mod that herdr-app 0.1.15 ships or a mod folder in the package.
  - The Linux global defaults are checked at the top of `test_every_action_is_reachable_without_cmd`.
  - `test/secrets_loader_test.rb` hangs when the 1Password agent is down. That is a known separate issue, out of scope.

Per changed file, the unit tests expected:

- `test/herdr_app_keys_test.rb`: `test_the_leader_map_binds_every_row`, `test_every_action_is_reachable_without_cmd`, `test_object_bindings_name_real_commands_and_arguments`, `test_semicolon_twice_types_one_semicolon`, `test_space_in_a_terminal_types_semicolon_space`, `test_terminal_copy_and_paste_work_without_super`, `test_shifted_keys_have_both_spellings`, `test_the_cmd_defaults_stay`.
- `test/herdr_app_package_test.rb`: `test_the_package_holds_only_etiennes_files` (updated list), `test_the_blocked_list_shares_the_done_list_code`, `test_each_agent_list_names_its_status`, `test_the_agent_list_imports_only_builtin_modules`, `test_the_agent_lists_are_clones_of_the_picker`, `test_the_generated_mod_files_are_ignored` (extended to the new folders).

Test setup: the tests read the tracked JSON and JS files; no herdr-app process. The key map is a frozen hash in `test/herdr_app_keys_test.rb`, written from the intent's table. Sandbox checks use a scratch `HERDR_APP_HOME` and `HC_SESSION=hac3`, both removed after.

---
Domain skills applied: software-design, glossary, diagrams, dotfiles-maintenance.

## Critique

### Round 1 (claude -p, opus)

- Step 1's `osascript` keystrokes could reach Etienne's own Herdr window, also named "Herdr" → fixed (step 1 targets the sandbox by unix id, checks the frontmost pid before each batch, aborts on a mismatch, falls back to Etienne typing)
- `herdr-app check` checks a mod folder, not `keys.json`; one bad binding drops every binding → fixed (steps 3 and 11 require no `keys.error` and a clean `herdr-app status`; the keys test checks object bindings' command and argument names against a snapshot of herdr-app's command table; a risk line added)
- Zoom, `layout.switch` and the picker from inside a terminal still needed Super on Linux → fixed (herdr-app's Linux `ctrl-…` defaults for zoom, `layout.switch` and `mod.open:picker` added; the test checks every action is reachable without `cmd` from a terminal)
- `layout.select` cannot show the hidden Files panel → fixed (`; f` binds `layout.toggle:panel`; the probe and fallback are gone)
- The agent list loses Enter and focus without the filter input, and arrows give NaN on an empty list → fixed (Signatures: focus handle with delayed refocus, Enter in `on_key_down`, arrows idle on an empty list)
- Step 6 could not produce done agents, because "done" turns "idle" once looked at → fixed (step 7 reports from background tabs and opens the lists from a third tab)
- The `a;b` probe tested an unbound key, and `; ;` types nothing in text inputs → fixed (recorded as a consequence of "leader everywhere" in Design decisions and the runbook; step 4 probes with the full map; worse results become a `Decision needed:`)
- The sandbox-only verification differs from the intent without a record → fixed (Design decisions records it with the reason; the conflicts line names it)
- Step 9 skipped the main checkout pull, named no actor, and `hc server stop` may leave the sandbox holder → fixed (step 11: the coordinator fast-forwards, restows at once and checks `keys.error`; step 8 kills the `hac3` holder after checking its arguments)
