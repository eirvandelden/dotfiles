# Delivery account: rex-init-consolidate

## Behaviour delivered

The repo `rex/.config/rex/init.lua` is the only Rex config. It binds no `ctrl+s` key, because herdr owns `ctrl+s`. It binds `ctrl+up` to `client.prompt.previous` and `ctrl+down` to `client.prompt.next`. The live `~/.config/rex/init.lua` is in the trash, so `stow rex` no longer conflicts.

## Evidence

- `stow -n -v rex -t "$HOME"` reports no `cannot stow` line for `.config/rex/init.lua`.
- `ruby test/rex_config_test.rb`: 12 runs, 0 failures. The new tests failed first for the right reasons (5 failures, 1 error).
- Tests assert no active `ctrl+s` bind in any Rex Lua file, the two prompt binds, and that all seven actions stay registered and unbound.

## Check results

- `stylua --check`, `luajit -b` and `rubocop` are clean.
- `bin/test`: one file fails, `test/secrets_loader_test.rb` (5 failures). It also fails on the main checkout. The cause is the missing `op://Private/token/credential` item in the local 1Password vault. This branch does not touch it.
- `rex` is not on `PATH`, so `rex config check` did not run.

## Review outcome

Claude reviewer, round 1: no findings. No Codex review (`Codex review: no`).

## For Etienne

- Run the real `stow` for `rex` from `~/Developer/dotfiles` after the merge.
- Do not reload Rex before that stow: Rex would load no `init.lua`.
- After the stow, press `ctrl+up` and `ctrl+down` in Rex, and `ctrl+s` in a herdr pane.
- The switcher, project action, viewer and lazygit have no key now. Rebinding them is a later change.
- The `secrets_loader_test.rb` failure needs a separate branch (rule 25).
