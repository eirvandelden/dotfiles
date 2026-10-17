# Re-establish rv's Ruby paths after macOS path_helper has reordered PATH.
# macOS's /etc/zprofile runs path_helper which moves system paths to the front.
# Using `rv shell env` restores Ruby paths without adding a duplicate preexec hook.
if [[ -x "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" ]]; then
  eval "$("${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" shell env zsh)"
fi

# Put the selected chnode node back ahead of Homebrew's, which path_helper
# moved to the front. Without this, login shells (agents, Ghostty) resolve
# Homebrew's node and its global npm root.
if [[ -n "${CHNODE_ROOT:-}" && -x "$CHNODE_ROOT/bin/node" ]]; then
  path=("$CHNODE_ROOT/bin" "${path[@]}") # .zshenv sets typeset -U path
fi

# After `unlock`, keep its codex shim ahead of path_helper's order, so Codex's
# `zsh -lc` shell commands start nested sessions off the shared daemon.
if [[ -n "${UNLOCKED_BIN:-}" && -x "$UNLOCKED_BIN/codex" ]]; then
  path=("$UNLOCKED_BIN" "${path[@]}") # .zshenv sets typeset -U path
fi
