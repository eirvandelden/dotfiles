# Delivery account: remove-bundler-from-stow

## Behaviour delivered

On a fresh clone, the installer's stow step no longer stops at `bundler`: `bundler` is gone from `STOW` and from the package lists in `agents.md` and the dotfiles-maintenance repository layout. The `bundler` gem in `RUBY_GEMS` stays.

## Evidence

- Regression test `test_every_stowed_package_has_a_tracked_folder` failed on the old `STOW`, naming `bundler`, and passes after the fix. It reads only `git ls-files`, so the untracked local `bundler/.bundle` is never read.
- Manual check on a fresh clone with a scratch `HOME`: `50_stow_all.sh` ran through `zsh` and logged "stow: all configured packages applied". The `caddy` `Caddyfile` link and the `claude` `settings.json` link resolve into the clone.
- The `herdr-app` link from the first acceptance criterion is proved on the `herdr-app` branch after it rebases onto this fix.

## Checks

- `bin/test test/stow_package_roots_test.rb test/repo_agents_file_test.rb`: 12 runs, 0 failures.
- `bin/test`: every file green except `test/secrets_loader_test.rb`, which calls the real 1Password CLI on this Mac; CI on `main` is green, so it is a local-only failure, unrelated to this change.
- `rubocop` on the changed test file: no offenses. Lefthook pre-push checks passed.

## Review

One Claude reviewer round, clean: no open finding.
