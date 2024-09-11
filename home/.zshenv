#
# Defines environment variables.
#
#

#MANUAL: brew completions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ "$SHLVL" -eq 1 && ! -o LOGIN && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

# GPGP
export GPG_TTY=`tty`

# source: https://dance.computer.dance/posts/2015/02/making-chruby-and-binstubs-play-nice.html
# Remove the need for bundle exec ... or ./bin/...
# by adding ./bin to path if the current project is trusted
function set_local_bin_path() {
  # Replace any existing local bin paths with our new one
  export PATH="${1:-""}`echo "$PATH"|sed -e 's,[^:]*\.git/[^:]*bin:,,g'`"
}

function add_trusted_local_bin_to_path() {
  if [[ -d "$PWD/.git/safe" ]]; then
    # We're in a trusted project directory so update our local bin path
    set_local_bin_path "$PWD/.git/safe/../../bin:"
  fi
}

# Make sure add_trusted_local_bin_to_path runs after chruby so we
# prepend the default chruby gem paths
if [[ -n "$ZSH_VERSION" ]]; then
  if [[ ! "$preexec_functions" == *add_trusted_local_bin_to_path* ]]; then
    preexec_functions+=("add_trusted_local_bin_to_path")
  fi
fi

# Node-build
export NODE_BUILD_DEFINITIONS="/opt/homebrew/opt/node-build-update-defs/share/node-build"

# Ruby YJIT support
export RUBYOPT=’--enable-yjit’
export RUBY_YJIT_ENABLE=1

## Copied here for Nova
#
# chruby
#

source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh
chruby $(cat ~/.ruby-version)
source ~/.chruby-default-gems/chruby-default-gems.sh

# chruby-default-gems
# enable chruby-default-gems: # https://github.com/bronson/chruby-default-gems
# DEFAULT_GEMFILE='~/.default-ruby-gems'
# source ~/.chruby-default-gems/chruby-default-gems.sh

#
# chnode
#
source /opt/homebrew/opt/chnode/share/chnode/chnode.sh
source /opt/homebrew/opt/chnode/share/chnode/auto.sh
precmd_functions+=(chnode_auto)  # if using Zsh
