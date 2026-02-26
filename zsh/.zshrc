# Point Zsh to ~/.config/zsh folder
export ZDOTDIR="$HOME/.config/zsh"

# Intentionally do NOT source "$ZDOTDIR/.zshrc" from here.
# When ZDOTDIR is set, zsh will load startup files from $ZDOTDIR automatically.
# Sourcing again causes double-loading (and duplicate side effects like repeated 1Password prompts).

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/etienne.vandelden/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
