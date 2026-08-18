# TREK MCP Machine-Client Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export a short-lived TREK MCP bearer token from `unlock` and configure Codex to use it for the self-hosted TREK server.

**Architecture:** 1Password continues to hold the machine client ID and secret. The current Zsh shell resolves those values, exchanges them at TREK's OAuth token endpoint through a stdin-fed form request, and exports only the resulting access token. Codex's Streamable HTTP MCP entry reads that access token from `TREK_MCP_ACCESS_TOKEN`.

**Tech Stack:** Zsh, 1Password CLI, `curl`, `jq`, Codex TOML configuration, Ruby Minitest.

---

### Task 1: Add the authentication regression tests

**Files:**
- Create: `test/trek_mcp_test.rb`

- [ ] **Step 1: Write the failing tests**

Create a Minitest class that runs the future Zsh helper in a clean `zsh -f` process. Use a temporary `bin` directory containing a `curl` stub that records stdin and returns `{"access_token":"test-access-token"}`. Cover these behaviors:

```ruby
def test_missing_client_credentials_is_a_no_op
  result = run_helper(env: {"TREK_MCP_TOKEN_URL" => "https://example.test/oauth/token"})

  assert result[:status].success?, result[:stderr]
  assert_equal "unset\n", result[:stdout]
end

def test_client_credentials_are_exchanged_and_access_token_is_exported
  result = run_helper(
    env: {
      "TREK_MCP_CLIENT_ID" => "client-id",
      "TREK_MCP_CLIENT_SECRET" => "client-secret",
      "TREK_MCP_TOKEN_URL" => "https://example.test/oauth/token"
    }
  )

  assert result[:status].success?, result[:stderr]
  assert_equal "set\n", result[:stdout]
  assert_includes File.read(@request_file), "grant_type=client_credentials"
  assert_includes File.read(@request_file), "client_id=client-id"
  assert_includes File.read(@request_file), "client_secret=client-secret"
  refute_includes result[:stdout] + result[:stderr], "client-secret"
end

def test_token_request_failure_is_generic_and_does_not_echo_response
  write_executable("curl", <<~SH)
    #!/bin/sh
    printf '%s\n' 'oauth failure containing client-secret' >&2
    exit 22
  SH

  result = run_helper(
    env: {
      "TREK_MCP_CLIENT_ID" => "client-id",
      "TREK_MCP_CLIENT_SECRET" => "client-secret"
    }
  )

  refute result[:status].success?
  assert_includes result[:stderr], "OAuth token request failed"
  refute_includes result[:stderr], "client-secret"
end
```

