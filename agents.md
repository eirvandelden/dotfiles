# Dotfiles repository

Etienne's dotfiles: GNU Stow packages, each a top-level directory, linked into `~/` and `~/.config/`. The shared playbook is `agents/.agents/PLAYBOOK.md`; it loads once, from Etienne's home directory.

## Packages and stow

- Packages in `packages.conf`: `1password` `agents` `avante` `editor` `caddy` `claude` `codex` `conductor` `ghostty` `git` `github` `glow` `herdr` `lazygit` `markdownlint` `neovim` `node` `pumadev` `rex` `ruby` `rubocop` `rv` `secrets` `solargraph` `ssh` `tones` `vim` `yamllint` `zed` `zsh`.
- Skill sources live in `agents/.agents/skills/<name>/`. They link into `claude/.claude/skills/`.
- The private `dotfiles-work` overlay (`~/Developer/dotfiles-work`) installs into the `STOW_SHARED` packages file by file.
- Edit the source file in its package, never the link under `~/`. Never run `stow` or `stow -R` without an explicit request.

## Tests

- `bin/test` runs every `test/*_test.rb` in parallel. `bin/test test/<file>_test.rb` runs one file.
- `ruby claude/.claude/test/statusline_command_test.rb` runs the statusline test.

## Linters

- `lefthook.yml` runs these on commit: `rubocop` (config `rubocop/.rubocop.yml`), `shellcheck`, `shellcheck-zsh`, `yamllint` and `no-hardwrap` (markdownlint).

## More

Everything else: `agents/.agents/skills/dotfiles-maintenance/SKILL.md`.
