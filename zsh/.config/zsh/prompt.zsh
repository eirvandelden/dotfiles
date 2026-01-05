# ~/.config/zsh/prompt.zsh

# Icons
GIT_ICON=""
GEM_ICON="💎"
NODE_ICON="⬢"
BOX_ICON="📦"
QUESTION_ICON="❓"
PROMPT_CHAR="🐿"

# Git info
git_info() {
  local branch status out
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  [[ -n "$branch" ]] && out="on $GIT_ICON $branch"

  local flags=""
  git diff --quiet --cached 2>/dev/null || flags+="$BOX_ICON"
  [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]] && flags+="$QUESTION_ICON"
  [[ -n "$flags" ]] && out+=" $flags"
  echo "$out"
}

# Ruby info
ruby_info() {
  [[ -n "$RUBY_VERSION" ]] && echo "via $GEM_ICON ruby-${RUBY_VERSION%%-*}"
}

# Node info (only if node is in use)
node_info() {
  [[ -f .nvmrc || -f .node-version || -d node_modules ]] || return
  command -v node >/dev/null || return
  echo "via $NODE_ICON node-$(node -v 2>/dev/null | sed 's/v//')"
}

# Enable prompt substitution
setopt PROMPT_SUBST

# Timing
typeset -gA TIMER

_get_timestamp() {
  if command -v gdate &>/dev/null; then
    gdate +%s%3N
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

preexec() {
  TIMER[cmd]=$(_get_timestamp)
}

# ── Battery (macOS; shows only if < 30 %) ────────────────────────────────
battery_info() {
  # macOS: pmset -g batt | awk '{print $3}' returns "84%;"
  local pct=$(pmset -g batt 2>/dev/null | awk '/%/{gsub(/%;/, ""); print $3}')
  [[ -z "$pct" ]] && return      # not a laptop / can't query
  (( pct < 30 )) && echo "%F{red}🔋${pct%%%}%f"
}

precmd() {
  local now=$(_get_timestamp)
  if [[ -n ${TIMER[cmd]} ]]; then
    local elapsed_ms=$((now - TIMER[cmd]))
    if ((elapsed_ms > 500)); then
      local elapsed_sec=$((elapsed_ms / 1000))
      TIMER[last]="took ${elapsed_sec}s"
    else
      TIMER[last]=""
    fi
  fi

  # 🔥 ALWAYS (re)set the prompt **after** everything else
  PROMPT=$'\n%F{green}%1~%f %F{yellow}$(git_info)%f %F{red}$(ruby_info)%f %F{242}$(node_info)%f $(battery_info) ${TIMER[last]}\n${PROMPT_CHAR} '
  PS1="$PROMPT"
}
