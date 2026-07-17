# Phase 0 — Foundation

**Goal:** Install Nix on both macOS and SteamOS, wire up direnv, and confirm the toolchain is
reachable — without touching any existing stow packages or Homebrew state.

## Prerequisites

- macOS machine with Homebrew installed.
- SteamOS 3.5+ installed. The `/nix` bind mount is created by the installer — no pre-existing `/nix` partition needed.
- Both machines are running and accessible.

## Step-by-step checklist

### Docs setup (do first)

- [x] Create `docs/nix-migration/` with README.md, all phase files, glossary.md, and
  troubleshooting.md.

### macOS

- [x] Install Nix via official installer (adds nix-daemon sourcing to `/etc/zshrc`
  automatically — the `experimental-features` line in `nix.conf` enables flakes):
  ```
  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
  ```
- [x] `brew install direnv`
- [x] `nix profile install nixpkgs#nix-direnv` (after Nix is installed)
- [x] Add direnv hook + nix-direnv sourcing block to `zsh/.config/zsh/environment.zsh`.
  The nix-daemon block is redundant (installer covers it via `/etc/zshrc`) but harmless.
- [x] Create `~/.config/nix/nix.conf` with `experimental-features = nix-command flakes`.
- [x] Open a new terminal and verify: `nix run nixpkgs#hello` → `Hello, world!`.
- [x] Verify direnv + nix-direnv:
  ```
  nix shell nixpkgs#hello --command which hello   # /nix/store/.../bin/hello
  ```
  direnv confirmed working: `direnv: using flake nixpkgs#hello` fires on `cd`.

### SteamOS (independent, can be done in parallel)

- [ ] Verify SteamOS 3.5+ and `/nix` overlay: `findmnt /nix`.
- [ ] Install Nix via Determinate Systems installer with `steam-deck` planner:
  ```
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install steam-deck
  ```
- [ ] Smoke-test: `nix run nixpkgs#hello`.
- [ ] Install nixGL: `nix profile install github:nix-community/nixGL#nixGLDefault`.
- [ ] Update `~/.local/bin/hyprland-gamemode` wrapper:
  1. Source `/etc/profile.d/nix.sh` at the top.
  2. Prepend `~/.nix-profile/bin:/nix/var/nix/profiles/default/bin` to PATH.
  3. Change the `exec` line to: `exec gamescope -f -W 1280 -H 800 -w 1280 -h 800 -- nixGL Hyprland`.
- [ ] Register launcher in Steam: Desktop Mode → Steam → Add a Non-Steam Game → browse to
  `~/.local/bin/hyprland-gamemode` → rename "Hyprland".
- [ ] Boot into Game Mode, launch "Hyprland" tile, verify nested Hyprland session starts with
  GPU acceleration.

## Verification

| Check | Expected output |
|-------|-----------------|
| `nix run nixpkgs#hello` (macOS) | `Hello, world!` |
| `nix run nixpkgs#hello` (SteamOS) | `Hello, world!` |
| direnv test on macOS | `which hello` → path under `/nix/store/...` while inside dir, gone after `cd ..` |
| Hyprland Game Mode tile (SteamOS) | Nested Hyprland session starts; GPU-accelerated |
| `rv shell 4.0.3` (macOS) | Still works — rv unaffected |
| Work overlay (macOS) | New terminal sources work aliases/env if `dotfiles-work` is stowed |

## Rollback

### macOS

```sh
# Uninstall Nix (official installer)
# Follow https://nixos.org/manual/nix/stable/installation/uninstall — roughly:
sudo /nix/nix-install --uninstall   # or the script the installer left behind

# Remove direnv
brew uninstall direnv
# nix-direnv goes away when /nix is removed

# Revert environment.zsh change — undo the Nix/direnv block added in this phase.
# The change is one commit; revert or manually delete the added block.

# Remove nix.conf
rm ~/.config/nix/nix.conf
```

### SteamOS

```sh
/nix/nix-installer uninstall
# Remove the "Hyprland" entry from Steam library via Desktop Mode → Steam → Library.
```

## Notes

**SteamOS update survival:** After any SteamOS OS update, verify the nix-daemon is still running:
```sh
systemctl status nix-daemon
```
If it's stopped, the Determinate Systems installer's systemd units should restart it automatically.
If not: `sudo systemctl start nix-daemon`. The Nix store itself lives on `/home/nix` and survives
updates — only the daemon service occasionally needs a nudge after a major OS update.

<!-- Fill in during execution: surprises, decisions made, version numbers installed, etc. -->
