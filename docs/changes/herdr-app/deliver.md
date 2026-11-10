# Delivery account: herdr-app, phase 1 (stow package)

## Behaviour delivered

- A new `herdr-app` stow package holds `keys.json` and `settings.json`, linked file by file (`STOW` and `STOW_SHARED`), so `~/.config/herdr-app` stays a real folder for the files Herdr writes.
- `settings.json` is portable: the sound paths are relative (`../../Documents/Tones/herdr/…`) and resolve under each machine's home. The font stays MonoLisa.
- macOS: the `herdr-app` cask in `BREW_MACOS`.
- SteamOS: `install/tasks/26_install_herdr_app.sh` installs herdr-app from the Linux release tarball. It checks the sha256 from `releases.herdr.dev`, downloads over HTTPS only, writes only under `$HOME` and `$XDG_DATA_HOME`, quotes the desktop entry's `Exec` path, and downloads nothing once installed.
- `determine_os` reads `OS_RELEASE_FILE` as a test seam; without it, nothing changes.

## Evidence

- Sandbox window with its own app home and core, links to this worktree's files:
  - A repository edit of `settings.json` reached the window in 9.3 s (intent: within 10 seconds).
  - A save from the app (`app.zoom_in`) wrote through the link: the link stayed, and `git diff` listed the file. The whole-folder fallback is not needed.
  - `git status` listed no file Herdr wrote.
  - The sound paths resolve to `~/Documents/Tones/herdr/`.
- Fresh clone of the branch, real `stow`, scratch `HOME`: `50_stow_all.sh` exited 0; both files link into the clone; the config folder is a real folder.
- Not yet verified: MonoLisa and tone playback in Etienne's own window, and the three timed `font` changes (plan step 9, after the merge). The fresh-Mac cask install and the Steam Deck install stay manual checks.

## Checks

- `test/herdr_app_install_test.rb`: 25 runs, 0 failures. `test/herdr_app_package_test.rb`: 10 runs, 0 failures.
- `bin/test`: every file green except `test/secrets_loader_test.rb`, which reaches the real 1Password CLI on this Mac; CI on `main` is green, so it is a local-only failure, unrelated to this change.
- `shellcheck` and `rubocop` clean on the touched files; lefthook pre-push checks passed.

## Review

Three Claude reviewer rounds. Round 1: two Important findings and two nits, all fixed. The missing `bundler` package was fixed first on its own branch (PR #273), and this branch rebased onto it. Round 2: one nit, fixed. Round 3: clean.

## Next

- After the merge, plan step 9 on this Mac: `trash` the two local files, `stow -d ~/Developer/dotfiles -t "$HOME" --no-folding --restow herdr-app`, then the live checks in Etienne's own window.
- Phase 2 starts from `intent.md` as it stands in this branch's history, the commit before `Remove change artifacts for herdr-app`.
