# Plan: Review GitHub pull requests inside Neovim

From `intent.md` and `spec.md` (2026-09-29). Status: accepted.

## Context

Reviewing a GitHub PR meant leaving the terminal. The implementation for this (octo.nvim, a `<leader>go`/`<leader>gl` keymap scheme, `gh` declared as a system dependency) was already built and committed on this branch before `intent.md`/`spec.md` existed — a violation of playbook rule 17, caught by review round 1 (`docs/changes/octo-nvim-plugin/review.md`). This plan formalizes that work and lists what verification is still owed, rather than proposing new code: nearly everything spec.md requires is already done.

## Files that change

Already changed, on this branch (SHAs are post-rebase, from `git fetch origin main` on 2026-10-06; cspell and `project-dictionary.txt` were removed from `main` in `4e547b6b`, so this branch no longer touches that file):

- `neovim/.config/nvim/lua/plugins/octo.lua` (`cb23e731`, `27eeb96b`) — installs octo.nvim, `picker = "snacks"`, `<leader>go` → `Octo pr list`.
- `neovim/.config/nvim/lua/plugins/snacks.lua` (`27eeb96b`) — lazygit moved to `<leader>gl`.
- `packages.conf` (`72f14e7b`, `a145f2c1`) — `gh` added to `BREW`; `GH_EXTENSIONS` added with `dlvhdr/gh-dash`.
- `install.sh`, `install/tasks/25_install_gh_extensions.sh` (`a145f2c1`) — installs the `gh-dash` CLI extension on a fresh machine, the same idempotent pattern as `install_brew_packages`.
- `install/utils.sh` (`a145f2c1`, `ee39ee77`) — `install_gh_extensions`/`gh_extension_is_installed`, and a log-line fix once the unauthenticated-fresh-machine case was found misleading.
- `github/.config/gh-dash/config.yml` (`d5c08489`, `86bb6bd7`) — shipped in the `github` stow package, no longer machine-local. Its `C` keybinding opens a herdr pane (`herdr pane split` + `herdr pane run`) running `nvim -c ":silent Octo pr edit {{.PrNumber}} {{.RepoName}}"`. An earlier version used `tmux new-window` (wrong multiplexer for this setup, never actually exercised) and a second `R` keybinding that piped an untrusted PR diff into `claude -p` with no tool restriction — a prompt-injection risk under this repo's `auto` Claude mode, and broken besides: gh-dash redraws its TUI the instant the command exits, so the output never stayed on screen. `R` was unplanned (not in `intent.md`/`spec.md`) and is dropped in `86bb6bd7`.

Dependency approval (playbook rule 11): the `dlvhdr/gh-dash` CLI extension is a new system dependency. Approved by the user's explicit instruction to "ship the gh-dash config and install step" (conversation, 2026-10-05) — it is what makes gh-dash's `C` keybinding resolve to a real binary on a fresh machine, instead of only on one where it happened to already be installed.

One-time migration owed on this machine (not fresh-machine-blocking): `~/.config/gh-dash/config.yml` predates this branch as a plain file, not a symlink. `stow --restow github` cannot succeed until it is moved aside — but the committed config only exists on this unmerged branch, so the real restow has to happen after merge, from the main checkout. Until then, the corrected content was copied into place directly (not symlinked) so `C` keeps working; the stale original is at `~/.config/gh-dash/config.yml.bak`.

## Order of work

This repository has no automated test framework for Neovim Lua config (confirmed in review round 1). Acceptance is proven by manual verification against a real pull request, in this order — each step is the walking skeleton for the one after it:

1. `<leader>go` in a repository with open PRs lists them (spec criterion 1).
2. Selecting a PR opens its overview with a file panel (criterion 2).
3. Opening a changed file from the panel shows diff hunks (criterion 3).
4. `<localleader>ca` on a diff line adds a comment; `<localleader>sa` adds a suggestion (criterion 4) — keymap names confirmed by loading octo.nvim's actual `octo.config` module headlessly and inspecting `values.mappings.review_diff`, not by trusting the README. Still owed: pressing them against a real PR's diff.
5. In the `pull_request` buffer `<localleader>vs` is `review_start`; once a review is open, the same key is `submit_review`, which opens a window offering `<C-a>` approve, `<C-m>` comment, `<C-r>` request changes (criterion 5) — same headless-config confirmation as step 4. Still owed: actually starting and submitting a review on a real PR, which is a GitHub write and needs your own hands, not something to automate here.
6. From gh-dash, `C` on a PR opens that same PR in Octo (criterion 6).
7. `<leader>gl` still opens lazygit (criterion 7 — regression check on the rename).
8. `packages.conf`'s `BREW` list carries `gh` (criterion 8) — spot-checked by reading the file, not by a fresh install.
9. Neither telescope nor fzf-lua was added (criterion 9) — spot-checked by search.

## Risks

- Steps 4 and 5's keymaps are confirmed correct against octo.nvim's actual default config (headless inspection, this plan's verification run), so the risk of a wrong key name is closed. What remains is only exercising them against a real PR, which is interactive and needs the user, not a plan-time step.
- The gh-dash config now ships in the `github` stow package, but this machine's live copy is still a plain file pending the post-merge restow described above — a second machine-local drift is possible if the migration step is skipped.
- Rejected: building an automated test harness for this Neovim config. The repository has never had one; that is a bigger, separate change outside this intent's scope.

## Proof

- `<leader>go` lists open pull requests → manual check, step 1 (no test file: no Lua test suite in this repository).
- Selecting a PR opens its overview with a file panel → manual check, step 2.
- Opening a changed file shows diff hunks → manual check, step 3.
- `<localleader>ca`/`<localleader>sa` add a comment/suggestion → keymap names confirmed against octo.nvim's real config (headless), step 4. Owed: manual run against a real PR.
- `<localleader>vs` starts and submits a review with approve/comment/request-changes → keymap names and submit-window keys confirmed against octo.nvim's real config (headless), step 5. Owed: manual run against a real PR (a GitHub write — the user's own action, not automated here).
- `C` in gh-dash opens the same PR in Octo → manual check, step 6.
- `<leader>gl` opens lazygit → manual check, step 7.
- `gh` is in `packages.conf` → `grep -n '^\s*gh$' packages.conf`, step 8.
- No telescope/fzf-lua added → `rg -i 'telescope|fzf-lua' neovim/`, step 9.

Per changed file: the Neovim and gh-dash config files gained plugin registrations, a keymap rename, and a config line — no new testable units. `install/utils.sh` gained `install_gh_extensions` and `gh_extension_is_installed`, which have no test — no function in that file does today, so this matches existing practice rather than a gap introduced here. No test setup needed.
