# ~/.config/zsh/functions/secrets.zsh
#
# `secrets`: explicitly load environment variables from 1Password references
# into a subshell, or run a one-off command with those secrets.
#
# This is intentionally NOT auto-run during shell startup beyond being sourced.
#
# Usage:
#   secrets
#   secrets -- <command> [args...]
#   secrets edit [--work]
#   secrets --help | -h
#
# Config:
#   ~/.config/secrets/1password.env
#   ~/.config/secrets/1password.work.env (optional; loaded if present)
#   Format (one per line):
#     VAR_NAME=op://<vault>/<item>/<field>
#
# Notes:
# - Lines starting with # and blank lines are ignored.
# - This function never prints secret values.
# - `secrets edit` uses your `e` editor launcher (alias/function).

# Print usage/help text
_secrets_usage() {
  emulate -L zsh
  set -euo pipefail

  local cfg="$1"
  local cfg_work="$2"

  print -r -- $'secrets: load environment variables from 1Password into a subshell or command\n'
  print -r -- $'Usage:\n  secrets\n  secrets -- <command> [args...]\n  secrets edit [--work]\n  secrets --help | -h\n'
  print -r -- $'Config:\n  '"$cfg"$'\n  Optional (if present):\n  '"$cfg_work"$'\n  Format: VAR_NAME=op://<vault>/<item>/<field>\n'
}

# Trim leading/trailing whitespace from a string
_secrets_trim() {
  emulate -L zsh
  set -euo pipefail

  local s="$1"
  # leading
  s="${s#"${s%%[![:space:]]*}"}"
  # trailing
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

# Parse a single config line into "KEY<TAB>REF"
# Returns non-zero if the line is not a valid mapping line.
_secrets_parse_line() {
  emulate -L zsh
  set -euo pipefail

  local line="$1"
  local file="$2"

  # Skip blanks
  [[ -z "${line//[[:space:]]/}" ]] && return 1

  # Skip comments (allow leading whitespace)
  if [[ "$line" == [[:space:]]#* || "$line" == \#* ]]; then
    return 1
  fi

  local key="${line%%=*}"
  local ref="${line#*=}"

  key="$(_secrets_trim "$key")"
  ref="$(_secrets_trim "$ref")"

  if [[ -z "$key" || "$ref" == "$line" ]]; then
    print -u2 "secrets: invalid line (expected KEY=op://...): $line"
    print -u2 "secrets: in file: $file"
    return 2
  fi

  if [[ "$ref" != op://* ]]; then
    print -u2 "secrets: invalid reference (must start with op://): $ref"
    print -u2 "secrets: in file: $file"
    return 2
  fi

  print -r -- "${key}\t${ref}"
}

# Load a config file and append resolved "KEY=VALUE" entries into the env_args array.
# Also tracks duplicates in seen_keys and warns when an existing key is overridden.
#
# Args:
#   1: file path
#   2: label for warnings (e.g. "base" or "work")
#
# Uses (by reference):
#   env_args   (array)
#   seen_keys  (assoc array: key -> origin label)
_secrets_load_file() {
  emulate -L zsh
  set -euo pipefail

  local file="$1"
  local origin="$2"

  local line parsed key ref val

  while IFS= read -r line || [[ -n "$line" ]]; do
    parsed="$(_secrets_parse_line "$line" "$file")" || {
      # 1 => skip (blank/comment), 2 => hard error
      local rc=$?
      if (( rc == 1 )); then
        continue
      fi
      return $rc
    }

    key="${parsed%%$'\t'*}"
    ref="${parsed#*$'\t'}"

    if [[ -n "${seen_keys[$key]-}" ]]; then
      print -u2 "secrets: warning: overriding $key (was from ${seen_keys[$key]}, now from ${origin})"
    fi

    # Resolve secret (do not echo)
    val="$(op read "$ref")"

    env_args+=("$key=$val")
    seen_keys[$key]="$origin"
  done < "$file"
}

secrets() {
  emulate -L zsh
  set -euo pipefail

  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/secrets/1password.env"
  local cfg_work="${XDG_CONFIG_HOME:-$HOME/.config}/secrets/1password.work.env"

  if (( $# > 0 )); then
    case "$1" in
      --help|-h)
        _secrets_usage "$cfg" "$cfg_work"
        return 0
        ;;
      edit)
        shift
        local target="$cfg"
        if (( $# > 0 )); then
          case "$1" in
            --work)
              target="$cfg_work"
              ;;
            *)
              print -u2 "secrets: unknown option for edit: $1"
              print -u2 ""
              _secrets_usage "$cfg" "$cfg_work"
              return 2
              ;;
          esac
        fi

        if ! command -v e >/dev/null 2>&1; then
          print -u2 "secrets: can't find editor launcher: e"
          print -u2 "secrets: define an alias/function named 'e' (for example: alias e='zed')"
          return 1
        fi

        e "$target"
        return $?
        ;;
    esac
  fi

  if [[ ! -f "$cfg" ]]; then
    print -u2 "secrets: config not found: $cfg"
    print -u2 "secrets: create it with lines like: FOO=op://Vault/Item/field"
    print -u2 ""
    _secrets_usage "$cfg" "$cfg_work"
    return 1
  fi

  if ! command -v op >/dev/null 2>&1; then
    print -u2 "secrets: 1Password CLI not found: op"
    return 1
  fi

  # If a command is given, run it with secrets in the environment.
  # Otherwise, start an interactive zsh subshell.
  local -a cmd
  if (( $# > 0 )); then
    if [[ "$1" == "--" ]]; then
      shift
    fi
    if (( $# == 0 )); then
      print -u2 "secrets: expected a command after --"
      print -u2 ""
      _secrets_usage "$cfg" "$cfg_work"
      return 2
    fi
    cmd=("$@")
  else
    cmd=()
  fi

  # Build an env invocation safely without printing secrets.
  local -a env_args
  local -A seen_keys

  _secrets_load_file "$cfg" "base"

  # Optional work overlay (intentionally not required / not in git)
  if [[ -f "$cfg_work" ]]; then
    _secrets_load_file "$cfg_work" "work"
  fi

  if (( ${#cmd[@]} > 0 )); then
    command env "${env_args[@]}" "${cmd[@]}"
  else
    # Launch interactive subshell. Inherit stdin/out/err; no secrets printed.
    command env "${env_args[@]}" zsh -i
  fi
}
