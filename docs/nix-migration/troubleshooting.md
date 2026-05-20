# Troubleshooting

## The stow-before-switch footgun

**Problem:** `home-manager switch` fails with an error like
`Existing file '/home/etienne/.gitconfig' is in the way`.

**Cause:** Home-manager refuses to overwrite files it doesn't own — including stow symlinks.

**Fix:** Always unstow the package *before* switching:
```sh
stow -D <package>   # removes symlinks
home-manager switch
```

If you forgot and the switch partially applied, roll back the home-manager generation first
(`home-manager generations` → `<prior-path>/activate`), then unstow, then switch again.

---

## Rolling back a home-manager generation

```sh
home-manager generations
# Output: list of activations with paths, e.g.:
# 2024-01-15 10:23 : id 42 -> /nix/store/.../home-manager-generation
# 2024-01-14 18:01 : id 41 -> /nix/store/.../home-manager-generation

# Activate a prior generation:
/nix/store/.../activate
```

---

## Rolling back a nix-darwin generation (Phase 6+)

```sh
darwin-rebuild --list-generations
darwin-rebuild --rollback
# Or target a specific generation number:
sudo /run/current-system/sw/bin/darwin-rebuild --switch-generation <N>
```

---

## Recovering from a broken SteamOS Hyprland session

If Hyprland fails to start from Game Mode (black screen, crash, etc.):

1. Press the Steam button to return to Game Mode.
2. Go to Desktop Mode via the Power menu → Switch to Desktop.
3. Open a terminal in KDE/GNOME desktop.
4. Check Hyprland logs: `cat ~/.local/share/hypr/*.log | tail -50`.
5. If the issue is a nixGL path: verify `nix profile list | grep nixGL` and reinstall if missing.
6. If the Nix daemon is not running: `systemctl --user status nix-daemon` (SteamOS may need
   `sudo systemctl start nix-daemon`).
7. Rebuild the environment: `home-manager switch --flake path:$HOME/Developer/dotfiles#default`.

---

## nix-daemon not running after reboot (SteamOS)

SteamOS updates can reset system files, including `/etc/profile.d/nix.sh`. If Nix commands stop
working after a SteamOS update:

1. Check: `/nix/nix-installer repair` (Determinate Systems installer provides this).
2. If the `/nix` overlay partition is unmounted: reboot SteamOS and check again.
3. If the partition is mounted but the daemon is stopped:
   `sudo systemctl start nix-daemon`.

---

## direnv not loading the flake

**Symptom:** `cd` into a project with `.envrc`, no env change, no "direnv: loading" message.

**Check 1:** Is `eval "$(direnv hook zsh)"` in your shell init? Verify: `type direnv_hook`.

**Check 2:** Did you `direnv allow` in this directory? Run `direnv allow`.

**Check 3:** Is nix-direnv installed? Check `~/.nix-profile/share/nix-direnv/direnvrc` exists.
If not, `home-manager switch` with `programs.direnv.nix-direnv.enable = true`.

**Check 4:** In a git worktree, `.envrc` must exist in the worktree root, not just the main
worktree. Symlink or copy it: `ln -s ../main-worktree/.envrc .envrc && direnv allow`.

---

## rv stops working after Nix PATH changes

**Symptom:** `rv shell 4.0.3` gives "command not found" or uses the wrong Ruby.

**Cause:** A Nix-managed tool prepended to PATH is shadowing rv or its shims.

**Fix:** Check `which rv` — it should resolve to Homebrew's bin (e.g. `/opt/homebrew/bin/rv`).
If not, check `~/.nix-profile/bin` for a conflicting `rv` or `ruby`. Per-project flakes use
`unset RUBY_VERSION RV_RUBY_VERSION` in `.envrc` to avoid this conflict.

---

## Work overlay not loading

**Symptom:** Work aliases/functions not available in a new terminal, even with `dotfiles-work` stowed.

**Check 1:** Is `dotfiles-work` stowed? `ls ~/.config/zsh/*.work.zsh` should list files.

**Check 2:** Is the source loop in `.zshrc` (or `programs.zsh.initContent` post-Phase 4)
preserved verbatim from the plan? It must source `$ZDOTDIR/${base}.work.zsh` for each base.

**Check 3:** Did a `home-manager switch` overwrite `~/.zshrc` with a version that lost the loop?
Check the generated `~/.zshrc` content.
