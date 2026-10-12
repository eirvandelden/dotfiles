# Re-establish rv's Ruby paths after macOS path_helper has reordered PATH.
# macOS's /etc/zprofile runs path_helper which moves system paths to the front.
# Using `rv shell env` restores Ruby paths without adding a duplicate preexec hook.
if [[ -x "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" ]]; then
  eval "$("${HOMEBREW_PREFIX:-/opt/homebrew}/bin/rv" shell env zsh)"
fi

# After `unlock`, keep its codex shim ahead of path_helper's order, so Codex's
# `zsh -lc` shell commands start nested sessions off the shared daemon.
if [[ -n "${UNLOCKED_BIN:-}" && -x "$UNLOCKED_BIN/codex" ]]; then
  path=("$UNLOCKED_BIN" "${(@)path:#$UNLOCKED_BIN}")
fi
