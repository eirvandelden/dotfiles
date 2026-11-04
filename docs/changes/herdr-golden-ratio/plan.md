# Plan: Golden ratio in herdr and Neovim

From `intent.md` (2026-11-04). Status: accepted.

## Design

### Domain terms

No new terms. "Auto mode" is the plugin's own `auto = true` setting. "Golden ratio" is the plugin's 0.618 setting: the share of the tab the focused pane gets on each axis, set through all its ancestor splits.

### Diagrams

Not affected: configuration only, no objects.

### Signatures

Not affected: no Ruby code.

Checked by: steep check

### Complexity

Not affected: no code path. The herdr hook spawns one process per focus change; the plugin debounces it (`debounce_ms = 120`).

### Invariants

Not affected: no invariant to enforce.

### Alternatives

- Bind a herdr key to the `apply` action for a manual re-balance. Rejected: the intent puts it out of scope, and auto mode replaces it.
- Use a Lua golden-ratio plugin for Neovim. Rejected: the herdr plugin cites the Vim plugin `roman/golden-ratio`, and it runs in Neovim as is.

## Design decisions

- The plugin id is `vv.golden-ratio`, so its config lives at `herdr/.config/herdr/plugins/config/vv.golden-ratio/config.toml`. The intent wrote `herdr-golden-ratio/config.toml`; `herdr plugin config-dir vv.golden-ratio` confirms the id path. This corrects a path, not a behaviour.
- `roman/golden-ratio` is a Vim script plugin with no `setup()`. The lazy.nvim spec holds only the repository name, no `opts`. A bare spec with `opts = {}` would call a missing `setup`.
- `lazy = false` is the repository default, so the plugin loads at start and needs no `event`.
- The lockfile entry comes from `:Lazy sync` in a real Neovim run, not from hand-written text. Commit `636b8a1e` is the current head of `roman/golden-ratio` and must match the lockfile.

## Integration points

- herdr loads plugin settings from `~/.config/herdr/plugins/config/vv.golden-ratio/config.toml`, a stow link into the `herdr` package.
- lazy.nvim imports every file under `lua/plugins/` and records commits in `lazy-lock.json`.

## Files that change

- `herdr/.config/herdr/plugins/config/vv.golden-ratio/config.toml` — new; `auto = true`, commented like the file-viewer config.
- `herdr/.config/herdr/README.md` — new section: what the plugin does, install command, Go 1.24+ need, herdr 0.9.1+ for auto mode.
- `neovim/.config/nvim/lua/plugins/golden-ratio.lua` — new; the `roman/golden-ratio` spec.
- `neovim/.config/nvim/lazy-lock.json` — new `golden-ratio` entry.

## Order of work

1. Write `config.toml` with `auto = true`. Run the check below.
2. Add the README section.
3. Add `golden-ratio.lua`.
4. Run Neovim against the worktree config with disposable paths: create a scratch dir `$S`, link `$S/config/nvim` to the worktree's `neovim/.config/nvim`, then run `XDG_CONFIG_HOME=$S/config XDG_DATA_HOME=$S/data XDG_STATE_HOME=$S/state XDG_CACHE_HOME=$S/cache nvim --headless "+Lazy! install" +qa`. `install` clones every plugin at its locked commit and clones the new one at head, so only `golden-ratio` is added to `lazy-lock.json`. Check the diff adds that one entry.
5. Verify the window behaviour in a headless Neovim run with the same four paths, as below.
6. Lint the touched files: `stylua --check`, `markdownlint`, and the repository's TOML and YAML linters where they apply.

## Risks

- `Lazy install` on a fresh data tree may still rewrite other lockfile lines. Mitigation: check the diff; if other lines change, restore them, since a fresh install at locked commits matches them.
- The herdr plugin does nothing until installed, and Go is missing. The README says so. The config is inert until then.
- `roman/golden-ratio` resizes on `WinEnter`. Plugins that open floating or sidebar windows may resize oddly. Out of scope; the intent forbids tuning.

## Proof

- The plugin config file sets `auto = true` → check: `grep -n '^auto = true$' herdr/.config/herdr/plugins/config/vv.golden-ratio/config.toml`
- The herdr README tells how to install the plugin → check: `grep -n 'herdr plugin install vigneshwerv/herdr-golden-ratio' herdr/.config/herdr/README.md`
- Starting Neovim loads `roman/golden-ratio` without error → check: `nvim --headless -c 'lua assert(vim.g.loaded_golden_ratio == 1 or vim.fn.exists(":GoldenRatioToggle") == 2)' -c qa` exits 0.
- A new Neovim split makes the focused window larger → check: headless Neovim opens a vertical split, runs `:GoldenRatioResize`, and prints `winwidth` for both windows; the focused one is wider.

Per changed file, the unit tests expected: none. This change is configuration, and configuration has no tests.

Test setup: none.

---
Domain skills applied: None.

## Critique

### Round 1 (Codex terra)

- Step 4 runs `nvim` against `~/.config/nvim`, the main checkout, so it cannot load the worktree spec → fixed (step 4 and 5 now use isolated XDG config, data, state and cache paths with the config linked to the worktree)
- `Lazy! sync` updates every plugin and rewrites all locks, so restoring lines leaves them inconsistent → fixed (step 4 uses `Lazy! install` on a disposable data tree, which keeps locked commits)
- The design calls 0.618 a split ratio, but the plugin treats it as the focused pane's share per axis through all ancestor splits → fixed (domain terms now describe it that way)
  - The suggested nested-split check is dismissed: it tests herdr plugin behaviour, which this repository does not own.
