# Phase 3 — home-manager standalone; low-risk CLI tools

**Goal:** Introduce home-manager to manage low-risk CLI tools (fzf, ripgrep, bat, lazygit,
direnv) declaratively on both macOS and SteamOS. Migrate direnv from Homebrew to home-manager.

## Prerequisites

- Phase 0 complete on both platforms.
- Phase 1–2 complete on macOS (or at least Phase 0 verified working).

## Step-by-step checklist

### macOS

- [ ] Add `home-manager` and `flake-parts` as flake inputs to the dotfiles `flake.nix`.
- [ ] Create `modules/shared/cli.nix` with:
  - `programs.fzf.enable = true`
  - `programs.ripgrep` (or `home.packages`)
  - `programs.bat.enable = true`
  - `programs.lazygit.enable = true`
  - `programs.direnv.enable = true` + `programs.direnv.nix-direnv.enable = true`
- [ ] Create `modules/shared/default.nix` importing `cli.nix`.
- [ ] Create `home/etienne.nix` declaring identity and importing `modules/shared`.
- [ ] Add `homeConfigurations.default` to `flake.nix` pointing at `home/etienne.nix`.
- [ ] Run `home-manager switch --flake path:$HOME/Developer/dotfiles#default`.
- [ ] Edit `zsh/.config/zsh/paths.zsh` to put `~/.nix-profile/bin` **before**
  `/opt/homebrew/bin`.
- [ ] For each migrated tool: verify the home-manager version works, then
  `brew uninstall <tool>`.
- [ ] `brew uninstall direnv nix-direnv` after confirming `programs.direnv.enable` works.

### SteamOS

- [ ] Create `modules/linux/default.nix` with `targets.genericLinux.enable = true`.
- [ ] Run `home-manager switch --flake path:$HOME/Developer/dotfiles#default`.
- [ ] Verify fzf, ripgrep, bat, lazygit, direnv are available via `~/.nix-profile/bin`.
- [ ] Add `nix-flatpak` as a flake input.
- [ ] Create `modules/linux/flatpak.nix` declaring:
  - `com.microsoft.Edge`
  - `org.gnome.Geary`
  - `md.obsidian.Obsidian`
  - `com.onepassword.OnePassword` (verify exact app ID via `flatpak search` first)
  - Apple Music TBD (Edge-PWA or Cider — see open questions).
- [ ] Create `modules/linux/game-mode-launchers.nix` with entries for: Hyprland, Geary,
  Edge, Netflix-via-Edge, Disney+-via-Edge, Prime-Video-via-Edge, 1Password, Obsidian,
  optionally Ghostty.
- [ ] For each new non-Hyprland launcher: manually add to Steam once via Desktop Mode →
  Add a Non-Steam Game → browse to the wrapper script.

## Verification

| Check | Expected output |
|-------|-----------------|
| `which fzf` (macOS) | `~/.nix-profile/bin/fzf` |
| `home-manager switch` (second run) | no-op, no errors |
| `rv shell 4.0.3` (macOS) | still works |
| Work overlay (macOS) | new terminal sources work files if stowed |
| `which fzf` (SteamOS) | `~/.nix-profile/bin/fzf` |
| `flatpak list` (SteamOS) | shows declared apps |
| Game Mode (SteamOS) | non-Hyprland tiles appear in library |

## Rollback

```sh
# Roll back one home-manager generation:
home-manager generations  # find the previous generation path
<generation-path>/activate

# To fully exit home-manager:
home-manager uninstall
brew install fzf ripgrep bat lazygit direnv
# Re-add nix-direnv sourcing to environment.zsh (see Phase 0 block).
```

## Notes

<!-- Fill in: nixpkgs version used, any tool version mismatches, Flatpak app IDs confirmed,
     Apple Music decision, 1Password socket path on Linux, etc. -->
