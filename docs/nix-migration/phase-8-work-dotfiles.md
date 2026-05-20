# Phase 8 — Migrate dotfiles-work to Nix

**Goal:** Convert `dotfiles-work` (private repo) into its own flake that imports the main
dotfiles flake as a base. One command bootstraps the full work setup.

**Start only after Phase 7 has been stable for at least one week of daily use.**

## Prerequisites

- Phase 7 complete and stable.
- Main dotfiles `flake.nix` exposes `homeManagerModules.default` and `darwinModules.default`.
- SSH key in 1Password provides `git+ssh` access to the private `dotfiles-work` repo.

## Step-by-step checklist

### Step 1 — Expose personal config as reusable modules

- [ ] Refactor main dotfiles `flake.nix` to add module outputs:
  - `homeManagerModules.default` — personal home-manager config as a module function.
  - `darwinModules.default` — personal nix-darwin config as a module function.
- [ ] Rewrite existing `darwinConfigurations.default` and `homeConfigurations.default` to
  consume their own module outputs internally (personal users keep one-command switching).
- [ ] `sudo darwin-rebuild switch --flake .` — verify nothing changed for personal setup.

### Step 2 — dotfiles-work becomes a flake

- [ ] Add `flake.nix` to `~/Developer/dotfiles-work`:
  ```nix
  inputs.dotfiles.url = "git+ssh://git@github.com/<user>/dotfiles";
  inputs.nixpkgs.follows = "dotfiles/nixpkgs";
  ```
- [ ] Add `darwinConfigurations.work` — composes `dotfiles.darwinModules.default` +
  work-only modules.
- [ ] Add `homeConfigurations.work` — composes `dotfiles.homeManagerModules.default` +
  work-only modules (for non-darwin work machines).
- [ ] Migrate work-specific content into `dotfiles-work/modules/`:
  - `aliases.work.zsh` content → work zsh module.
  - `environment.work.zsh` content → work zsh module.
  - `git/work.config` content → work git module.
  - `1password.work.env` references → work 1password module.
  - Work brew packages → work homebrew module.

### Step 3 — Switch the work machine to the work flake

- [ ] `sudo darwin-rebuild switch --flake path:$HOME/Developer/dotfiles-work#work`.
- [ ] Verify full personal config + work overrides are applied.
- [ ] Verify personal-only machine still switches cleanly from `dotfiles#default`.

### Step 4 — Retire dotfiles-work Stow setup

- [ ] Remove `dotfiles-work/install.sh`, `dotfiles-work/packages.conf`, and stow packages.
- [ ] Keep the file-existence source loop in `modules/shared/zsh.nix` and the `includeIf`
  directive in `modules/shared/git.nix` as harmless no-ops / rollback path.

## Verification

| Check | Expected output |
|-------|-----------------|
| Work machine bootstrap | `darwin-rebuild switch --flake .../dotfiles-work#work` succeeds |
| Personal machine | `darwin-rebuild switch --flake .../dotfiles#default` still works |
| Work aliases active | `which <work-alias>` resolves on work machine, not on personal machine |
| nixpkgs aligned | `nix flake metadata` shows same nixpkgs revision in both flakes |

## Rollback

```sh
# On work machine: roll back to the previous darwin generation, or switch back to personal:
darwin-rebuild --rollback
# or:
sudo darwin-rebuild switch --flake path:$HOME/Developer/dotfiles#default
```

## Notes

<!-- Fill in: work flake.nix location, private repo URL, any module name collisions,
     nixpkgs follows verified, 1Password SSH agent working for git+ssh, etc. -->
