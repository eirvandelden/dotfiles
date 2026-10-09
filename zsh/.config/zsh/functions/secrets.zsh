# ~/.config/zsh/functions/secrets.zsh
#
# Minimal secrets loader for zsh + 1Password CLI.
#
# Usage (sets vars in the CURRENT shell):
#   unlock             # exports the secrets and puts unlocked-bin/ first on PATH
#   eval "$(secrets)"  # exports only
#
# Reads:
#   ~/.config/secrets/1password.env
#   ~/.config/secrets/1password.work.env (optional; loaded if present)
#
# File format (one per line):
#   VAR_NAME=op://<vault>/<item>/<field>
#
# Notes:
# - Lines starting with # and blank lines are ignored.
# - This function prints shell-safe `export` statements (no secret values echoed
#   except via the exports you eval into your shell).

secrets() {
  emulate -L zsh
  set -euo pipefail

  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/secrets/1password.env"
  local cfg_work="${XDG_CONFIG_HOME:-$HOME/.config}/secrets/1password.work.env"

  if ! command -v op >/dev/null 2>&1; then
    print -u2 "secrets: 1Password CLI not found: op"
    return 1
  fi

  if [[ ! -f "$cfg" ]]; then
    print -u2 "secrets: config not found: $cfg"
    return 1
  fi

  # Parse and emit exports for a single config file.
  # Args:
  #   1: file path
  #   2: origin label (base/work) for override warnings
  #   3: 1Password account shorthand (passed to --account; empty = no flag)
  #
  # Uses by reference:
  #   seen_keys (assoc array: key -> origin)
  _secrets_emit_file() {
    emulate -L zsh
    set -euo pipefail

    local file="$1"
    local origin="$2"
    local account="$3"

    local line key ref val escaped_val

    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip blanks
      [[ -z "${line//[[:space:]]/}" ]] && continue
      # Skip comments (allow leading whitespace)
      if [[ "$line" == [[:space:]]#* || "$line" == \#* ]]; then
        continue
      fi

      # Expect KEY=op://...
      key="${line%%=*}"
      ref="${line#*=}"

      # Trim whitespace around key/ref
      key="${key#"${key%%[![:space:]]*}"}"
      key="${key%"${key##*[![:space:]]}"}"
      ref="${ref#"${ref%%[![:space:]]*}"}"
      ref="${ref%"${ref##*[![:space:]]}"}"

      if [[ -z "$key" || "$ref" == "$line" ]]; then
        print -u2 "secrets: invalid line (expected KEY=op://...): $line"
        print -u2 "secrets: in file: $file"
        return 1
      fi

      if [[ "$ref" != op://* ]]; then
        print -u2 "secrets: invalid reference (must start with op://): $ref"
        print -u2 "secrets: in file: $file"
        return 1
      fi

      if [[ -n "${seen_keys[$key]-}" ]]; then
        print -u2 "secrets: warning: overriding $key (was from ${seen_keys[$key]}, now from ${origin})"
      fi

      # Resolve secret via the correct account. Never print raw value.
      # Checked explicitly: zsh ignores `set -e` when the caller sits left of
      # && or ||, as in `unlock && codex`.
      local op_args=("read" "$ref")
      [[ -n "$account" ]] && op_args+=("--account" "$account")
      if ! val="$(op "${op_args[@]}")"; then
        print -u2 "secrets: op read failed for $key"
        return 1
      fi
      escaped_val="$(printf "%q" "$val")"
      print -r -- "export ${key}=${escaped_val}"

      seen_keys[$key]="$origin"
    done < "$file"
  }

  local -A seen_keys
  local personal_account="vandelden"
  local work_account="${SECRETS_WORK_OP_ACCOUNT:-}"

  _secrets_emit_file "$cfg" "base" "$personal_account" || return 1

  # Optional overlay (not required, typically gitignored). Without an account
  # the references would be read from the personal one, so skip it instead.
  if [[ -f "$cfg_work" && -z "$work_account" ]]; then
    print -u2 "secrets: SECRETS_WORK_OP_ACCOUNT is unset, skipping $cfg_work"
  elif [[ -f "$cfg_work" ]]; then
    _secrets_emit_file "$cfg_work" "work" "$work_account" || return 1
  fi
}

# Exports the secrets into the current shell and puts unlocked-bin/ first on
# PATH, so the `codex` shim there keeps Codex sessions off the shared daemon
# (Codex 0.160+) and the unlocked environment reaches their MCP servers.
# Nothing is applied when `secrets` fails.
unlock() {
  local exports
  local shim_dir="${ZDOTDIR:-$HOME/.config/zsh}/unlocked-bin"

  exports="$(secrets)" || return 1
  eval "$exports"

  if [[ ! -x "$shim_dir/codex" ]]; then
    print -u2 "unlock: $shim_dir/codex is missing; restow the zsh package"
    return 0
  fi

  case ":$PATH:" in
    *":$shim_dir:"*) ;;
    *) PATH="$shim_dir:$PATH" ;;
  esac
}
