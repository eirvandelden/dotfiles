# Zsh always loads .zshenv
# Point Zsh to ~/.config/zsh folder
export ZDOTDIR="$HOME/.config/zsh"

# Failsafe: ensure main config is loaded in interactive shells

source "$ZDOTDIR/zshenv"
[[ -o interactive ]] && source "$HOME/.zshrc"
