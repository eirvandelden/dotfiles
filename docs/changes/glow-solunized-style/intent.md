# Intent: Glow uses the Solunized style

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: feature. Delivery: autonomous.

## Problem

Glow renders Markdown with its built-in `auto` style. Those colours do not match Solunized, so Markdown in the terminal looks out of place next to every other themed app. The dotfiles do not manage glow's configuration at all: `~/Library/Preferences/glow/glow.yml` is a plain file with `style: auto`.

## Proposed outcome

A new `glow` stow package holds glow's configuration and a copy of the Solunized glamour style that the solunized repository generates (`dist/glow/solunized.json`, change `glow-style`). Once stowed, glow uses that style everywhere. Glow then follows Ghostty's `solunized-light`/`solunized-dark` palette swap with the macOS appearance, with no switching code.

## Affected users and systems

- The maintainer, reading Markdown with glow in Ghostty on macOS.
- The dotfiles repository: a new `glow` stow package and the `STOW` list in `packages.conf`.
- The live `~/Library/Preferences/glow/glow.yml`, which the package replaces after merge.

## Constraints

- Glow 3.0.0 on macOS reads `~/Library/Preferences/glow/glow.yml`. `glow --config <file>` reads another file.
- Precedent: the dotfiles keep a committed copy of a generated theme, `zed/.config/zed/themes/solunized-theme.json`. The glow style follows that precedent. A solunized change means a manual re-copy.
- The solunized `glow-style` change is not merged yet. Copy the style from the generator output on that branch (`/Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style`). Re-copy if its review changes the output.
- The `style:` path in `glow.yml` must resolve no matter which directory glow runs in.
- The dotfiles repository is public: no work references, and no secrets.
- Approved permission: create a new `glow` stow package (rule 12).
- Approved permission, after Etienne merges the pull request only: `trash ~/Library/Preferences/glow/glow.yml`, then `stow -t "$HOME" glow` from the main checkout. Stow links point at the directory stow runs from, so stowing from the worktree would leave dangling links.
- No new dependencies. Glow is already in `packages.conf`.

## In scope

- A `glow` stow package with `Library/Preferences/glow/glow.yml`. It keeps today's values (`mouse: false`, `pager: false`, `width: 80`, `all: false`) and sets `style:` to the Solunized style.
- A committed copy of `solunized.json` in that package.
- `glow` in the `STOW` array of `packages.conf`, so a future `install.sh` run links it.
- Tests for the package, in the repository's existing test style.
- The delivery account lists the post-merge trash and stow commands.

## Out of scope

- Generating or changing the style. The solunized repository owns that.
- Linux. Glow there reads `~/.config/glow/glow.yml`; this change does not configure it. The shared `STOW` list may create an unused `~/Library/Preferences/glow` on Linux; that is accepted.
- Running `stow` or trashing the live `glow.yml` before the pull request merges.
- Automatic sync of the copy with the solunized repository.

## Acceptance criteria

- The `glow` package holds `Library/Preferences/glow/glow.yml` with `mouse: false`, `pager: false`, `width: 80`, `all: false`, and a `style:` that names the Solunized style.
- The package's `solunized.json` is byte-identical to `dist/glow/solunized.json` from the solunized `glow-style` branch's generator.
- `glow --config glow/Library/Preferences/glow/glow.yml README.md`, run from the repository root and again from another directory, renders without a style error.
- In Ghostty with macOS in light mode, that command shows headings, links and code in Solunized light colours on the cream background.
- After a switch to dark mode, the same command, with no config change, shows them in Solunized dark colours on the blue-teal background.
- `packages.conf` lists `glow` in the `STOW` array.
- After merge, trash and stow from the main checkout: plain `glow README.md` renders with the Solunized style, and `~/Library/Preferences/glow/glow.yml` is a symlink into the main dotfiles checkout.

## Flagged concerns

- Verification before merge versus a live config. Stowing from the worktree would let plain `glow` prove the setup before the PR, but its links dangle once the worktree goes. Chosen side: verify with `--config` before the PR; trash and stow from the main checkout after merge.

## Open questions

None.