The test helper should set `PATH` to the temporary `bin` directory followed by the real system paths, source `zsh/.config/zsh/functions/trek.zsh`, invoke `trek_mcp_token`, and print only `${TREK_MCP_ACCESS_TOKEN:+set}`. The `curl` stub must save stdin to `@request_file` and must not print the request body.

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
ruby -I test test/trek_mcp_test.rb
```

Expected: failure because `zsh/.config/zsh/functions/trek.zsh` does not exist yet.

### Task 2: Implement the TREK token exchange

**Files:**
- Create: `zsh/.config/zsh/functions/trek.zsh`

- [ ] **Step 1: Add the minimal helper that satisfies the tests**

Implement `trek_mcp_token` with this behavior:

```zsh
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

  if (( ! $+commands[curl] )); then
    print -u2 -- "trek_mcp_token: curl is required"
    return 1
  fi

  if (( ! $+commands[jq] )); then
    print -u2 -- "trek_mcp_token: jq is required"
    return 1
  fi

  request_body="$(
    TREK_MCP_CLIENT_ID="$client_id" \
    TREK_MCP_CLIENT_SECRET="$client_secret" \
    jq -nr '"grant_type=client_credentials&client_id=" + (env.TREK_MCP_CLIENT_ID | @uri) + "&client_secret=" + (env.TREK_MCP_CLIENT_SECRET | @uri) + "&scope=" + ("trips:write reservations:write places:write geo:read" | @uri)'
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
```

- [ ] **Step 2: Run the focused tests to verify they pass**

Run:

```bash
ruby -I test test/trek_mcp_test.rb
```

Expected: all TREK helper tests pass.

### Task 3: Connect `unlock` and Codex configuration

**Files:**
- Modify: `zsh/.config/zsh/aliases.zsh:98`
- Modify: `secrets/.config/secrets/1password.env`
- Modify: `codex/.codex/config.toml`

- [ ] **Step 1: Make `unlock` exchange TREK credentials after loading 1Password values**

Change the existing alias from:

```zsh
alias unlock='eval "$(secrets)"'
```

to:

```zsh
alias unlock='eval "$(secrets)" && trek_mcp_token'
```

- [ ] **Step 2: Add the two exact 1Password mappings supplied by the user**

Append `TREK_MCP_CLIENT_ID` and `TREK_MCP_CLIENT_SECRET` to `secrets/.config/secrets/1password.env`, using the exact vault/item/field references from the user's request for the `TrekMCP` item's `CLIENT_ID` and `CLIENT_SECRET` fields. Do not substitute plaintext values or alter the references.

- [ ] **Step 3: Register TREK as a bearer-token MCP server**

Append this entry to `codex/.codex/config.toml`:

```toml
[mcp_servers.trek]
url = "https://trips.vandelden.family/mcp"
bearer_token_env_var = "TREK_MCP_ACCESS_TOKEN"
```

Do not add the client secret or access token to TOML.

- [ ] **Step 4: Run the focused tests and inspect the intended diff**

Run:

```bash
ruby -I test test/trek_mcp_test.rb
git diff --check
git diff -- zsh/.config/zsh/aliases.zsh zsh/.config/zsh/functions/trek.zsh secrets/.config/secrets/1password.env codex/.codex/config.toml test/trek_mcp_test.rb
```

Expected: focused tests pass, `git diff --check` is silent, and the diff contains only the intended TREK files/sections.

### Task 4: Verify locally and with the live machine client

**Files:**
- No additional files.

- [ ] **Step 1: Run all repository tests**

Run:

```bash
ruby -I test test/consent_guard_test.rb test/editor_test.rb test/lefthook_pull_hooks_test.rb test/rv_ci_fallback_test.rb test/trek_mcp_test.rb
```

Expected: zero failures and zero errors.

- [ ] **Step 2: Validate Codex's parsed MCP configuration**

Run:

```bash
codex mcp get trek
```

Expected: URL `https://trips.vandelden.family/mcp`, bearer environment variable `TREK_MCP_ACCESS_TOKEN`, and no literal credential values.

- [ ] **Step 3: Run the real unlock flow without printing values**

From the same interactive shell that will launch Codex, run `unlock`, then inspect only presence:

```zsh
for name in TREK_MCP_CLIENT_ID TREK_MCP_CLIENT_SECRET TREK_MCP_ACCESS_TOKEN; do
  [[ -n "${(P)name:-}" ]] && print "$name=set" || print "$name=unset"
done
```

Expected: all three variables report `set` and no secret value is printed.

- [ ] **Step 4: Verify the bearer token against TREK without displaying it**

Run a metadata request with the environment-expanded header:

```zsh
curl --silent --show-error --fail \
  -H "Authorization: Bearer $TREK_MCP_ACCESS_TOKEN" \
  -H 'Accept: application/json, text/event-stream' \
  https://trips.vandelden.family/mcp \
  >/dev/null
```

Expected: curl exits successfully. If OAuth discovery still advertises `localhost`, stop and fix TREK's `APP_URL` before treating the integration as complete.

### Task 5: Commit the implementation

**Files:**
- Stage only the files listed in Tasks 1–3.

- [ ] **Step 1: Review status and staged diff**

Run:

```bash
git status --short
git diff --cached --check
git diff --cached --stat
```

Expected: only the TREK design/plan, helper, test, mappings, alias, and Codex config are staged.

- [ ] **Step 2: Commit the implementation**

Run:

```bash
git commit -m "feat: configure TREK MCP machine auth"
```

Expected: repository hooks pass and the commit is created on `agent/trek-mcp`.
