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
} &!

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
    "Good morning! And in case I don't see ya, good afternoon, good evening and goodnight.\n  --Truman Burbank"
)

# Print a randomly-chosen message:
echo $WELCOMES[$(($RANDOM % ${#WELCOMES} + 1))]

} >&2


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
