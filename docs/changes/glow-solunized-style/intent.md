# Intent: Glow uses the Solunized style

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: feature. Delivery: autonomous.

## Problem

Glow renders Markdown with its built-in `auto` style. Those colours do not match Solunized, so Markdown in the terminal looks out of place next to every other themed app. The dotfiles do not manage glow's configuration at all: `~/Library/Preferences/glow/glow.yml` is a plain file with `style: auto`.

## Proposed outcome

A new `glow` stow package holds a copy of the Solunized glamour style that the solunized repository generates (`dist/glow/solunized.json`, change `glow-style`). An install step points the `style:` line of the live `glow.yml` at that file through the real home directory. Glow then uses the style everywhere and follows Ghostty's `solunized-light`/`solunized-dark` palette swap with the macOS appearance, with no switching code.

## Affected users and systems

- The maintainer, reading Markdown with glow in Ghostty on macOS.
- The dotfiles repository: a new `glow` stow package, the `STOW` list in `packages.conf`, and the install flow.
- The live `~/Library/Preferences/glow/glow.yml`. It stays a plain file; only its `style:` line changes.

## Constraints

- Glow 3.0.0 on macOS reads `~/Library/Preferences/glow/glow.yml`.
- Glow 3.0.0 finds a style file from every directory only through an absolute path. `~/…` and `$HOME/…` fail (probed in the plan stage). The dotfiles repository is public and must work for any home directory, so no hardcoded home path goes into the repository. The install step writes the absolute path from the real `$HOME`.
- Glow 3.0.0 ignores the values in a `--config` file (probed in the plan stage), so `glow --config` cannot prove the setup.
- Precedent: the dotfiles keep a committed copy of a generated theme, `zed/.config/zed/themes/solunized-theme.json`. The glow style follows that precedent. A solunized change means a manual re-copy.
- The solunized `glow-style` change is not implemented yet. Implement here waits until `dist/glow/solunized.json` exists and is committed on that branch (`/Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style`). Copy it from there; re-copy if its review changes the output.
- The dotfiles repository is public: no work references, and no secrets.
- Approved permission: create a new `glow` stow package (rule 12).
- Approved permission, after Etienne merges the pull request only: agents run `stow -t "$HOME" glow` and the new install step from the main checkout on this Mac, then verify plain `glow`. Stow links point at the directory stow runs from, so stowing from the worktree would leave dangling links.
- No new dependencies. Glow is already in `packages.conf`.

## In scope

- A `glow` stow package with `Library/Preferences/glow/solunized.json`, a committed copy of the generated style. No `glow.yml` in the package.
- `glow` in the `STOW` array of `packages.conf`, so a future `install.sh` run links it.
- A macOS install step, run by `install.sh`, that sets `style:` in `~/Library/Preferences/glow/glow.yml` to `$HOME/Library/Preferences/glow/solunized.json`, expanded to an absolute path. It keeps every other line of an existing file. It adds the `style:` line when the file has none. It creates the file with only that line when the file is missing. A second run changes nothing.
- Tests for the package and the install step, in the repository's existing test style.
- The delivery account lists the post-merge stow and install commands and their results.

## Out of scope

- Generating or changing the style. The solunized repository owns that.
- Managing glow's other settings (`mouse`, `pager`, `width`, `all`).
- Linux. Glow there reads `~/.config/glow/glow.yml`; this change does not configure it, and the install step does not run there. The shared `STOW` list may create an unused `~/Library/Preferences/glow` on Linux; that is accepted.
- Running `stow` or the install step on the live home directory before the pull request merges.
- Automatic sync of the copy with the solunized repository.

## Acceptance criteria

- The `glow` package holds `Library/Preferences/glow/solunized.json`, byte-identical to `dist/glow/solunized.json` from the solunized `glow-style` branch's generator. The package holds no `glow.yml`.
- `packages.conf` lists `glow` in the `STOW` array.
- With a `glow.yml` of `style: "auto"` and `width: 80`, the install step leaves `width: 80` and sets `style:` to `<HOME>/Library/Preferences/glow/solunized.json`, with the real home directory spelled out.
- With a `glow.yml` that has no `style:` line, the install step adds one and keeps the other lines.
- With no `glow.yml`, the install step creates one that holds only the `style:` line.
- Running the install step twice gives the same file as running it once.
- `glow -s glow/Library/Preferences/glow/solunized.json README.md` renders without a style error, using only palette colours 0–15.
- With a scratch home directory that holds the stowed style and an installed `glow.yml`, plain `glow README.md` run from another directory picks up the Solunized style.
- In Ghostty with macOS in light mode, `glow -s <worktree style> README.md` shows headings, links and code in Solunized light colours on the cream background. After a switch to dark mode, the same command shows them in Solunized dark colours on the blue-teal background. Etienne checks both before he approves the merge; the PR body gives the command.
- After merge, stow and the install step from the main checkout: `~/Library/Preferences/glow/solunized.json` is a symlink into the main dotfiles checkout, and plain `glow README.md` renders with the Solunized style.

## Flagged concerns

- Verification before merge versus a live config. Stowing from the worktree would let plain `glow` prove the setup before the PR, but its links dangle once the worktree goes. Chosen side: verify with `glow -s` and a scratch home directory before the PR; stow and run the install step from the main checkout after merge.
- A stowed, fully owned `glow.yml` versus a portable style path. A stowed `glow.yml` would need a hardcoded home path in a public repository. Chosen side: the install step edits only the `style:` line; the dotfiles do not own glow's other settings.

## Open questions

None.
