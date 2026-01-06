# Point Zsh to ~/.config/zsh folder
export ZDOTDIR="$HOME/.config/zsh"

# Intentionally do NOT source "$ZDOTDIR/.zshenv" from here.
# When ZDOTDIR is set, zsh will load startup files from $ZDOTDIR automatically.
# Sourcing again causes double-loading (and duplicate side effects like repeated 1Password prompts).
