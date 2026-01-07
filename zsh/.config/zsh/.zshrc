# History, input
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=2000
SAVEHIST=$HISTSIZE

# Share history safely across multiple shells (including a secrets subshell)
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
# Optional: if you prefix a command with a space, don't write it to history
setopt HIST_IGNORE_SPACE

bindkey -e

# Completions
autoload -Uz compinit
compinit

# Prezto

# Load base config files and optional work overlays
for base in environment plugins aliases prompt; do
  [[ -f "$ZDOTDIR/$base.zsh" ]] && source "$ZDOTDIR/$base.zsh"
  [[ -f "$ZDOTDIR/${base}.work.zsh" ]] && source "$ZDOTDIR/${base}.work.zsh"
done

# function loader
for func in $ZDOTDIR/functions/*.zsh(N) $ZDOTDIR/functions/*.work.zsh(N); do
  source "$func"
done

# Greet the user 👋
if [[ -o interactive && -t 2 ]]; then
  [[ -f "$ZDOTDIR/login.zsh" ]] && source "$ZDOTDIR/login.zsh"
fi

# --- ensure squirrel prompt wins ---
source "$ZDOTDIR/prompt.zsh"
