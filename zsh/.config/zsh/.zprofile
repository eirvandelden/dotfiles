# Re-initialize rv after macOS path_helper has run.
# macOS's /etc/zprofile runs path_helper which reorganizes PATH,
# moving system paths to the front and pushing rv's Ruby paths to the end.
# This re-initialization restores rv's Ruby paths to the front of PATH.
if [[ -x /opt/homebrew/bin/rv ]]; then
  eval "$(/opt/homebrew/bin/rv shell init zsh)"
fi
