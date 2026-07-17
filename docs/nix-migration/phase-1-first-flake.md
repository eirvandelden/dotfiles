# Phase 1 — First project flake

**Goal:** Add a minimal top-level `flake.nix` to the dotfiles repo (templates only) and
put one personal project on its own per-project flake, loaded automatically via direnv.

## Prerequisites

- Phase 0 complete on macOS (Nix installed, direnv wired up, `nix run nixpkgs#hello` works).
- direnv active in the shell.

## Step-by-step checklist

- [ ] Add top-level `flake.nix` to the dotfiles repo (minimal — pins `nixpkgs` and
  `flake-parts`, exposes `templates.ruby-rails` only; no `darwinConfigurations` or
  `homeConfigurations` yet).
- [ ] Add `templates/ruby-rails/flake.nix` — uses flake-parts, exposes a `mkShell` with
  Ruby + Node + Postgres + project tools.
- [ ] Add `templates/ruby-rails/.envrc` — contains `use flake`.
- [ ] Add `templates/ruby-rails/.gitignore` — ignores `.direnv/`.
- [ ] Pick one personal project. Run `nix flake init -t path:$HOME/Developer/dotfiles#ruby-rails`
  inside it.
- [ ] Run `direnv allow` in the project root.
- [ ] Verify `which ruby` returns a `/nix/store/...` path while inside the project.
- [ ] Verify `cd ..` → `which ruby` returns rv's Ruby path.
- [ ] If rv wins instead of Nix: delete the project's `.ruby-version` (the flake is now the
  version source) and re-verify.
- [ ] Create or verify a git worktree of the same project and confirm the flake env loads
  there too without any extra steps.

## Verification

| Check | Expected output |
|-------|-----------------|
| `which ruby` (inside project) | `/nix/store/...` |
| `which ruby` (outside project) | rv's path (e.g. `~/.rv/rubies/.../bin/ruby`) |
| `direnv status` (inside project) | shows loaded, no errors |
| Same flake in a worktree | `which ruby` → `/nix/store/...` without manual intervention |

## Rollback

```sh
# Inside the project:
rm flake.nix .envrc .direnv/

# Restore .ruby-version if it was deleted.

# The dotfiles top-level flake.nix is harmless to keep — no system state is affected.
```

## Notes

<!-- Fill in: which project was chosen, Ruby/Node versions pinned in the template, any PATH
     ordering issues encountered, etc. -->
