# Phase 2 — More project flakes

**Goal:** Roll out per-project flakes to 3+ personal projects and add extra templates as needed.

## Prerequisites

- Phase 1 complete. One project already on a flake. direnv confirmed working.

## Step-by-step checklist

- [ ] Identify projects that would benefit from per-project Nix pinning (Ruby/Node version
  constraints, Postgres version, project-specific CLI tools).
- [ ] Add extra templates as needed:
  - [ ] `templates/node-only/{flake.nix,.envrc,.gitignore}` if any pure Node projects exist.
  - [ ] `templates/ruby-postgres-redis/{flake.nix,.envrc,.gitignore}` if needed.
- [ ] For each additional project:
  - [ ] `nix flake init -t path:$HOME/Developer/dotfiles#<template>` in the project root.
  - [ ] `direnv allow`.
  - [ ] Verify `which ruby` (or `which node`) → `/nix/store/...` inside project.
  - [ ] Verify `direnv status` — no errors.
  - [ ] Verify any Conductor workspaces / worktrees of the project load the flake automatically.
- [ ] Confirm 3+ projects are on their own flakes.

## Verification

| Check | Expected output |
|-------|-----------------|
| `direnv status` in each project | loaded, no errors |
| 3+ projects | all show `/nix/store/...` Ruby/Node paths |
| Conductor workspace for each project | flake env loads on `cd` without manual steps |

## Rollback

Per project: `rm flake.nix .envrc .direnv/` and restore `.ruby-version`/`.node-version` if removed.

## Notes

<!-- Fill in: projects enrolled, templates added, any edge cases (monorepos, nested worktrees, etc.) -->
