#
# Executes commands at login post-zshrc.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Execute code that does not affect the current session in the background.
{
  # Compile the completion dump to increase startup speed.
  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
  if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
    zcompile "$zcompdump"
  fi
}

# Print a random, hopefully interesting, adage.
# Execute code only if STDERR is bound to a TTY.
[[ -o INTERACTIVE && -t 2 ]] && {

WELCOMES=(
    "Grrreetings! I am the High Sycophant\n  --Kobold Sycophant of the Red Dragon"
    "Deekin?\n --Deekin"
    "Input!\n --Johnny 5"
    "Ready are you? What know you of ready? For eight hundred years have I trained Jedi. My own counsel will I keep on who is to be trained. A Jedi must have the deepest commitment, the most serious mind. This one, a long time have I watched. All his life has he looked away… to the future, to the horizon. Never his mind on where he was. …Hmm? On what he was doing.\n --Yoda"
    "'I’m Luke Skywalker? I’m here to rescue you!' '…You’re who?' \n  --Princess Leia"
    "Power! UNLIMITED … POWER!⚡️ \n  --Darth Sidious"
    "Do. Or do not. There is no try.\n --Yoda"
    "An army of squirrels, is still an army.\n --Squirrel Mob"
)

# Print a randomly-chosen message:
echo $WELCOMES[$(($RANDOM % ${#WELCOMES} + 1))]

} >&2


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

