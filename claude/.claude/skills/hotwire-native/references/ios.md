# Hotwire Native on iOS (Swift)

Docs: [native.hotwired.dev](https://native.hotwired.dev) and [hotwire-native-ios](https://github.com/hotwired/hotwire-native-ios). Read the version the app pins, not the latest.

## Structure to preserve

- `Navigator` hosts navigation per tab. Keep the app's existing navigator setup.
- Path configuration is loaded once at start, from a bundled file and a remote URL. Edit the rule that matches the URL. Do not restructure it.
- `BridgeComponent` subclasses handle messages by name. The name must match the Stimulus component on the web side.
- Keep the supported iOS deployment target and the Swift Package pins unless the task asks to change them.

## Contracts to keep

- Path configuration is an ordered contract: a later matching rule overrides the properties of an earlier one, and a change keeps already shipped app versions working, so leave old file versions on the server ([rules](https://native.hotwired.dev/reference/path-configuration), [versions](https://native.hotwired.dev/overview/path-configuration)).
- A bridge component is one contract across the HTML data attributes, the Stimulus component, the native registration (a `BridgeComponent` subclass registered with `Hotwire.registerBridgeComponents`), the message names, the payloads and the replies. Read every side before changing one ([bridge components](https://native.hotwired.dev/ios/bridge-components), [web side](https://native.hotwired.dev/reference/bridge-components)).
- Keep progressive enhancement: the web control stays usable in a plain browser and in older app versions, so hide web UI only when the native side supports the component, with `data-bridge-components` CSS ([bridge components](https://native.hotwired.dev/ios/bridge-components)).
- Clean up on repeat visits: every destination has its own `BridgeDelegate` and component instances, and a component that sends `connect` from its own `connect()` sends `connect` again each time its Stimulus controller connects, so its `onReceive` must replace the control and its callback instead of adding another, and a repeat visit shows no stale button and fires no duplicate action. The web side's `disconnect()` sends nothing to native; a disconnect reaches native only through a message the web component sends ([bridge components](https://native.hotwired.dev/ios/bridge-components), [delegate](https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Bridge/BridgeDelegate.swift), [web side](https://github.com/hotwired/hotwire-native-bridge/blob/main/src/bridge_component.js)).
- Lifecycle hooks are overrides: `onViewWillAppear`, `onViewWillDisappear` and `onViewDidDisappear` do nothing by default, and `BridgeDelegate` forwards them only while the destination's web view is active. A new visit deactivates the previous web view first, so the disappear hooks often never reach a component; do not put cleanup there ([component](https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Bridge/BridgeComponent.swift), [delegate](https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Bridge/BridgeDelegate.swift), [session](https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Turbo/Session/Session.swift)).
- Preserve cookies, authentication, session expiry and sign-out behaviour. Handle a 401 in the app's own error handler, and present the login screen only when the 401 means the session has expired, not when the app's auth flow can refresh it; share cookies with web views outside Hotwire Native by using the same `WKWebsiteDataStore` for the Hotwire Native web view, set in `makeCustomWebView`, and for those outside web views; `WKProcessPool` is deprecated since iOS 15 and has no effect on iOS 15 and later, so the upstream example's pool changes nothing there ([reference](https://native.hotwired.dev/ios/reference), [data store](https://developer.apple.com/documentation/webkit/wkwebsitedatastore), [process pool](https://developer.apple.com/documentation/webkit/wkprocesspool)).
- Never log tokens, cookies or sensitive bridge payloads.
- Validate untrusted destinations. Authenticated web content never goes to an arbitrary origin, and external URLs open outside the app through the route decision handlers ([navigation](https://native.hotwired.dev/reference/navigation)).

## Lifecycle traps

- WKWebView process termination leaves a blank page. Do not override the session or navigation delegate in a way that skips the reload ([Apple](https://developer.apple.com/documentation/webkit/wknavigationdelegate/webviewwebcontentprocessdidterminate(_:)), [Navigator](https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Turbo/Navigator/Navigator.swift)).
- Use no blanket `@MainActor` to silence a concurrency warning. Isolate the type that owns UI state, and fix the cause ([Apple](https://developer.apple.com/documentation/swift/mainactor), [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)).

## Before you apply another skill

Check a skill's prerequisites against the project before you apply it. A SwiftUI skill does not apply to a UIKit shell.

## Checks

Name the worktree path, scheme and simulator before every command.

1. With MobileBuildMCP registered, call `session_show_defaults` first. Then use its build, simulator and inspection tools. Setup is below.
2. Without it, use `xcodebuild` with an explicit `-scheme` and `-destination 'id=<udid>'`. List simulators with `xcrun simctl list devices available`.
3. Lint with the project's own SwiftLint config only if one exists. Never add a config.

## Report what you checked

Report three separate things: automated checks (build, lint, tests), simulator observations, and untested device-only behaviour.

## Setup

MobileBuildMCP (Sentry, MIT) builds, runs and inspects iOS apps. Pin an exact version and turn telemetry off.

Claude, once, with no Claude session running:

```bash
claude mcp add --scope user -e MOBILEBUILDMCP_SENTRY_DISABLED=true MobileBuildMCP -- npx -y mobilebuildmcp@2.7.1 mcp
```

A live Claude session rewrites `~/.claude.json` and drops the change. Read the file afterwards to confirm the server is there.

Codex reads the `[mcp_servers.MobileBuildMCP]` block in `codex/.codex/config.toml`. Keep the version in both places equal.
