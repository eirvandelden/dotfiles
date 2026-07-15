---
name: dotfiles-maintenance
description: Use when working inside the dotfiles repository itself — stow packages, bootstrap/install scripts, symlinks, or machine environment setup.
---

# Dotfiles Maintenance

All configuration is managed through a dotfiles repository at `~/Developer/dotfiles`, symlinked
into `~/` and `~/.config/` using GNU Stow. This is true on every machine. Work-specific
configuration lives in a separate private repository at `~/Developer/dotfiles-work`.

## Editors and language servers

- Primary editor is Nova on macOS. Secondary editors are Zed and VS Code (mainly for debugging
  with RDBG).
- Use Solargraph as the default Ruby language server. Experiment with Ruby LSP but do not assume
  it is always available.

## Ruby, linters, CI

- Ruby version manager is `rv` (spinel-coop/rv) — no RVM/rbenv/chruby. Use `rv ruby run -- COMMAND`
  to run a command in the correct Ruby context on a version mismatch, rather than installing or
  switching versions.
- Use RuboCop for Ruby, `scss-lint` for legacy SCSS, Herb and cspell where they add value. Never
  add linter disable comments; if a file already has them, no need to remove them just for that.
- Run Bundler Audit and Brakeman before pushing; CI runs the full test suite.

## Shell, packages, Node, git signing

- Default shell zsh, default terminal Ghostty. Shell config lives in `~/.config/zsh/` (`.zshrc`,
  `paths.zsh`, `environment.zsh`, `aliases.zsh`, `prompt.zsh`, modular `functions/` loaders).
  Work-specific overlays supported (e.g. `aliases.work.zsh`).
- Primary package manager Homebrew (`brew`); all packages declared in `packages.conf`. Linux
  fallbacks: `yay` (Arch/AUR), `apt` (Debian), `flatpak` (GUI apps).
- Ruby built with YJIT and jemalloc; default version in `ruby/.ruby-version`. Global gems (bundler,
  rubocop, kamal, solargraph, etc.) installed by `40_install_default_ruby_gems.sh`.
- Node version manager `chnode` (tkareine/chnode tap); default version in `node/.node-version`.
- SSH signing via 1Password (ed25519 key, `gpg.format = ssh`). Git hooks managed by Lefthook
  (pre-commit, pre-push, commit-msg, post-merge). Trusted binstubs via the `.git/safe` convention.

## Stow packages, bootstrap, cross-platform

Each top-level directory in the dotfiles repo is a Stow package. See `references/repository-layout.md`
for the current package list and the cross-platform package-manager breakdown.

- `bootstrap.sh` is a curlable POSIX script that clones the repo and runs the installer.
- `install.sh` orchestrates numbered scripts (`00_common.sh` through `50_stow_all.sh`) covering OS
  updates, prerequisites, packages, runtimes, gems, npm packages, and stow.

## Symlink safety (hard rule — also enforced in core playbook)

- NEVER overwrite, delete, or modify symlinks directly. Always edit the source file in
  `~/Developer/dotfiles/<package>/`, never the symlinked target in `~/` or `~/.config/`.
- NEVER run `stow` or `stow -R` without explicit instruction.
- NEVER create new stow packages (top-level directories) without explicit instruction.
