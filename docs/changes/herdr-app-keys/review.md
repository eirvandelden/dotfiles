# Review: herdr-app-keys

## Round 1 — 2026-11-11 13:22 UTC — 29a0ec0a

Compliance (intent phase 3 acceptance criteria):

- `; t` new tab, terminal and sidebar → `test_the_leader_map_binds_every_row`; keystroke check pending with Etienne (plan step 4).
- `; w` closes pane, then tab → `test_the_leader_map_binds_every_row`; keystroke check pending (step 4).
- `; space` picker from sidebar, `; ` in a shell → `test_space_in_a_terminal_types_semicolon_space`; keystroke check pending (step 4).
- `; d` two done, `; b` one blocked, Enter shows the agent → `test_each_agent_list_names_its_status`; list contents pending (step 7).
- `; ;` types one `;`, `echo a; echo b` unchanged → `test_semicolon_twice_types_one_semicolon` with `test_space_in_a_terminal_types_semicolon_space`; keystroke check pending (step 4).
- Every row of the key map → `test_the_leader_map_binds_every_row`.
- Steam Deck, no Super key → `test_every_action_is_reachable_without_cmd`, `test_terminal_copy_and_paste_work_without_super`; Deck check pending with Etienne.
- Runbook `layout.switch --name cores` and plain terminal → present in `herdr-app-cores.md:11` and `:32`.
- All 14 tests named in `## Proof` exist. No existing test was weakened, skipped or deleted (`test_the_generated_mod_files_are_ignored` was extended).

Checks: `herdr_app_keys_test.rb` 8 runs, `herdr_app_package_test.rb` 18 runs, 0 failures; rubocop clean on both; no-hardwrap markdownlint clean; `node --check` on `main.js` clean. No N+1 loop (`rows()` reads `agents()` once per render). No Law of Demeter finding beyond host-API calls (`cx.timer.after`) that the shipped mods use the same way.

- [ ] Important: `AgentList`'s five methods (`init`, `close`, `rows`, `go`, `render`) carry none of the JSDoc types that `### Signatures` signed ("the types are JSDoc against Herdr's generated `herdr.d.ts`"), and plan.md records no departure — `herdr-app/.config/herdr-app/mods/agents-done/main.js:10` → fixed (Type the agent list methods with JSDoc)
- [ ] Nit: the runbook uses the glossary Avoid word "picker" as a concept ("`; space` for the picker"), outside backticks; the plan allows `picker` only as the backticked mod name — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md:36` → fixed (Say which keys the herdr-app leader adds and how it fires in a terminal)
- [ ] Nit: the runbook says `keys.json` "binds every shortcut of herdr-app to the `;` leader", but the `cmd-…` and `ctrl-…` bindings stay — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md:36` → fixed (Say which keys the herdr-app leader adds and how it fires in a terminal)
- [ ] Nit: the runbook documents the leader's effect in text inputs only; in a terminal a `;` followed by a bound key also fires it (`ls;pwd` runs `tab.prev` at `; p`), and a typed `;;` (a shell `case` arm, `for(;;)`) arrives as one `;` — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md:36` → fixed (Say which keys the herdr-app leader adds and how it fires in a terminal)
- [ ] Nit: the test name uses the glossary Avoid word "picker" outside backticks — `test/herdr_app_package_test.rb:92` → fixed (Name the agent list clone test without the word picker)
- [ ] Nit: plan.md records only the test-commit departures; the implementation departures (`mod.clone` skipped, `mod.json` and `cloned_from` written by hand, rows showing tab, space and app) live only in the implementer's report — `docs/changes/herdr-app-keys/plan.md:183` → fixed (docs: record the herdr-app-keys implementation departures in the plan)

## Round 2 — 2026-11-11 13:41 UTC — c65e575e

Round 1 fixes: the JSDoc on `AgentList` (`main.js:10`–`49`) matches `### Signatures` and Herdr's `herdr.d.ts` (`AgentInfo`, `Context`, `Element`). The runbook names `picker` only as the backticked mod and documents the leader in a terminal. The clone test is `test_the_agent_lists_are_clones_of_a_shipped_mod`. plan.md lists the implementation departures. The "every shortcut" claim is only partly fixed: see the second finding below.

