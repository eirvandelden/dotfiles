# paths.zsh — single source of truth for PATH construction.
# All PATH modifications go here. rv is last.
#
# Sourced from .zshenv so it runs for every shell type, including
# non-interactive shells used by editors, IDEs, and AI coding agents.

# 1. Homebrew — must come first so later tools can rely on HOMEBREW_PREFIX.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# 2. Extra PATH entries
export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PATH="$PATH:$HOME/.rd/bin:$HOME/.local/bin" # .rd = Rancher Desktop

# 3. SSL certificate configuration (depends on HOMEBREW_PREFIX from step 1)
export SSL_CERT_FILE="$HOMEBREW_PREFIX/etc/openssl@3/cert.pem"

# 4. rv (Ruby version manager) — MUST be last.
# rv shell init prepends Ruby paths to PATH, so anything added after this
# would end up ahead of Ruby and break version management.
if [[ -x "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" ]]; then
  eval "$("${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" shell init zsh)"
  # rv's built-in init uses `preexec` which doesn't fire in non-interactive
  # shells (editors, AI agents, CI). Adding `chpwd` ensures rv re-evaluates
  # .ruby-version whenever the working directory changes.
  add-zsh-hook chpwd _rv_autoload_hook
fi

# 5. chnode (Node version manager) — mirrors the rv pattern above.
# Sourced here so non-interactive shells (editors, AI agents, CI) also
# get the correct Node version on startup and on directory change.
if [[ -f "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/chnode/share/chnode/chnode.sh" ]]; then
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/chnode/share/chnode/chnode.sh"
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/chnode/share/chnode/auto.sh"
  chnode_auto
  add-zsh-hook chpwd chnode_auto
fi
