export ZDOTDIR="$HOME/.config/zsh"

# Set default browser for macOS
if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi

# Editors
[ -z "$EDITOR" ] && export EDITOR='e'
export VISUAL='nano'
export PAGER='less'

# Language
if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

# Default path to open
export START="$HOME/Developer"
if [[ "$PWD" == "$HOME" ]]; then
  cd "$START"
fi

# Ensure path arrays do not contain duplicates
typeset -gU cdpath fpath mailpath path

# Less
export LESS='-F -g -i -M -R -S -w -X -z-4'

# Try both `lesspipe` and `lesspipe.sh` as either might exist
if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

# TMPDIR fallback
if [[ ! -d "$TMPDIR" ]]; then
  export TMPDIR="/tmp/$LOGNAME"
  mkdir -p -m 700 "$TMPDIR"
fi

TMPPREFIX="${TMPDIR%/}/zsh"

# GPG agent
export GPG_TTY=$(tty)

# Node-build definitions path
export NODE_BUILD_DEFINITIONS="/opt/homebrew/opt/node-build-update-defs/share/node-build"

# Prompt is intentionally loaded from `.zshrc` only to avoid double-loading.
# (Both `.zshenv` and `.zshrc` can be sourced during startup depending on shell type.)
