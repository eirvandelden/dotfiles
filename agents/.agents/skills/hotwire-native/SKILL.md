---
name: hotwire-native
description: Use when writing, changing or reviewing a Hotwire Native app — Swift or Kotlin shell code, path configuration, native navigation, bridge components (Stimulus and native sides), or building and checking the app on a simulator or device.
---

# Hotwire Native

A Hotwire Native app is a thin native shell around a server-rendered web app. The web app owns the screens. The shell owns navigation, native chrome, bridge components and platform lifecycle.

Upstream docs are the source of truth. Read them instead of recalling the API: [native.hotwired.dev](https://native.hotwired.dev), [hotwire-native-ios](https://github.com/hotwired/hotwire-native-ios), [hotwire-native-android](https://github.com/hotwired/hotwire-native-android) and [hotwire-native-bridge](https://github.com/hotwired/hotwire-native-bridge).

## How the parts fit

- Server-rendered pages: Rails views and Turbo render each screen in a WebView. They stay valid for the plain web too.
- Path configuration: a JSON file, local and remote, maps URL patterns to native behaviour such as presentation, modal or pull to refresh.
- Native navigation: a navigator per tab pushes, presents and pops screens according to path configuration.
- Bridge components: a Stimulus `BridgeComponent` on the web side and a matching native component send messages to each other by name.
- Lifecycle: the shell owns app, activity and view-controller lifecycle. Web code must not assume it.

## Route by the files you touch

| Files touched | Read |
| --- | --- |
| `*.swift`, `*.xcodeproj`, `Package.swift` | `references/ios.md` |
| `*.kt`, `*.gradle*`, `AndroidManifest.xml` | `references/android.md` |
| Stimulus `BridgeComponent`, path configuration JSON | `references/ios.md` and `references/android.md`, plus the bridge rows below |

## Rules

- Preserve the app's existing Hotwire Native structure and its supported platform versions. Never migrate a framework, bump an SDK or rewrite structure unless the task asks for it.
- Rails architecture, strong parameters and Ruby style govern the Rails side only. They do not apply to Swift or Kotlin. Web code that serves native clients keeps web compatibility.
- A vendored skill may demand a dependency or version, for example a minimum library version. That demand yields to the preservation rule above and to the dependency-consent rule. Report the gap. Never add or bump a dependency without task scope and approval.

## Target before you build

Never guess the target. Before any build or device command, name these three, read from the project or ask:

1. The worktree path you build from. Run `pwd` and confirm it is the assigned workspace.
2. The scheme (iOS) or the variant and module (Android).
3. The device or simulator identifier.

## Validation matrix

Mobile exception: native UI, configuration and straightforward wiring in Swift or Kotlin may use build, lint and simulator or device checks instead of a test written first. Meaningful logic, security-sensitive behaviour and regressions keep automated tests, and a regression test comes first. Rails and web code keep the test-first rule unchanged.

| Change | Done when |
| --- | --- |
| Native UI or configuration | Build passes, lint passes, and a simulator or device check shows the change. A test written first is not required. |
| Simple wiring | Build passes, lint passes, and a simulator or device check exercises the wired path. |
| Bridge component, web side | The Stimulus controller and its markup follow the web testing policy, and the web page still works in a plain browser. |
| Bridge component, native side | Build passes, lint passes, and a simulator or device check sends a real message through the component. |
| Meaningful logic | An automated test covers it, written first. |
| Security-sensitive behaviour | An automated test covers it, written first. Review the boundary by hand as well. |
| Regression fix | An automated test reproduces the bug and fails first, then the fix makes it pass. The regression test comes first. |

A check that needs a person (a physical device, an install) is reported as pending, never as done.
