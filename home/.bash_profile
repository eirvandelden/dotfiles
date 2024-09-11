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
PROMPT_COMMAND=chnode_auto       # if using Bash
# precmd_functions+=(chnode_auto)  # if using Zsh
chnode $(cat ~/.node-version)

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/etienne.vandelden/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