Compliance: the same as round 1. Each phase 3 criterion maps to its test. The keystroke checks (plan step 4), the agent list contents (step 7) and the Steam Deck check stay with Etienne after merge and restow. All 14 tests named in `## Proof` exist. No existing test was weakened, skipped or deleted.

Checks: `bin/test` on 111 files (without `secrets_loader_test.rb` and `herdr_worker_scripts_test.rb`): 0 failed. `herdr_app_keys_test.rb` had 8 runs and `herdr_app_package_test.rb` 18 runs, with 0 failures. rubocop on both test files: clean. no-hardwrap markdownlint on the runbook, glossary, intent and plan: clean. `node --check` on `main.js`: clean. Design: every public `AgentList` method is signed. No N+1 loop and no Law of Demeter finding. No Avoid word outside code names.

- [ ] Important: Etienne's Neovim leader is also `;` (`neovim/.config/nvim/lua/config/options.lua:50`). The `;` leader fires inside terminals, so in Neovim in a herdr-app terminal herdr-app takes `;a`, `;b`/`;bd`, `;d`/`;db`/`;dc`/`;di`/`;do`/`;du`, `;f`/`;ff`/`;fb`/`;fr`, `;g`/`;gb`/`;gl`/`;go`/`;gp`, `;p` and `;t`/`;tt`/`;tf`/`;to`/`;tr`/`;ts`. They run `agent.next`, the blocked list, the done list, the Files panel, a lazygit split, `tab.prev` and a new tab, and Neovim never gets them. The herdr TUI's `ctrl+s` prefix never clashed. The intent, the plan and the runbook do not record this; Etienne must decide what happens — `herdr-app/.config/herdr-app/keys.json:60` → fixed (Move the Neovim leader to space, off herdr-app's ; leader)
- [ ] Nit: the runbook still says `keys.json` "adds a `;` leader sequence for every herdr-app shortcut". `layout.switch`, the three zoom actions, `terminal.copy`, `terminal.paste` and `terminal.paste_image` have no leader sequence — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md:36` → fixed (Name the herdr-app keys without a leader and the Linux ctrl keys)
- [ ] Nit: the runbook does not name the new Linux keys: `ctrl-shift-c` and `ctrl-shift-v` (copy, paste), `ctrl-shift-k` (the `picker` mod from a terminal), `ctrl-shift-l` and the `ctrl-…` zoom keys. It also does not say that on macOS `ctrl--`, `ctrl-=`, `ctrl-+` and `ctrl-0` no longer reach terminal programs. `ctrl--` sends `^_`, which is undo in zsh and readline — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md:36` → fixed (Name the herdr-app keys without a leader and the Linux ctrl keys)

## Round 3 — 2026-11-11 13:43 UTC — b18774bb

Round 2 fixes: the runbook paragraph (`herdr-app-cores.md:36`) now says "most herdr-app shortcuts". Checked against `keys.json`, the actions without a leader sequence are `app.quit`, `app.hide`, `app.hide_others`, `layout.switch`, the three `app.zoom_*` actions, `terminal.copy`, `terminal.paste` and `terminal.paste_image`. The runbook names all of them. It names the Linux keys `ctrl-shift-c`, `ctrl-shift-v` (terminal section), `ctrl-shift-k`, `ctrl-shift-l` and the `ctrl-…` zoom keys, and the `ctrl--` `^_` loss on macOS, correctly. The Neovim `;` leader clash from round 2 stays open, waiting on Etienne's decision.

Compliance: the same as round 2. Each phase 3 criterion maps to its test. The keystroke checks (plan step 4), the agent list contents (step 7) and the Steam Deck check stay with Etienne after merge and restow. All 14 tests named in `## Proof` exist. No existing test was weakened, skipped or deleted.

Checks: `herdr_app_keys_test.rb` 8 runs, 174 assertions; `herdr_app_package_test.rb` 18 runs, 57 assertions; 0 failures. no-hardwrap markdownlint on the runbook, glossary, intent, plan and review: clean. Only the runbook changed since round 2. Design: every public `AgentList` method is signed. No N+1 loop, no Law of Demeter finding, no Avoid word outside code names (`picker`, `app.palette`).

- [ ] Nit: "Quit, hide, `layout.switch`, zoom, copy and paste have no leader sequence" reads as if pane zoom has none, but `; z` binds `pane.zoom`; only the app zoom actions (`app.zoom_in`, `app.zoom_out`, `app.zoom_reset`) lack one — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md:36` → fixed (Tell window zoom from pane zoom in the herdr-app leader runbook)

## Round 4 — 2026-11-11 13:45 UTC — 895c5758

Round 3 fix: the runbook paragraph (`herdr-app-cores.md:36`) now names the window zoom (`app.zoom_in`, `app.zoom_out`, `app.zoom_reset`) as without a leader sequence and says pane zoom is `; z`. This matches `keys.json`, which binds `; z` to `pane.zoom` and no `;` sequence to an `app.zoom_*` action. The Neovim `;` leader clash from round 2 stays open, waiting on Etienne's decision.

Compliance: the same as round 3. Each phase 3 criterion maps to its test. The keystroke checks (plan step 4), the agent list contents (step 7) and the Steam Deck check stay with Etienne after merge and restow. All 14 tests named in `## Proof` exist. No existing test was weakened, skipped or deleted.

Checks: `herdr_app_keys_test.rb` 8 runs, 174 assertions; `herdr_app_package_test.rb` 18 runs, 57 assertions; 0 failures. no-hardwrap markdownlint on the runbook, glossary, intent, plan and review: clean. Only the runbook changed since round 3. Design: every public `AgentList` method is signed. No N+1 loop, no Law of Demeter finding, no Avoid word outside code names (`picker`, `app.palette`).

Nothing new found.

## Round 5 — 2026-11-11 19:41 UTC — 08fa3fe8

Since round 4: Etienne's decision (intent `## Decisions`, 2026-11-11) keeps herdr-app's `;` leader, moves Neovim's leader to space and adds `ctrl-alt-cmd-…` chords. `options.lua:50`–`51` sets `mapleader` and `maplocalleader` to `" "`, before `config.lazy` loads (`init.lua`). The 14 chords in `keys.json` match the intent's chord table and their leader twins, and `test_the_chords_repeat_their_leader_twins` proves it. The runbook (`herdr-app-cores.md:38`) and plan.md (Proof, departures) record the decision. No other Neovim file sets a leader or a literal `;` mapping; every map uses `<leader>`, and `<leader><space>` (snacks) becomes `<space><space>`. No duplicate key in either `keys.json` section.

Compliance: the same as round 4, plus the chord Proof line → `test_the_chords_repeat_their_leader_twins`. The keystroke checks (plan step 4), the agent list contents (step 7), pressing the chords and the Steam Deck `ctrl+alt+meta` check stay with Etienne. All 15 tests named in `## Proof` and the per-file list exist. No existing test was weakened, skipped or deleted.

Checks: `herdr_app_keys_test.rb` 9 runs, 189 assertions; `herdr_app_package_test.rb` 18 runs, 57 assertions; `editor_test.rb` 17 runs and `neovim_avante_dependencies_test.rb` 2 runs (the Neovim tests; neither reads the leader); 0 failures. rubocop on both herdr-app test files: clean. stylua `--check` on `options.lua`: clean. no-hardwrap markdownlint on the runbook, glossary, intent, plan and review: clean. `node --check` on `main.js`: clean. Design: no new public method, no N+1 loop, no Law of Demeter finding, no Avoid word outside code names.

- [ ] Important: with the leader off `;`, Neovim's own `;` (repeat the last `f`/`t` motion) works again, but herdr-app's `;` leader takes it plus the next bound key in a terminal. In Neovim normal mode, `;x` and `;w` run `pane.close` on the pane that runs Neovim, `;d` opens the done list, `;p` runs `tab.prev`, `;v` splits, and `;;` reaches Neovim as one `;`. The decision, the runbook and the plan record the leader clash for Neovim's old `<leader>` maps only, not for the restored `;` motion — `neovim/.config/nvim/lua/config/options.lua:50` → fixed (Turn off Neovim's ; motion, which the herdr-app leader takes)
- [ ] Nit: `<leader>tt` is also mapped in terminal mode, so it is now `<space>tt` in Neovim's floating terminal. Typing a space and then `tt` there (`cat tt.log`) toggles the terminal away instead of typing, and each space waits for the next key or `timeoutlen` (300 ms) before it reaches the shell — `neovim/.config/nvim/plugin/floaterminal.lua:61` → fixed (Map the floating terminal toggle in normal mode only, off the space leader)

