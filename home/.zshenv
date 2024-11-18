#
# Defines environment variables. Read by every zsh shell.
#
#

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ "$SHLVL" -eq 1 && ! -o LOGIN && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

# GPGP
export GPG_TTY=`tty`

# Node-build
export NODE_BUILD_DEFINITIONS="/opt/homebrew/opt/node-build-update-defs/share/node-build"

#
# chruby
#

source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh
chruby $(cat ~/.ruby-version)
source ~/.chruby-default-gems/chruby-default-gems.sh

# Use YJIT by default but don't clobber the existing +RUBYOPT+
# if one is already set.
if [[ -z "$RUBYOPT" ]]; then
    export RUBYOPT="--yjit"
else
    export RUBYOPT="$RUBYOPT --yjit"
fi

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
