# Point Zsh to ~/.config/zsh folder
export ZDOTDIR="$HOME/.config/zsh"

# Source $ZDOTDIR/.zshenv explicitly to ensure it runs in both login and non-login shells.
# For login shells, zsh auto-loads $ZDOTDIR/.zshenv after reading ~/.zshenv, so there's no
# double-sourcing. For non-login shells (like Ghostty), setting ZDOTDIR in ~/.zshenv may be
# too late for zsh to auto-load $ZDOTDIR/.zshenv, so we source it explicitly here.
# This guard prevents double-sourcing in the unlikely event it's already been loaded.
if [[ -f "$ZDOTDIR/.zshenv" && -z "${ZDOTDIR_LOADED:-}" ]]; then
  export ZDOTDIR_LOADED=1
  source "$ZDOTDIR/.zshenv"
fi

# Note: Do NOT source .zshrc from here.
# When ZDOTDIR is set, zsh will load startup files from $ZDOTDIR automatically.
# Sourcing .zshrc again causes double-loading (and duplicate side effects like repeated 1Password prompts).