## Round 6 — 2026-11-11 19:44 UTC — 1e8d1d40

Round 5 fixes: `floaterminal.lua:62` maps `<leader>tt` in normal mode only, so a space typed in the floating terminal reaches the shell at once. No other `<leader>` mapping in the Neovim config holds back typed spaces: every `vim.keymap.set` with `<leader>` is mode `"n"`, and the lazy.nvim `keys` specs in `snacks.lua`, `octo.lua`, `todo-comments.lua` and `mini-files.lua` set no `mode`, so they are normal mode. The only terminal-mode and insert-mode maps (`<Esc>`, `<esc><esc>`, `<C-s>`, `<C-a>`, `<C-e>`, `<M-b>`, `<M-f>`) use no leader. The runbook (`herdr-app-cores.md:38`) now records the restored `;` motion. Checked against `keys.json`: `; x` and `; w` bind `pane.close`, `; p` binds `tab.prev`, and `; ;` binds `send:;`, as the runbook says. The round 5 Important stays open, waiting on Etienne's decision.

Compliance: the same as round 5. Each phase 3 criterion maps to its test. The keystroke checks (plan step 4), the agent list contents (step 7), pressing the chords and the Steam Deck `ctrl+alt+meta` check stay with Etienne. All 15 tests named in `## Proof` and the per-file list exist. No existing test was weakened, skipped or deleted.

