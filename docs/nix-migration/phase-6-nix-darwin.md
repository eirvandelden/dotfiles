# Phase 6 — Introduce nix-darwin

**Goal:** Add nix-darwin so a single `sudo darwin-rebuild switch --flake .` manages both
system-level macOS config and home-manager. Declare Homebrew Casks declaratively.

## Prerequisites

- Phase 5 complete on macOS. Nearly all stow packages retired. `secrets/` is the only
  remaining stow package.

## Step-by-step checklist

- [ ] Add `nix-darwin` as a flake input.
- [ ] Add `darwinConfigurations.default` output to `flake.nix`. home-manager runs as a
  nix-darwin module (not standalone).
- [ ] Create `modules/darwin/defaults.nix` — translate `defaults write` calls from
  `install/macos.sh` into `system.defaults.dock`, `system.defaults.finder`,
  `system.defaults.NSGlobalDomain`.
- [ ] Create `modules/darwin/homebrew.nix`:
  ```nix
  homebrew.enable = true;
  homebrew.onActivation.cleanup = "none";   # never auto-uninstall during transition
  homebrew.onActivation.autoUpdate = false;
  homebrew.casks = [ "ghostty" "zed" "claude" "codex-app" "tableplus" "rancher" "responsively" ];
  homebrew.brews = [ "rv" "chnode" "node-build" "1password-cli" ];
  ```
- [ ] Run `sudo darwin-rebuild switch --flake .` for the first time.
- [ ] Verify declared Casks are present: `brew list --cask`.
- [ ] Verify system defaults: `defaults read com.apple.dock`.
- [ ] Confirm existing rv, chnode, work overlays still work.

## Verification

| Check | Expected output |
|-------|-----------------|
| `sudo darwin-rebuild switch` | succeeds, no errors |
| `defaults read com.apple.dock` | shows configured values from `defaults.nix` |
| `brew list --cask` | matches `homebrew.casks` list |
| `rv shell 4.0.3` | still works |
| New terminal | prompt, rv, chnode, work overlay all normal |

## Rollback

```sh
darwin-rebuild --list-generations
darwin-rebuild --rollback
# Or target a specific generation:
sudo /run/current-system/sw/bin/darwin-rebuild --switch-generation <N>
```

## Notes

<!-- Fill in: nix-darwin version used, any system.defaults that didn't translate cleanly,
     Cask IDs confirmed, any brew formula name differences, etc. -->
