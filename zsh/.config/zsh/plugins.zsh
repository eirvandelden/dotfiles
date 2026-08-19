# ~/.config/zsh/plugins.zsh

if [[ "$TERM_PROGRAM" == "Apple_Terminal" || "$TERM_PROGRAM" == "iTerm.app" || "$TERM_PROGRAM" == "ghostty" ]]; then
  [[ -f "$HOME/.zsh-notify/notify.plugin.zsh" ]] && source "$HOME/.zsh-notify/notify.plugin.zsh"
fi
zstyle ':notify:*' notifier /opt/homebrew/bin/noti
zstyle ':notify:*' error-title "failed"
zstyle ':notify:*' error-sound "default"
zstyle ':notify:*' success-sound "wc3-work-complete"

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Set up fzf key bindings and fuzzy completion
# shellcheck source=/dev/null
source <(fzf --zsh)
