# TREK MCP Machine-Client Authentication Design

## Goal

Make the self-hosted TREK MCP server available to Codex after the existing `unlock` command, using the TREK machine client's 1Password-backed credentials without storing either credential or an OAuth access token in the dotfiles repository.

## Context

The Codex configuration is a Stow-managed Streamable HTTP MCP configuration. Codex can read a bearer token from a named environment variable, but the installed CLI configuration does not provide a client-secret environment setting for the OAuth `client_credentials` grant. TREK's machine client therefore needs to be exchanged for a short-lived bearer token before Codex starts.

## Design

The existing `secrets` function will resolve the user's supplied 1Password references through the already-configured personal account:

```text
TREK_MCP_CLIENT_ID=op://.../TrekMCP/CLIENT_ID
TREK_MCP_CLIENT_SECRET=op://.../TrekMCP/CLIENT_SECRET
```

The `unlock` alias will then call a Zsh function that:

1. Does nothing when the TREK client variables are absent, preserving unlock behavior on machines without TREK configured.
2. Validates that `curl` and `jq` are available when TREK credentials are present.
3. Sends a `client_credentials` form request to `https://trips.vandelden.family/oauth/token`.
4. Sends the URL-encoded request body to `curl` over stdin, avoiding the client secret in the process argument list.
5. Requests the scopes needed to create trips and reservations: `trips:write reservations:write places:write geo:read`.
6. Extracts the access token without printing the OAuth response and exports it as `TREK_MCP_ACCESS_TOKEN`.
7. Fails with a short diagnostic if the request or response is invalid, without echoing credential values or the response body.

Codex will use the following server entry:

```toml
[mcp_servers.trek]
url = "https://trips.vandelden.family/mcp"
bearer_token_env_var = "TREK_MCP_ACCESS_TOKEN"
```

This explicitly connects the session environment to the HTTP MCP server. A fresh Codex CLI process launched from the same shell as `unlock` will inherit the token.

## Error handling and security

- The client ID and secret remain only in 1Password and the current shell environment.
- The access token remains only in the current shell environment and its child processes.
- Token endpoint failures are reported generically; OAuth response bodies are not emitted.
- The helper does not overwrite the client credentials or persist the access token.
- The configuration does not use Codex's interactive OAuth login flow because this is a TREK machine client and has no redirect URI.

## Testing and verification

- Add a Minitest regression test that runs the Zsh helper with stubbed `curl` and `jq`, verifies the request URL/form behavior, and confirms that the access token is exported without printing the client secret.
- Run the existing dotfiles test suite.
- Validate the TOML through `codex mcp get trek`.
- Run `unlock` with the real 1Password references in the user's shell, inspect only variable-presence status, and verify the TREK endpoint accepts the resulting bearer token without displaying it.

## Scope

This change only adds TREK authentication/configuration and its tests. It does not import bookings, create trips, change the TREK deployment, or modify existing unrelated working-tree changes.
