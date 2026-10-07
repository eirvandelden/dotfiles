# Hotwire Native on iOS (Swift)

Docs: [native.hotwired.dev](https://native.hotwired.dev) and [hotwire-native-ios](https://github.com/hotwired/hotwire-native-ios). Read the version the app pins, not the latest.

## Structure to preserve

- `Navigator` hosts navigation per tab. Keep the app's existing navigator setup.
- Path configuration is loaded once at start, from a bundled file and a remote URL. Edit the rule that matches the URL. Do not restructure it.
- `BridgeComponent` subclasses handle messages by name. The name must match the Stimulus component on the web side.
- Keep the supported iOS deployment target and the Swift Package pins unless the task asks to change them.

## Checks

Name the worktree path, scheme and simulator before every command.

1. With MobileBuildMCP registered, call `session_show_defaults` first. Then use its build, simulator and inspection tools. Setup is below.
2. Without it, use `xcodebuild` with an explicit `-scheme` and `-destination 'id=<udid>'`. List simulators with `xcrun simctl list devices available`.
3. Lint with the project's own SwiftLint config only if one exists. Never add a config.

## Setup

MobileBuildMCP (Sentry, MIT) builds, runs and inspects iOS apps. Pin an exact version and turn telemetry off.

Claude, once, with no Claude session running:

```bash
claude mcp add --scope user -e MOBILEBUILDMCP_SENTRY_DISABLED=true MobileBuildMCP -- npx -y mobilebuildmcp@2.7.1 mcp
```

A live Claude session rewrites `~/.claude.json` and drops the change. Read the file afterwards to confirm the server is there.

Codex reads the `[mcp_servers.MobileBuildMCP]` block in `codex/.codex/config.toml`. Keep the version in both places equal.
