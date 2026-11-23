# A herdr-app core started from an agent shell leaks the agent git include into every terminal.
# Etienne's own shells keep his git config, so drop a leaked include (see git/.config/git/agent/).
case "${GIT_CONFIG_VALUE_0:-}" in
  */git/.config/git/agent/claude.config | */git/.config/git/agent/codex.config)
    unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
    ;;
esac

# History, input
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=2000
SAVEHIST=$HISTSIZE

# Append each command immediately so history is persisted per-session
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

# Change to Developer directory only if starting from home
# This respects directories passed by parent processes (like Conductor)
if [[ "$PWD" == "$HOME" || "$PWD" == "/" ]]; then
  cd ~/Developer 2>/dev/null || true
fi
