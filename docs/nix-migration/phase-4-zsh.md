# Phase 4 — Migrate zsh to home-manager

**Goal:** Transfer shell configuration from the stow `zsh/` package into home-manager's
`programs.zsh`, retiring the stow package at the end. Split into three sub-generations so
behavior never changes more than once per switch.

## Prerequisites

- Phase 3 complete on both platforms. home-manager running and confirmed stable.

## Sub-phase 4A — Shell loading as before

- [ ] Add to `modules/shared/zsh.nix`:
  ```
  programs.zsh.enable = true;
  programs.zsh.initContent = "source $HOME/.config/zsh/.zshrc-legacy";
  ```
- [ ] Rename `zsh/.config/zsh/.zshrc` to `zsh/.config/zsh/.zshrc-legacy` in the repo.
  Stow continues to symlink it.
- [ ] `home-manager switch` — home-manager now owns `~/.zshrc`; it just sources legacy content.
- [ ] Open a new terminal and verify: prompt identical, no errors, rv and chnode work.

## Sub-phase 4B — Content migration (block by block)

For each block, migrate and verify before moving to the next:

- [ ] **History** (`.zshrc:1-13`) → `programs.zsh.history.*`.
- [ ] **PATH construction** (`paths.zsh`) → `home.sessionPath` + `programs.zsh.envExtra`.
  Keep `eval "$(rv shell init zsh)"` and chnode source line verbatim inside `envExtra`.
- [ ] **chpwd hooks** for rv/chnode → inside `programs.zsh.initContent`, gated with
  `command -v rv` / `command -v chnode` (so the same module works on SteamOS).
- [ ] **Work overlay loop** (`.zshrc:22-25`, `:28`) → preserve **verbatim** inside
  `programs.zsh.initContent`. `dotfiles-work` continues to stow `*.work.zsh` files.
- [ ] **1Password SSH_AUTH_SOCK** (`environment.zsh:31-32`) → `home.sessionVariables.SSH_AUTH_SOCK`
  inside `modules/darwin/onepassword-paths.nix` (macOS only).
- [ ] **Custom prompt** (`prompt.zsh`) → `xdg.configFile."zsh/prompt.zsh".source = ./files/prompt.zsh`
  + source from `initContent`.
- [ ] **Functions** (`functions/*.zsh`) → `xdg.configFile."zsh/functions" = { source = ./files/functions; recursive = true; }`.
- [ ] `home-manager switch` after each block. Verify identical behavior after each.

## Sub-phase 4C — Retire stow zsh package

- [ ] `stow -D zsh` from the repo root.
- [ ] Remove `zsh` from `STOW=(...)` in `packages.conf`.
- [ ] `home-manager switch` — home-manager now fully owns `~/.zshrc`, `~/.zshenv`,
  `~/.config/zsh/*`.
- [ ] Open a new terminal: verify prompt, rv, chnode, work overlay all work.
- [ ] `exec zsh` in an existing terminal: no duplicate completions or PATH entries.

## Verification

| Check | Expected output |
|-------|-----------------|
| New terminal | Prompt identical to pre-Phase 4 (battery + timer) |
| `cd` into Ruby project | rv switches Ruby automatically |
| `cd` into Node project | chnode switches Node automatically |
| Work overlay | sourced when `dotfiles-work` files exist |
| `home-manager switch && exec zsh` | no duplicate completions or PATH entries |
| `stow list` (after 4C) | `zsh` not listed |

## Rollback

```sh
# Roll back to a prior sub-generation:
home-manager generations
<prior-generation-path>/activate

# After 4C, if you need stow back:
home-manager generations  # activate a pre-4C generation
stow zsh  # re-stow the package
```

## Notes

<!-- Fill in: any zsh option that didn't translate cleanly, surprises with initContent ordering,
     SteamOS-specific divergences, etc. -->
