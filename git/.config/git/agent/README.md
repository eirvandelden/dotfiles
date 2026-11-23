# Agent git setup

Claude Code and Codex commit and push to personal repositories with no 1Password prompt.

Every agent process carries one git include (`GIT_CONFIG_*`, set in `claude/.claude/settings.json` and `codex/.codex/config.toml`). The include loads the files in this directory only when a repository has a remote under `eirvandelden/` or `eirvandelden-dev/`. Every other repository keeps Etienne's own git config.

## One-time setup

Etienne does these steps once. Claude never reads, prints or logs a token or the private key.

1. Create the agent signing key, with no passphrase, outside every repository:

   ```sh
   mkdir -p ~/.local/state/agent-git
   ssh-keygen -t ed25519 -N '' -C 'agent signing key' -f ~/.local/state/agent-git/signing_key
   chmod 600 ~/.local/state/agent-git/signing_key
   ```

2. Register `~/.local/state/agent-git/signing_key.pub` on GitHub as a **signing key** only (Settings, SSH and GPG keys, New SSH key, key type "Signing Key"). Never register it as an authentication key.
3. Add the public key to `git/.config/git/allowed_signers` as `etienne@vandelden.family namespaces="git" <contents of signing_key.pub>`.
4. Create two fine-grained personal access tokens, each with an expiry date: one with resource owner `eirvandelden`, one with resource owner `eirvandelden-dev`. Each has repository access to all repositories of its owner and the permission "Contents: Read and write".
5. Store each token in the login Keychain. The command prompts for the token, so it never reaches shell history:

   ```sh
   security add-generic-password -s agent-git-github -a eirvandelden -T /usr/bin/security -w
   security add-generic-password -s agent-git-github -a eirvandelden-dev -T /usr/bin/security -w
   ```

6. Protect `main` on every personal repository: run `bin/protect-main` for the report, then `bin/protect-main --apply <owner>/<repo>` for each repository that is not `protected`.
7. Restow the `git`, `claude`, `codex` and `zsh` packages.

## Renew an expired token

Create a new token with the same scope. Replace the Keychain item: `security add-generic-password -U -s agent-git-github -a <owner> -T /usr/bin/security -w`.

## Files

- `claude.config`, `codex.config`: the personal gate, one `includeIf` per owner and URL form.
- `claude-identity.config`, `codex-identity.config`: author, committer and `Co-Authored-By` of one tool.
- `personal.config`: signing, the HTTPS rewrite, the credential helpers and the agent hooks.
- `ssh-sign`: the signer. It names a missing signing key and never asks the SSH agent.
- `credential-keychain`: the credential helper. It names a missing or rejected token and never falls back to 1Password.
- `origin-check`, `no-private-keys`, `co-authored-by`: the agent hooks.

## When it fails

- `agent signing key missing: <path>`: step 1.
- `no agent token for <owner>`: step 5.
- `GitHub rejected the agent token for <owner>`: renew the token.
- `origin is not a personal repository`: the agent configuration only commits and pushes where `origin` is personal.
