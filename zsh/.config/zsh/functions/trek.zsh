# ~/.config/zsh/functions/trek.zsh

# Exchange the TREK machine-client credentials for a short-lived MCP bearer
# token. The client credentials are loaded by `unlock` from 1Password.
trek_mcp_token() {
  emulate -L zsh
  set -o pipefail

  local client_id="${TREK_MCP_CLIENT_ID:-}"
  local client_secret="${TREK_MCP_CLIENT_SECRET:-}"
  local token_url="${TREK_MCP_TOKEN_URL:-https://trips.vandelden.family/oauth/token}"
  local request_body token_response access_token

  [[ -z "$client_id" && -z "$client_secret" ]] && return 0

  if [[ -z "$client_id" || -z "$client_secret" ]]; then
    print -u2 -- "trek_mcp_token: both TREK_MCP_CLIENT_ID and TREK_MCP_CLIENT_SECRET are required"
    return 1
  fi

  unset TREK_MCP_ACCESS_TOKEN

  if ! command -v curl >/dev/null 2>&1; then
    print -u2 -- "trek_mcp_token: curl is required"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    print -u2 -- "trek_mcp_token: jq is required"
    return 1
  fi

  request_body="$(
    TREK_MCP_CLIENT_ID="$client_id" \
    TREK_MCP_CLIENT_SECRET="$client_secret" \
    jq -nr '
      [
        "grant_type=client_credentials",
        ("client_id=" + (env.TREK_MCP_CLIENT_ID | @uri)),
        ("client_secret=" + (env.TREK_MCP_CLIENT_SECRET | @uri)),
        ("scope=" + ("trips:write reservations:write places:write geo:read" | @uri))
      ] | join("&")
    '
  )" || {
    print -u2 -- "trek_mcp_token: could not encode the OAuth request"
    return 1
  }

  token_response="$(
    print -rn -- "$request_body" |
      curl --silent --show-error --fail --request POST \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --data-binary @- "$token_url" 2>/dev/null
  )" || {
    print -u2 -- "trek_mcp_token: OAuth token request failed"
    return 1
  }

  access_token="$(print -r -- "$token_response" | jq -er '.access_token // empty' 2>/dev/null)" || {
    print -u2 -- "trek_mcp_token: OAuth response did not contain an access token"
    return 1
  }

  [[ -n "$access_token" ]] || {
    print -u2 -- "trek_mcp_token: OAuth response did not contain an access token"
    return 1
  }

  export TREK_MCP_ACCESS_TOKEN="$access_token"
}
