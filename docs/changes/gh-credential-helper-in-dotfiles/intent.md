# Intent: Git credentials come from 1Password, set in the dotfiles config

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

`~/.gitconfig` is a machine-local file that `gh auth setup-git` created on 2026-09-08. It holds two things: `pull.rebase = true`, which the dotfiles git config (`git/.config/git/config`) already sets, and gh as the credential helper for `https://github.com` and `https://gist.github.com`.

Because the file exists, `git config --global` reads only `~/.gitconfig` and never the dotfiles config at `~/.config/git/config`. Lefthook asks git with `--global` whether a global `core.hooksPath` is set, sees none, and so its own refusal to write into the global hooks directory does not work. PR #168 stopped the dotfiles `lefthook.yml` from syncing hooks, but a repository with its own lefthook config can still replace the global hooks while `~/.gitconfig` exists.

The gh helper is the only thing in `~/.gitconfig` that exists nowhere else. It also reads from the macOS Keychain: gh keeps its token there (`gh auth status`: "Logged in to github.com account eirvandelden (keyring)"). The dotfiles config itself names `osxkeychain` as the credential helper for every host. 1Password is the only vault Etienne accepts for credentials; the Keychain is not acceptable as a source or as a fallback.

## Proposed outcome

- Git gets GitHub HTTPS credentials (`github.com`, `gist.github.com`) from 1Password: the `token` field of the item `Github` in vault `Familie`, read with `op read "op://Familie/Github/token"`, and sent to git as username `x-access-token` with that token as password.
- The dotfiles git config sets this up, so `~/.gitconfig` holds nothing that is needed.
- No credential helper reads the macOS Keychain: `osxkeychain` is gone from the dotfiles config for every host.
- After merge, Etienne removes `~/.gitconfig`. `git config --global core.hooksPath` then answers `~/.config/git/hooks`, and lefthook's own refusal to write into the global hooks directory works again.

## Affected users and systems

- Etienne, on every machine that stows the `git` package (macOS and Debian/Arch Linux per `install.sh`).
- HTTPS access to GitHub from git: HTTPS clones and fetches, HTTPS git gems in Gemfiles. SSH remotes (`git@github.com:`) are not affected; they use the 1Password SSH agent already.
- HTTPS access to any other host: no credential helper answers any more, so git asks in the terminal (or fails without one).
- Lefthook's global hooks-path check (PR #168).

## Constraints

- The dotfiles repository is public. The 1Password reference `op://Familie/Github/token` is in it by Etienne's decision (2026-10-06): the reference only names the item; reading it still needs Etienne's unlocked 1Password account.
- No token or other secret in the repository, in tests, or in test output.
- 1Password's gh shell plugin (`op plugin run -- gh …`) cannot be the mechanism: it needs an interactive terminal and fails under git with `interactive IO not available` (tested 2026-10-02). `op read` works without a terminal (tested 2026-10-02).
- No new dependency installed by the agent (playbook rule 11); `op` is already on this machine.
- No `stow`, no removal of `~/.gitconfig`, no change to 1Password items by the agent; Etienne does those.
- Once `~/.gitconfig` is gone, `gh auth setup-git` and any `git config --global` write go into `~/.config/git/config`, a link into the dotfiles repository.

## In scope

- `git/.config/git/config`: a credential helper for `https://github.com` and `https://gist.github.com` that answers git's `get` request from `op read "op://Familie/Github/token"`; removal of `credential.helper = osxkeychain`.
- Tests at the repository root (`test/*_test.rb`, run by CI) that exercise the helper through real `git credential fill` with a stub `op` on `PATH`.

## Out of scope

- Creating or rotating the GitHub token, or moving it to another vault (Etienne, by hand).
- Removing `~/.gitconfig`, `gh auth logout`, running `stow` (Etienne, after merge).
- Adding `op` or `gh` to `packages.conf`.
- Credentials for hosts other than GitHub.
- Guarding `~/.config/git/config` against `git config --global` writes.
- `.github/workflows/`.

## Acceptance criteria

1. Asking git for `https://github.com` credentials returns username `x-access-token` and the token that `op read "op://Familie/Github/token"` gives.
2. Asking git for `https://gist.github.com` credentials returns the same.
3. When git stores or erases a GitHub credential, the helper does nothing and 1Password is not asked.
4. When `op read` fails (1Password locked or item missing), git gets no GitHub password from any other source.
5. Asking git for credentials for another HTTPS host (for example `https://gitlab.com`) gets nothing from any helper.
6. The dotfiles git config names no `osxkeychain` helper.
7. On Etienne's machine, after a valid token is in the item, a GitHub API request made with the token git receives answers `200` with login `eirvandelden` (manual check, token not printed).

## Flagged concerns

- The item lives in the shared vault `Familie`, so everyone with access to that vault can read the GitHub token. Etienne chose this item; moving it is out of scope.
- The token currently in the item is rejected by GitHub (`401`, tested 2026-10-02). Criterion 7 waits until Etienne puts a new token in the item.

## Open questions

None.
