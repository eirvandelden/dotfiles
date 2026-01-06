# ~/.config/zsh/environment.zsh

export ZDOTDIR="$HOME/.config/zsh"
export RUBY_CONFIGURE_OPTS="--enable-yjit --with-jemalloc --disable-install-doc"

# Homebrew prefix (must be set before using it below)
# Prefer HOMEBREW_PREFIX if already set; otherwise infer it from common locations.
: "${HOMEBREW_PREFIX:=}"
if [[ -z "${HOMEBREW_PREFIX}" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    HOMEBREW_PREFIX="$("/opt/homebrew/bin/brew" --prefix)"
  elif [[ -x /usr/local/bin/brew ]]; then
    HOMEBREW_PREFIX="$("/usr/local/bin/brew" --prefix)"
  fi
  export HOMEBREW_PREFIX
fi

# Native extensions (Ruby gems, etc.)
# Append paths instead of overwriting so multiple deps can coexist.
export CPPFLAGS="-I$HOMEBREW_PREFIX/opt/jemalloc/include ${CPPFLAGS:-}"
export LDFLAGS="-L$HOMEBREW_PREFIX/opt/jemalloc/lib ${LDFLAGS:-}"

# OpenSSL (needed for gems like trilogy)
export OPENSSL_DIR="$HOMEBREW_PREFIX/opt/openssl@3"
export CPPFLAGS="-I$OPENSSL_DIR/include ${CPPFLAGS:-}"
export LDFLAGS="-L$OPENSSL_DIR/lib ${LDFLAGS:-}"
export PKG_CONFIG_PATH="$OPENSSL_DIR/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export DISABLE_SPRING=true
export PATH="$PATH:/Users/etienne.vandelden/.rd/bin:/Users/etienne.vandelden/.local/bin"

## SQLite3
# For compilers to find sqlite you may need to set:
export CPPFLAGS="-I$HOMEBREW_PREFIX/opt/sqlite/include ${CPPFLAGS:-}"
export LDFLAGS="-L$HOMEBREW_PREFIX/opt/sqlite/lib ${LDFLAGS:-}"

# For pkg-config to find sqlite you may need to set:
export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/opt/sqlite/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# configure ssh config file
export SSH_CONFIG_FILE="$HOME/.config/ssh/config"

# 1Password
# configure 1password ssh-agent to access configured keys
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# Add plugins (idempotent; prevents duplicate approval prompts when init files get sourced twice)
if [[ -z "${__OP_PLUGINS_LOADED:-}" ]]; then
  __OP_PLUGINS_LOADED=1
  export __OP_PLUGINS_LOADED

  if [[ -f "$HOME/.config/op/plugins.sh" ]]; then
    source "$HOME/.config/op/plugins.sh"
  fi
fi

# Ruby
## chruby setup
# source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
# source /opt/homebrew/opt/chruby/share/chruby/auto.sh
# chruby $(cat ~/.ruby-version 2>/dev/null)

## rv setup
eval "$(/opt/homebrew/bin/rv shell init zsh)"
eval "$(/opt/homebrew/bin/rv shell completions zsh)"

## Add trusted ./bin for safe projects
function set_local_bin_path() {
  export PATH="${1:-""}`echo "$PATH"|sed -e 's,[^:]*\.git/[^:]*bin:,,g'`"
}

function add_trusted_local_bin_to_path() {
  if [[ -d "$PWD/.git/safe" ]]; then
    set_local_bin_path "$PWD/.git/safe/../../bin:"
  fi
}

if [[ -n "$ZSH_VERSION" && "$preexec_functions" != *add_trusted_local_bin_to_path* ]]; then
  preexec_functions+=("add_trusted_local_bin_to_path")
fi

# Javascript
## chnode setup
source /opt/homebrew/opt/chnode/share/chnode/chnode.sh
source /opt/homebrew/opt/chnode/share/chnode/auto.sh
precmd_functions+=(chnode_auto)

# Add utilities from brew
export PATH="/opt/homebrew/opt/curl/bin:$PATH"

# Homebrew environment
# NOTE: Keep this near the end so brew-managed tools are available.
eval "$(/opt/homebrew/bin/brew shellenv)"
