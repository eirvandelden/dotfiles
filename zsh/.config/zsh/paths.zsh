# paths.zsh — single source of truth for PATH construction.
# All PATH modifications go here. rv comes after every other tool; only the
# unlocked codex shim (step 6) goes after it, since that directory holds only codex.
#
# Sourced from .zshenv so it runs for every shell type, including
# non-interactive shells used by editors, IDEs, and AI coding agents.

# 0. Ensure standard system paths are always present.
# Non-login shells (Conductor, editors, CI) may start with a stripped PATH.
path=(/usr/local/bin /usr/bin /bin /usr/sbin /sbin "${path[@]}")

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

# Hook helper is needed here because paths.zsh is sourced from .zshenv.
autoload -Uz add-zsh-hook

# 4. rv (Ruby version manager) — MUST come after every other tool (step 6 adds
# only the codex shim).
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
# Node version rule, first match wins (deliberately not chnode_auto's, which
# lets ~/.node-version replace the node a parent shell passed down):
#   1. the nearest .node-version above $PWD that is not ~/.node-version
#   2. the CHNODE_ROOT this shell inherited from its parent
#   3. ~/.node-version
# .zprofile puts the selected node back ahead of Homebrew's after path_helper.
if [[ -f "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/chnode/share/chnode/chnode.sh" ]]; then
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/chnode/share/chnode/chnode.sh"
  # chnode.sh already dropped a root it does not know. Not exported: a child
  # shell inherits this shell's current CHNODE_ROOT instead.
  typeset -g _inherited_chnode_root="${CHNODE_ROOT:-}"
  typeset -g _applied_node_source=""

  # Sets REPLY to the nearest project .node-version, if any. No subshell, so
  # the per-prompt hook stays cheap. -ef: $PWD may spell HOME differently.
  function _chnode_project_file() {
    local dir="$PWD"
    REPLY=""
    while true; do
      if [[ -r "$dir/.node-version" && ! "$dir/.node-version" -ef "$HOME/.node-version" ]]; then
        REPLY="$dir/.node-version"
        return 0
      fi
      [[ -z "$dir" || "$dir" == "/" ]] && return 1
      dir="${dir%/*}"
    done
  }

  # Sets reply to (source, chnode argument) for the rule above.
  function _chnode_wanted_node() {
    local file version
    reply=()
    if _chnode_project_file; then
      file="$REPLY"
    elif [[ -n "$_inherited_chnode_root" ]]; then
      reply=("inherited:$_inherited_chnode_root" "${_inherited_chnode_root##*/}")
      return 0
    else
      file="$HOME/.node-version"
    fi
    [[ -r "$file" ]] || return 1
    read -r version < "$file"
    version="${version//[[:space:]]/}" # a CRLF file leaves a trailing \r
    version="${version#v}"
    [[ -n "$version" ]] && reply=("$file:$version" "$version")
  }

  # A manual `chnode X` stays until the version source changes. The helpers
  # write REPLY and reply; the locals keep the shell's own values intact.
  function apply_default_node_version() {
    local REPLY
    local -a reply
    _chnode_wanted_node || return 0
    [[ "${reply[1]:-}" == "$_applied_node_source" ]] && return 0
    [[ -n "${reply[2]:-}" ]] || return 0

    _applied_node_source="${reply[1]}"
    chnode "${reply[2]}"
  }

  apply_default_node_version
  add-zsh-hook chpwd apply_default_node_version
fi

# 6. After `unlock`, its codex shim goes first (see functions/secrets.zsh), so a
# nested `codex` starts sessions off the shared daemon. .zprofile does this
# again after macOS path_helper reorders PATH in login shells.
if [[ -n "${UNLOCKED_BIN:-}" && -x "$UNLOCKED_BIN/codex" ]]; then
  path=("$UNLOCKED_BIN" "${path[@]}") # .zshenv sets typeset -U path
fi
