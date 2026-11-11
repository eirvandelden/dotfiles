# Delivery: herdr-app-look (phase 4)

## Behaviour delivered

- The cores layout shows the sidebar, with its spaces list and agents list, on the right of the window.
- The `herdr-app` package holds four Solunized herdr-app themes, `solunized-{light,dark}-{blue,orange}.json`, byte-for-byte copies of the solunized output (solunized PR #28, merged as `6e85d29`). The root theme of the cores layout is the blue pair, so herdr-app follows the system's light and dark mode with Solunized colors.
- Panes are cards on a frame, as in the herdr TUI: the Solunized panel palette makes the cards `bg_0` on a `bg_1` frame with a `bg_2` border and an accent focus border.
- A new `core-look` mod switches the window to the orange pair when a work space has focus and back to the blue pair for a personal space. Its decision logic is `pick.js`, which keeps no state and leaves a theme picked by hand alone. The switch writes only herdr-app's untracked click state, never a tracked file.
- Every work space shows one fixed orange avatar mark; personal avatars no longer use orange (`MARK.ansi3` is Solunized yellow in `spaces-cores`).
- A `tabs-cores` clone of the shipped `tabs` mod keeps the first tab clear of the macOS window buttons now that the sidebar is on the right, with the sidebar shown or hidden. It differs from `tabs` only in that padding line and the clone's own asset paths.
- `settings.json` no longer carries `colors.accent`, which would have pinned the accent blue on work spaces.
- A runbook, `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-look.md`, records the theme copy command, the switch rules and the sandbox check.
- The glossary has the new terms (personal space, work space, theme pair, personal pair, work pair, owned theme, hand pick, shown halves, Dist themes, work mark).

## Evidence

Sandbox herdr-app 0.1.15 on 2026-11-11: `HERDR_APP_HOME=/tmp/hac4h`, `HC_SESSION=hac4`, a scratch core `hac4w` registered as machine `w4`, and this branch's package files copied into the sandbox home. Etienne's window and his `default` and `work` cores were never touched.

- `herdr-app status`: no errors with the cores layout, `core-look`, `spaces-cores` and `tabs-cores` loaded.
- Theme state (`layouts/.state/cores.json`) after focus on a personal space: `{solunized-light-blue, solunized-dark-blue}`; on a work space: `{solunized-light-orange, solunized-dark-orange}`. Same in dark and light appearance.
- Screenshots: the sidebar on the right; an orange focus border on a work space and a blue one on a personal space; the orange `W` mark on both work spaces, teal and violet marks on personal spaces; the first tab clear of the window buttons with the sidebar shown and hidden.
- Pixel samples: light terminal `#fffbf1` and frame `#eeeae0`; dark terminal `#012b38` and sidebar `#0d3b4a`. Ghostty's solunized backgrounds are `#fffbf1` and `#012b38`.
- Hand pick: `graphite` in the dark half stopped the switch on a work space. After both blue halves were picked again on a work space, the mod corrected to the orange pair.
- Restart: after the sandbox restarted, focus on a work space gave the orange pair.
- The sandbox `cores.json` stayed byte-identical to the package file after every focus switch.

## Check results

- `SOLUNIZED_DIR=<export of solunized origin/main> bin/test test/herdr_app_look_test.rb`: 26 runs, 0 failures, 0 skips; the drift test against the solunized output ran.
- `bin/test test/herdr_app_package_test.rb`: 14 runs, 0 failures. `bin/test test/isolated_git_test.rb`: green.
- Full `bin/test` in the agent shell: green except `test/secrets_loader_test.rb`, which fails locally with a 1Password `authorization timeout` from real `op` calls. This branch touches nothing under secrets, and the main branch's CI is green; the pull request's CI is the check for it.
- `herdr-app check`: passed for `core-look`, `spaces-cores` and `tabs-cores`.
- rubocop clean on the test files; lefthook passed on every commit. No work names in the diff.

## Review outcome

- Plan critique (Claude, opus): 11 findings, 10 fixed and 1 dismissed with a reason, before acceptance.
- Review round 1 (Claude reviewer): 0 Important, 2 Nits, both fixed (an avoided glossary word in a test, and where to run the runbook's copy loop).
- Review round 2: no findings.

## Pending with Etienne

- After this pull request merges (after phase 3, per the agreed merge order): commit or set aside the local herdr-app edits to `herdr-app/.config/herdr-app/settings.json` in the main checkout, pull, then `stow -R -t "$HOME" herdr-app` to link the new `themes/`, `mods/core-look/` and `mods/tabs-cores/` files. Then look at a personal and a work space in his own window.
- Reading of the intent to confirm: "every work space has the same fixed sidebar color" is built as one fixed orange avatar mark for every work space; the sidebar background stays the same for both cores.
