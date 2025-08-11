# ~/.config/zsh/environment.zsh

export ZDOTDIR="$HOME/.config/zsh"
export RUBY_CONFIGURE_OPTS="--enable-yjit --with-jemalloc --disable-install-doc"
export CPPFLAGS="-I$HOMEBREW_PREFIX/opt/jemalloc/include"
export LDFLAGS="-L$HOMEBREW_PREFIX/opt/jemalloc/lib"

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export DISABLE_SPRING=true
export PATH="$PATH:/Users/etienne.vandelden/.rd/bin:/Users/etienne.vandelden/.local/bin"

## SQLite3
# For compilers to find sqlite you may need to set:
export LDFLAGS="-L/opt/homebrew/opt/sqlite/lib"
export CPPFLAGS="-I/opt/homebrew/opt/sqlite/include"

# For pkg-config to find sqlite you may need to set:
export PKG_CONFIG_PATH="/opt/homebrew/opt/sqlite/lib/pkgconfig"

# configure ssh config file
export SSH_CONFIG_FILE="$HOME/.config/ssh/config"

# 1Password
# configure 1password ssh-agent to access configured keys
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
## Add plugins
source /Users/etienne.vandelden/.config/op/plugins.sh

# Ruby
## chruby setup
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh
chruby $(cat ~/.ruby-version 2>/dev/null)

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
eval "$(/opt/homebrew/bin/brew shellenv)"
