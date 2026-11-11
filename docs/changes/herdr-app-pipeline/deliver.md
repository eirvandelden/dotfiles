# Delivery account: herdr-app, phase 5 (pipeline)

## Behaviour delivered

- herdr-app is a third pane backend. The dispatchers `hand-off-plan`, `start-review` and `open-pr-dash` pick it when `HC_TERMINAL_ID` is set; the herdr TUI (`HERDR_ENV=1`) still wins, and Rex comes after. `COORDINATOR` becomes `HERDR_APP_COORDINATOR`.
- `herdr-app/.config/herdr-app/scripts/{hand-off-plan,start-review,open-pr-dash}.sh` carry the Rex prompts. The prompt is claude's first argument; the worker reports with `hc send <coordinator>` and closes its own pane with `herdr-app-pane close`.
- `herdr-app-pane` (`herdr-app/.local/bin`, library in `herdr-app/.local/share/herdr-app-pane/`) holds every `herdr-app ls` and `herdr-app do` call: `open` (column, new row, unlisted, worktree; rooted in its folder; gives focus back; waits up to 30 s for an agent in a stage pane and closes it otherwise), `close`, `close-idle <slug>` (deliver) and `close-at <cwd>` (worktree sweep). It works only inside the coordinator's space and refuses a space id that two machines list.
- `deliver` closes idle herdr-app stage panes; `worktree-pane` opens and closes worktree panes in herdr-app; `play-tone.sh` stays silent in a herdr-app terminal; `bin/test` clears the herdr-app variables for every test file.
- The intent, plan, implement, review and deliver skills name the herdr-app backend, its coordinator id and the `<hc from=…>` wrapping of ready lines.
- The worktree viewer is out of phase 5, per Etienne's decision of 2026-11-11: phase 3's `; f` Files panel is the herdr-app viewer.

## Evidence

- Probe in a sandbox window (`probe.md`): answer shapes, focus moves on a split, kept terminals, the trust dialog.
- Live check in a sandbox window (`HC_SESSION=hac5`, started under `env -i`, scratch repository with a local bare origin, scripts from this worktree):
  - `hand-off-plan implement live-check` from a sandbox shell opened a real `claude --model sonnet` stage pane beside it; the worker wrote its report, its `Handoff done: <report path>` line reached the coordinator terminal, and it closed its own pane. Focus stayed on the coordinator.
  - The first try met claude's folder-trust dialog in the new scratch repository; `herdr-app-pane` printed "no agent started in t5 within 30.0 s; closed its pane".
  - `herdr-app-pane close-idle live-check` closed an idle claude pane and removed the row record.
  - `worktree-create live-pane` opened a login-shell pane below the caller, rooted in the new worktree; focus stayed on the caller.
- Not checked live: the `<hc from=…>` wrapping (the sandbox coordinator was a shell), and `start-review` (covered by its test).

## Checks

- `bin/test` without `test/secrets_loader_test.rb`: 116 files, 0 failed. `secrets_loader_test.rb` reaches the real 1Password CLI on this Mac, unrelated.
- rubocop, shellcheck and markdownlint (no-hardwrap) clean on every changed file.

## Review

Plan: one Claude critique round, 15 findings, all fixed; the worktree viewer finding went to Etienne. Code: two Claude reviewer rounds; round 1 had one Important finding (a space id on two machines) and four nits, all fixed; round 2 clean.

## Pending for Etienne

- After the merge, restow the `herdr-app` package (`stow -R -t "$HOME" herdr-app` from the dotfiles repository): the scripts and `herdr-app-pane` are new files in a file-by-file package.
- Merge order: keys, look, then this branch; rebase it after each merge.
