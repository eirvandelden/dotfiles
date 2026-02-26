# Re-establish rv's Ruby paths after macOS path_helper has reordered PATH.
# macOS's /etc/zprofile runs path_helper which moves system paths to the front.
# Using `rv shell env` restores Ruby paths without adding a duplicate preexec hook.
if [[ -x "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" ]]; then
  eval "$("${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" shell env zsh)"
fi
