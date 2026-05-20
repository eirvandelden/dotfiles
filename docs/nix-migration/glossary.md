# Glossary

## Nix

The package manager and build system. Not to be confused with NixOS (the operating system) or
nixpkgs (the package collection). Nix the tool evaluates `.nix` expressions and builds outputs
into `/nix/store`.

## nixpkgs

The canonical package collection for Nix. A git repo (`github:NixOS/nixpkgs`) with 100k+
packages. Referenced as a flake input and pinned in `flake.lock`.

## home-manager

A Nix-based tool (and module system) for managing user-level configuration. Two roles:
- **The tool** — the `home-manager` CLI that reads a config and activates it.
- **The config** — the `.nix` files you write under `modules/` and `home/` that describe what
  you want. `home-manager switch` applies the config.

Not to be confused with nix-darwin (which manages macOS system-level config).

## flake

A Nix project with a standardized interface (`flake.nix` + `flake.lock`). Inputs (other flakes)
are pinned in `flake.lock`. Outputs can be packages, dev shells, configurations, modules,
templates, etc. Flakes are the recommended way to write reproducible Nix.

## flake.lock

Auto-generated file that pins every flake input to an exact git revision. Commit this file to
get reproducible builds. Run `nix flake update` to update all inputs; `nix flake update <input>`
to update one.

## flake-parts

A framework for structuring `flake.nix` files. Splits the flake into composable modules so
each concern (dev shells, packages, home-manager configs) lives in its own file. Used in
per-project flakes to keep them small (~40 lines) and consistent.

## direnv

A shell extension that loads and unloads environment variables when you `cd` into or out of a
directory. Reads `.envrc` files. With `use flake`, it evaluates the project's `flake.nix` and
puts the dev shell's tools on PATH automatically — no manual `nix develop` needed.

## nix-direnv

A direnv extension that caches flake evaluations so `cd` is instant after the first load.
Without it, `direnv reload` re-evaluates the flake from scratch every time.

## nixGL

A wrapper tool that makes Nix-managed OpenGL/Vulkan apps work on non-NixOS Linux (including
SteamOS). Nix-built binaries expect GPU drivers at specific store paths; `nixGL <binary>` sets
up the required library paths at runtime. Required for Hyprland and any GPU-accelerated apps
installed via Nix on SteamOS.

## nix-darwin

The macOS equivalent of NixOS's system configuration module. Manages macOS system-level settings
(`system.defaults.*`), launchd agents/daemons, and the Homebrew package list via
`homebrew.casks`/`homebrew.brews`. Activated with `sudo darwin-rebuild switch --flake .`.

## mkOutOfStoreSymlink

A home-manager helper: `config.lib.file.mkOutOfStoreSymlink <absolute-path>`. Instead of
copying a file into `/nix/store` (which requires `home-manager switch` to see edits), this
creates a symlink that points directly back into the dotfiles repo. Edits are immediately
visible. Use for files you iterate on frequently (prompt config, Hyprland config); use
store-pinned for stable configs.

## targets.genericLinux.enable

A home-manager option (`true`/`false`) for non-NixOS Linux systems. Enables XDG path wiring,
session search directories, and other glue that NixOS would provide automatically. Mandatory
for home-manager to behave correctly on SteamOS.
