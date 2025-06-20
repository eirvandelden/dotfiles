# ~/.config/zsh/login.zsh

# Show a themed welcome quote on interactive terminals
[[ -o INTERACTIVE && -t 2 ]] || return

local -a groups=("starwars" "absurd" "dramatic" "inspirational")
local selected_group=${groups[RANDOM % ${#groups} + 1]}

case $selected_group in
  starwars)
    quotes=(
      "Ready are you? What know you of ready? …\n --Yoda"
      "'I’m Luke Skywalker!' '...You’re who?'\n --Leia"
      "Power! UNLIMITED … POWER!⚡️\n --Sidious"
      "Do. Or do not. There is no try.\n --Yoda"
    )
    COLOR=36 EMOJI="🌌"
    ;;
  absurd)
    quotes=(
      "An army of squirrels, is still an army.\n --Squirrel Mob"
      "Deekin?\n --Deekin"
      "Sudo make me a sandwich.\n --xkcd"
    )
    COLOR=35 EMOJI="🌀"
    ;;
  dramatic)
    quotes=(
      "All systems nominal. Awaiting orders.\n --MechWarrior"
      "The cake is a lie.\n --GLaDOS"
      "Today is a good day to code.\n --Worf"
    )
    COLOR=31 EMOJI="🔥"
    ;;
  inspirational)
    quotes=(
      "Stay awhile, and listen.\n --Deckard Cain"
      "Don't panic.\n --Douglas Adams"
      "Welcome, curious mind.\n --CLI Muse"
    )
    COLOR=32 EMOJI="💡"
    ;;
esac

local index=$((RANDOM % ${#quotes[@]}))
local quote=${quotes[index]}
print -P "\033[1;${COLOR}m$quote ${EMOJI}\033[0m" >&2
