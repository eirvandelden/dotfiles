# Phase 5 — Migrate remaining stow packages

**Goal:** Migrate every remaining stow package into home-manager modules, retiring stow
packages one at a time. Order matters — unstow first, then switch.

## Prerequisites

- Phase 4C complete. zsh fully managed by home-manager. Stow only manages non-zsh packages.

## Per-package migration pattern

For each package:
1. Add `modules/shared/<name>.nix` (or platform-specific module), import from `default.nix`.
2. `stow -D <name>` to remove symlinks.
3. `home-manager switch`.
4. Verify tool behaves identically.
5. Remove `<name>` from `packages.conf`.

**Important:** Home-manager refuses to overwrite existing symlinks. Always unstow (`stow -D`)
before switching. See [troubleshooting.md](troubleshooting.md) for the stow-before-switch footgun.

## Tier 1 — Config-only, no runtime risk

- [ ] `git/` → `programs.git` + `programs.gh` in `modules/shared/git.nix`.
  Watch the 1Password signing block — wrap in a darwin conditional.
- [ ] `lefthook/` → `xdg.configFile` copy; binary already migrated in Phase 3.
- [ ] `lazygit/` → `programs.lazygit.settings`.
- [ ] `rubocop/`, `solargraph/`, `yamllint/`, `cspell/` → `xdg.configFile`.
- [ ] `bundler/` → `home.file."./.bundle/config"`.
- [ ] `rv/` → `xdg.configFile."rv/rv.kdl"`. rv binary stays brew-managed.
- [ ] `rtk/` → `xdg.configFile."rtk/config.toml"`.

## Tier 2 — Shell-adjacent

- [ ] `ssh/` → `programs.ssh` in `modules/shared/ssh.nix`. Verify `SSH_CONFIG_FILE` env
  var still aligns.
- [ ] `1password/` → `modules/darwin/onepassword-paths.nix` + `modules/linux/onepassword-paths.nix`.
- [ ] `github/` → `programs.gh.settings`.

## Tier 3 — Editor-class

- [ ] `neovim/` → `programs.neovim` in `modules/shared/neovim.nix`. Keep lazy.nvim managing
  plugins; home-manager only places `init.lua` and `nvim/` tree as `xdg.configFile`.
- [ ] `vim/` → `programs.vim` or `xdg.configFile."vim/vimrc"`.
- [ ] `claude/`, `codex/` → `xdg.configFile`. Binaries stay brew on macOS until Phase 6.
- [ ] `avante/` → `xdg.configFile` alongside `neovim/` (AI plugin config, part of the nvim tree).
- [ ] `editor/` → `home.file."./.local/bin/editor"` + `editor-wait`, executable bit preserved.
  Terminal-aware nvim/Neovide routing script; keep `$EDITOR`/`$VISUAL` wiring intact.

## Tier 4 — macOS-app-tied (leave near nix-darwin in Phase 6)

- [ ] `ghostty/` → `xdg.configFile."ghostty/config"`. App stays Homebrew Cask.
- [ ] `zed/` → `xdg.configFile`. App stays Homebrew Cask.
- [ ] `pumadev/`, `caddy/` → `xdg.configFile`/`home.file`. LaunchAgents stay manual until Phase 6.
- [ ] `tones/` → config-only; trivial.

## Tier 5 — Leave alone or kill

- [ ] `node/.node-version`, `ruby/.ruby-version` → `home.file` defaults for projects without
  per-project pinning.
- [ ] `hyprland/` → covered by `modules/linux/hyprland.nix` (SteamOS-only).
- [ ] `secrets/` → keep stow-only; never goes into `/nix/store`.
- [ ] `test/` → delete last.

## Verification (per package)

- `stow -D <name>` cleanly removes symlinks (no "conflicts" output).
- `home-manager switch` succeeds (no errors).
- Tool behaves identically on macOS.
- Tool present on SteamOS where the module is shared.

## Rollback (per package)

```sh
home-manager generations   # find the generation before this package's migration
<prior-generation-path>/activate
stow <name>  # re-stow the package
```

## Notes

<!-- Fill in: packages migrated, any tool-specific surprises, SteamOS-specific notes,
     packages deferred or handled differently than planned. -->
