# Phase 7 — End state for personal stack

**Goal:** Complete the personal migration. Delete the old installer, flip Homebrew cleanup to
`zap`, and confirm the personal stack bootstraps from a single Nix command on a fresh machine.

## Prerequisites

- Phase 6 complete and stable (at least one week of daily use).
- All stow packages retired except `secrets/`.

## Step-by-step checklist

- [ ] Delete `install/`, `install.sh`, `bootstrap.sh`, `packages.conf`, `.stow-global-ignore`.
- [ ] Delete remaining stow package directories (keep `secrets/` if repurposing as a
  non-stow encrypted dir; otherwise delete it too).
- [ ] Flip `homebrew.onActivation.cleanup = "zap"` in `modules/darwin/homebrew.nix` so
  unmanaged brews get pruned.
- [ ] `sudo darwin-rebuild switch --flake .` — verify clean with no unexpected removals.
- [ ] Write or update a single-command bootstrap for a new personal machine:
  `nix run github:<user>/dotfiles#bootstrap`.
- [ ] Test the wipe-and-reimage scenario (or simulate on a VM): install Nix → run bootstrap
  → verify fully-configured personal machine; no manual brew, no stow.
- [ ] Confirm work overlay still works on a machine with both repos cloned: new terminal
  sources `aliases.work.zsh`, git uses `work.config`.

## Verification

| Check | Expected output |
|-------|-----------------|
| `ls install/` | no such directory |
| `ls packages.conf` | no such file |
| `stow --dir=. --target=$HOME -n -v 2>&1` | nothing to stow |
| Wipe-and-reimage scenario | single Nix command → fully configured personal machine |
| Work overlay (with dotfiles-work cloned) | aliases/env/git config from work repo active |

## Rollback

At this phase, rollback means re-cloning the old installer and re-running stow. The git history
preserves the old files. This is a last resort — rolling back should not be necessary if each
prior phase was validated.

## Notes

<!-- Fill in: bootstrap command finalised, any cleanup surprises, confirmation of wipe scenario, etc. -->
