# TODO: BROKEN!
# ~/.config/zsh/logout.zsh

[[ -o INTERACTIVE && -t 2 ]] || return

local -a groups=("classic" "scifi" "existential" "dev")
local group=${groups[RANDOM % ${#groups[@]}]}

case $group in
  scifi)
    quotes=(
      "Live long and log out.\n --Spock"
      "Resistance is futile.\n --Borg"
      "I'll be back.\n --Terminator"
      "Goodbye, and thanks for all the fish.\n --Douglas Adams"
      "The force will be with you, always.\n --Obi-Wan Kenobi"
      "Just when I thought I was out... they pull me back in.\n --Michael Corleone"
      "Hasta la vista, baby.\n --Terminator"
      "Game over, man. Game over!\n --Private Hudson"
      "Why so serious?\n --The Joker"
      "You have died of dysentery.\n --Oregon Trail"
    )
    COLOR=36 EMOJI="🛸"
    ;;
  existential)
    quotes=(
      "Time is an illusion. Logout doubly so.\n --Douglas Adams"
      "Exit status: 0 (success, allegedly)"
      "This shell is clean. This shell is pure. This shell... is gone."
      "You either die a hero, or live long enough to see your shell profile rewritten.\n --Harvey Dent"
      "Everything not saved will be lost.\n --Nintendo quit screen"
      "Nothing ever ends.\n --Dr. Manhattan"
    )
    COLOR=33 EMOJI="🧠"
    ;;
  dev)
    quotes=(
      "Semicolons are optional. Goodbyes aren't."
      "sudo logout"
      "exit(0);"
      "return to sender."
      "Goodbye, world."
      "Commit, push, peace out."
      "⌘Q achieved."
    )
    COLOR=32 EMOJI="💻"
    ;;
  classic|*)
    quotes=(
      "Only at the end do you realize the power of the Dark Side.\n --Darth Sidious"
      "I find your lack of faith disturbing.\n --Darth Vader"
      "The circle is now complete.\n --Darth Vader"
      "Fatality.\n --Shang Tsung"
    )
    COLOR=31 EMOJI="💀"
    ;;
esac

local index=$((RANDOM % ${#quotes[@]}))
local quote=${quotes[index]}

# force print to terminal (stderr might be closed too soon)
[[ -t 1 ]] && {
  print -P "\033[1;${COLOR}m$quote ${EMOJI}\033[0m" > /dev/tty
  sleep 0.1
  print -n '' > /dev/tty
}
