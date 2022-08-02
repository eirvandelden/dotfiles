#
# chruby
#

source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh
chruby $(cat ~/.ruby-version)

# chruby-default-gems
# enable chruby-default-gems: # https://github.com/bronson/chruby-default-gems
# DEFAULT_GEMFILE='~/.default-ruby-gems'
# source ~/.chruby-default-gems/chruby-default-gems.sh

#
# chnode
#
source /opt/homebrew/opt/chnode/share/chnode/chnode.sh
source /opt/homebrew/opt/chnode/share/chnode/auto.sh
PROMPT_COMMAND=chnode_auto       # if using Bash
# precmd_functions+=(chnode_auto)  # if using Zsh
