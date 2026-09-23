# Review — octo-nvim-plugin

## Round 1 — 2026-09-23 08:15 UTC — a45adf66

Scope: `git diff origin/main...HEAD` (2 files, 15 insertions), working tree clean — no uncommitted changes on top. Policy source: `claude/.claude/skills/new-repo-setup/references/REVIEW.md`; the repository root has neither `REVIEW.md` nor `REVIEW.local.md`, so the reference copy's passes were used.

Currently green: `cspell lint neovim/.config/nvim/lua/plugins/octo.lua` reports 0 issues. The repository has no test suite for Lua config, so no suite was run.

- [ ] Important: octo.nvim shells out to the `gh` CLI (`command = "gh"` in the plugin's `lua/octo/utils.lua`), but `packages.conf` declares `gh` in no BREW, AUR, or APT list — only the `github` *stow* package, which ships `~/.config/gh/config.yml` and `hosts.yml`. A fresh machine therefore gets the gh configuration without the gh binary, and every `:Octo` command fails at runtime. The diff adds a consumer of an undeclared system dependency — `packages.conf` →
- [ ] Important: no change folder exists for this branch. `docs/changes/octo-nvim-plugin/` was absent before this review round, so there is no `intent.md`, `spec.md`, or `plan.md`. The compliance pass has nothing to check the diff against: no acceptance criterion to map to a test, no `## Proof` list to confirm. Playbook rule 17 requires an accepted `plan.md` before code is written, and rule 11 requires recorded approval before a dependency is added; this branch has neither — `docs/changes/octo-nvim-plugin/` →
- [ ] Nit: the plugin registers no `keys` block and no which-key entry, so it is reachable only by typing `:Octo`. A `<leader>g` "Git" group already exists in `which-key-extra.lua`, and `snacks.lua`, `flash.lua`, `mini-files.lua`, and `todo-comments.lua` all declare `keys` — `neovim/.config/nvim/lua/plugins/octo.lua:2` →
- [ ] Nit: the dictionary gains both `octo` and `Octo`, but `cspell.yml` never sets `caseSensitive`, so the lowercase entry already covers the capitalised spelling. The redundancy matches the file's existing pattern (`neovim`/`Neovim`, `edge`/`Edge`), so it is consistent rather than wrong — `project-dictionary.txt:89` →

Checked and clear: `picker = "snacks"` is a valid value — the installed plugin's `config.lua:625` validates against `{ "telescope", "fzf-lua", "snacks", "default" }`, and `snacks.nvim` is present with `picker = {}` enabled in `snacks.lua`. The `plenary.nvim` and `nvim-web-devicons` dependencies match the convention already used in `lualine.lua` and `ai.lua`. The `devicons` dictionary entry is required by this diff rather than unrelated scope: the cspell hook only began checking every staged file in `05244d5f`, after `lualine.lua` last landed. The tracked `github/.config/gh/hosts.yml` holds only `git_protocol`, `user`, and `users` keys — no token, so no secret is committed. Dictionary additions are correctly sorted; the one ordering break (`SDLC`, line 166) predates this branch.

Per the review policy, the missing `octo.nvim` entry in `lazy-lock.json` is not reported — generated lockfiles are out of scope.