Checks: `herdr_app_keys_test.rb` 9 runs, 189 assertions; `herdr_app_package_test.rb` 18 runs, 57 assertions; `editor_test.rb` 17 runs, 65 assertions; `neovim_avante_dependencies_test.rb` 2 runs, 6 assertions; 0 failures. stylua `--check` on `floaterminal.lua` and `options.lua`: clean. no-hardwrap markdownlint on the runbook, glossary, intent, plan and review: clean. Only `floaterminal.lua` and the runbook changed since round 5. Design: no new public method, no N+1 loop, no Law of Demeter finding, no Avoid word outside code names.

- [ ] Nit: "Neovim's own `;` … reaches Neovim only before a key with no leader binding" is not quite true. In a terminal, `; space` is bound to `send:; ` (`keys.json` `terminal` section), so `;` followed by a space also reaches Neovim, as `;` and then a space — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md:38` → fixed (Say that ; then space reaches Neovim, and drop the Deck clash check)

## Round 7 — 2026-11-11 19:46 UTC — 45b21de3

Round 6 fix: the runbook (`herdr-app-cores.md:38`) now says Neovim's `;` reaches Neovim before a space (`; space` types `; `) or before a key with no leader binding. This matches `keys.json`: the `terminal` section binds `; space` to `send:; ` (line 180) and overrides the `global` `; space` → `mod.open:picker` (line 91). `; x` and `; w` bind `pane.close`, `; p` binds `tab.prev` and `; ;` binds `send:;`, as the runbook says. The removed Steam Deck clash sentence is intended (Etienne expects no KDE clash); the runbook (line 38) keeps the Linux Super note and the `; ` + arrow fallback, and the plan's chord Proof line keeps its sandbox check. The round 5 Important stays open, waiting on Etienne's decision.

Compliance: the same as round 6. Each phase 3 criterion maps to its test. The keystroke checks (plan step 4), the agent list contents (step 7), pressing the chords and the Steam Deck leader check stay with Etienne. All 15 tests named in `## Proof` and the per-file list exist. No existing test was weakened, skipped or deleted.

Checks: `herdr_app_keys_test.rb` 9 runs, 189 assertions; `herdr_app_package_test.rb` 18 runs, 57 assertions; 0 failures. no-hardwrap markdownlint on the runbook, glossary, intent, plan and review: clean. Only the runbook and plan.md changed since round 6. Design: no new public method, no N+1 loop, no Law of Demeter finding, no Avoid word outside code names (`picker`, `app.palette`).

Nothing new found.

## Round 8 — 2026-11-11 19:52 UTC — 5ad67320

