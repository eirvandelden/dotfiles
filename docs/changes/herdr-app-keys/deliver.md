# Delivery account: herdr-app, phase 3 (keys)

## Behaviour delivered

- `keys.json` adds a `;` leader sequence for most herdr-app shortcuts, from the intent's key map: tabs, spaces, agents, panes, splits, the sidebar, the Files panel, lazygit, search, the palette, help and settings. herdr-app's `cmd-…` defaults stay.
- In a terminal, `; ;` types `;` and `; space` types `; `. Elsewhere `; space` opens the `picker` mod. The leader also fires inside terminals.
- `ctrl-alt-cmd` chords repeat the moves Etienne makes many times in a row: an arrow focuses a pane, shift + arrow swaps it, `n`/`p` go to the next or previous tab, `]`/`[` to the next or previous space, and `a`/`shift-a` to the next or previous agent. Each chord runs the same action as its leader twin.
- Linux has no `cmd`, so the Steam Deck gets `ctrl-shift-c`/`ctrl-shift-v` for copy and paste, `ctrl-shift-k` for the `picker` mod, `ctrl-shift-l` for `layout.switch`, and `ctrl-` zoom keys. No action needs the Super key. On Linux the chords use Super, so `; ` + arrow is the fallback there.
- `; d` and `; b` open the `agents-done` and `agents-blocked` agent lists. Both load one `main.js` (`AgentList`, cut down from the shipped `picker` mod), and each `mod.json` names its status.
- Neovim's leader moves from `;` to space, and Neovim's `;` motion is off (`;` maps to `<Nop>` in normal mode): `;` belongs to herdr-app. The floating terminal's `<leader>tt` toggle works in normal mode only.
- The cores runbook says `layout.switch --name cores`, says to start cores only from a plain terminal, and describes the leader, the chords, the Linux keys and the agent lists.

## Evidence

- Sandbox window (`HC_SESSION=hac3`, scratch home), full `keys.json` with the chords: `keys.error` was absent, and `herdr-app status` showed `errors: []`. A cut-off file did produce `keys.error`, so the check works. GPUI also accepts a made-up key name, so this proves the file loads, not that each key name is real.
- `herdr-app check` passed on both agent list mods. `mod.open agents-blocked` returned ok, and the overlay showed in `status`. The status bar showed the `;` leader registered.
- Headless Neovim: after flash.nvim loads, `;` stays `<Nop>` in normal mode, and the leader is `" "`.
- Each sandbox was stopped by its own pid, and `hc server stop` ran. Etienne's windows and his `default` and `work` cores were not touched.

## Checks

- `bin/test`: 111 files, 0 failures. It left out `test/secrets_loader_test.rb`, which hangs when the 1Password agent is down (known, unrelated), and `test/herdr_worker_scripts_test.rb`. That file takes about 318 s and the diff does not touch it; it was green in the implement stage (94 runs, 0 failures).
- After the last change: `herdr_app_keys_test.rb` 9 runs, 189 assertions, 0 failures. `herdr_app_package_test.rb` 18 runs, 57 assertions, 0 failures. `editor_test.rb` and `neovim_avante_dependencies_test.rb` 0 failures.
- rubocop, stylua, `node --check` and markdownlint (no-hardwrap) are clean on every changed file. The pre-push hooks passed.

## Review

Plan: one Claude critique round. Code: nine Claude reviewer rounds (`Codex review: no`). They found 3 Important and 11 Nit findings, all fixed. Etienne decided two of them: Neovim's `;` leader clash (Neovim's leader moves to space, and the chords are added), and Neovim's restored `;` motion, which `;x`/`;w` turned into pane closes (the motion is off). Rounds 4, 7 and 9 found nothing new, and round 9 is clean.

## Pending for Etienne

- After the merge, fast-forward the main checkout, then restow `herdr-app` (`stow -R --no-folding -t "$HOME" herdr-app`) so the four agent list mod files link. Check that `~/.config/herdr-app/keys.error` does not exist and that `herdr-app status` names no keys error.
- Restow `neovim` (`stow -R -t "$HOME" neovim`). `~/.config/nvim` is a folded link into the main checkout, so the fast-forward alone already brings the new leader. The restow is a no-op check.
- Walk the key map in his own window: `; t`, `; w`, `; space`, `; ;`, `echo a; echo b`, `; d`, `; b`, `; f`, and the `ctrl-alt-cmd` chords. Walk the leader keys on the Steam Deck too.
- Check the agent-list contents: two done agents and one blocked agent show in `; d` and `; b`, Enter shows the agent, Esc closes the list, and an empty list shows its empty line.
