# Hotwire Native on Android (Kotlin)

Docs: [native.hotwired.dev](https://native.hotwired.dev) and [hotwire-native-android](https://github.com/hotwired/hotwire-native-android). Read the version the app pins, not the latest.

## Structure to preserve

- `HotwireActivity` hosts the navigator. Destinations are `HotwireFragment` subclasses registered with their URL pattern. Keep the existing registrations.
- Path configuration is loaded once at start, from a bundled asset and a remote URL. Edit the rule that matches the URL. Do not restructure it.
- `BridgeComponent` subclasses handle messages by name. The name must match the Stimulus component on the web side.
- Keep `minSdk`, the Gradle plugin and the library pins unless the task asks to change them.

## Contracts to keep

- Path configuration is an ordered contract: a later matching rule overrides the properties of an earlier one, and a change keeps already shipped app versions working, so leave old file versions on the server ([rules](https://native.hotwired.dev/reference/path-configuration), [versions](https://native.hotwired.dev/overview/path-configuration)).
- A bridge component is one contract across the HTML data attributes, the Stimulus component, the native registration (a `BridgeComponentFactory` registered in the `Application` subclass), the message names, the payloads and the replies. Read every side before changing one ([bridge components](https://native.hotwired.dev/android/bridge-components), [web side](https://native.hotwired.dev/reference/bridge-components)).
- Keep progressive enhancement: the web control stays usable in a plain browser and in older app versions, so hide web UI only when the native side supports the component, with `data-bridge-components` CSS ([bridge components](https://native.hotwired.dev/android/bridge-components)).
- Clean up on repeat visits: every destination has its own `BridgeDelegate` and component instances, and a component that sends `connect` from its own `connect()` sends `connect` again each time its Stimulus controller connects, so its `onReceive` must replace the control and its callback instead of adding another, and a repeat visit shows no stale button and fires no duplicate action. The web side's `disconnect()` sends nothing to native; a disconnect reaches native only through a message the web component sends. On a web, native, web return the Stimulus controller stays connected, so Android dispatches `native:restore`, which re-runs the component's `connect()` ([bridge components](https://native.hotwired.dev/android/bridge-components), [turbo.js](https://github.com/hotwired/hotwire-native-android/blob/main/core/src/main/assets/js/turbo.js), [delegate](https://github.com/hotwired/hotwire-native-android/blob/main/core/src/main/kotlin/dev/hotwire/core/bridge/BridgeDelegate.kt), [web side](https://github.com/hotwired/hotwire-native-bridge/blob/main/src/bridge_component.js)).
- Lifecycle hooks are overrides: `onStart` and `onStop` do nothing by default, and `BridgeDelegate` forwards them only while the destination is active. `onStop` means inactive and may resume, not removed; whatever an override tears down there, `onStart` restores, idempotent with what `onReceive` adds ([component](https://github.com/hotwired/hotwire-native-android/blob/main/core/src/main/kotlin/dev/hotwire/core/bridge/BridgeComponent.kt), [delegate](https://github.com/hotwired/hotwire-native-android/blob/main/core/src/main/kotlin/dev/hotwire/core/bridge/BridgeDelegate.kt)).
- Preserve cookies, authentication, session expiry and sign-out behaviour. Do not clear or replace the web view's cookie store to make a change work.
- Never log tokens, cookies or sensitive bridge payloads.
- Validate untrusted destinations. Authenticated web content never goes to an arbitrary origin, and external URLs open outside the app through the route decision handlers ([navigation](https://native.hotwired.dev/reference/navigation)).
- Validate incoming Intents and exported components with the vendored skill at `claude/.claude/skills/android-intent-security/SKILL.md`. An activity is exported only on purpose ([exported](https://developer.android.com/guide/topics/manifest/activity-element#exported)).

## Lifecycle traps

- Activity recreation (rotation, theme or locale change) rebuilds the Activity and its fragments. Keep UI state out of fields that die with it ([Android](https://developer.android.com/guide/components/activities/state-changes)).
- Handle process death: the system can kill the app in the background, so restore what the user needs from saved state ([Android](https://developer.android.com/topic/libraries/architecture/saving-states)).
- Check predictive back when you touch back handling, and register callbacks through the supported APIs ([Android](https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture)).
- In coroutines, never swallow `CancellationException` in broad error handling. Rethrow it, or catch narrower types ([Kotlin](https://kotlinlang.org/docs/cancellation-and-timeouts.html)).

## Before you apply another skill

Check a skill's prerequisites against the project before you apply it. A Compose skill does not apply to a Views shell.

## Checks

Name the worktree path, module, variant and device serial before every command. Use the Gradle wrapper from the project root, never a system Gradle.

```bash
./gradlew :<module>:assemble<Variant>
./gradlew :<module>:lint<Variant>
./gradlew :<module>:test<Variant>UnitTest
adb devices
adb -s <serial> install -r <apk>
```

`adb devices` is read-only. `adb install` changes a device, so name the serial first. List the variants with `./gradlew :<module>:tasks --all` when the project does not say.

## Report what you checked

Report three separate things: automated checks (build, lint, tests), emulator observations, and untested device-only behaviour.