Since round 7: Etienne decided the round 5 Important (intent `## Decisions`, line 241): Neovim's `;` motion is off. `keymaps.lua:27` maps `;` to `<Nop>` in normal mode, which matches the decision word for word. The runbook (`herdr-app-cores.md:38`) says `;` belongs to herdr-app, Neovim maps it to `<Nop>` in normal mode, and `;x`, `;w` and `;p` still reach herdr-app. This matches `keys.json`. No other Neovim file maps a literal `;`; every leader map uses `<leader>`. flash.nvim's char mode maps `;` in `n`, `x` and `o` when `;` is not the leader, but it skips `;` when a normal-mode mapping exists. A headless Neovim run on the worktree config, after flash loads, shows `;` as `<Nop>` in `n` and unmapped in `x` and `o`, while flash maps `f` and `,` in all three. The `<Nop>` loads in `init.lua` before flash's `VeryLazy` setup. Visual and operator-pending `;` keep Vim's own repeat, as the decision names normal mode only.

Compliance: the same as round 7. Each phase 3 criterion maps to its test. The keystroke checks (plan step 4), the agent list contents (step 7), pressing the chords and the Steam Deck leader walk stay with Etienne. All 15 tests named in `## Proof` and the per-file list exist (`test_the_agent_lists_are_clones_of_the_picker` is the recorded rename to `test_the_agent_lists_are_clones_of_a_shipped_mod`). No existing test was weakened, skipped or deleted. The Neovim changes are configuration, with no test of their own.

Checks: `herdr_app_keys_test.rb` 9 runs, 189 assertions; `herdr_app_package_test.rb` 18 runs, 57 assertions; `editor_test.rb` 17 runs, 65 assertions; `neovim_avante_dependencies_test.rb` 2 runs, 6 assertions; 0 failures. rubocop on both herdr-app test files: clean. stylua `--check` on `keymaps.lua`, `options.lua` and `floaterminal.lua`: clean. no-hardwrap markdownlint on the runbook, glossary, intent, plan and review: clean. `node --check` on `main.js`: clean. Design: no new public method, no N+1 loop, no Law of Demeter finding, no Avoid word outside code names (`picker`, `app.palette`).

- [ ] Nit: plan.md's implementation departures record the move of Neovim's leader to space, but not the two Neovim changes that followed from review: `;` mapped to `<Nop>` in normal mode (`keymaps.lua:27`) and the floating terminal's `<leader>tt` in normal mode only (`floaterminal.lua:62`). They live only in the intent decision, the runbook and the commits — `docs/changes/herdr-app-keys/plan.md:196` → fixed (docs: record the later Neovim key changes as plan departures)

## Round 9 — 2026-11-11 19:54 UTC — 02b1308f

Round 8 fix: plan.md's implementation departures (`plan.md:197`) now record the two later Neovim changes. `;` maps to `<Nop>` in normal mode, which matches `keymaps.lua:27` and the intent decision (`intent.md:241`). The floating terminal's `<leader>tt` toggle is in normal mode only, which matches `floaterminal.lua:62`, with the reason that a terminal-mode `<space>tt` held back every typed space. The line is one line, with no hard wrap.

Whole branch, read fresh: `keys.json`, the agent list code (`agents-done/main.js`, the `agents-blocked/main.js` relative symlink), both `mod.json` files, the Neovim changes, the runbook and the glossary agree with the intent, the plan's `## Design` and the earlier rounds' fixes. `;` keeps Vim's repeat in visual and operator-pending modes, which matches the "normal mode" decision.

Compliance: the same as round 8. Each phase 3 criterion maps to its test. The keystroke checks (plan step 4), the agent list contents (step 7), pressing the chords and the Steam Deck leader walk stay with Etienne. All 15 tests named in `## Proof` and the per-file list exist (`test_the_agent_lists_are_clones_of_the_picker` is the recorded rename). No existing test was weakened, skipped or deleted.

Checks: `herdr_app_keys_test.rb` 9 runs, 189 assertions; `herdr_app_package_test.rb` 18 runs, 57 assertions; 0 failures. no-hardwrap markdownlint on the plan, intent, review, runbook and glossary: clean. Only plan.md changed since round 8. Design: every public `AgentList` method is signed, no N+1 loop, no Law of Demeter finding, no Avoid word outside code names (`picker`, `app.palette`).

Nothing new found.
