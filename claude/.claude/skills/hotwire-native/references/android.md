# Hotwire Native on Android (Kotlin)

Docs: [native.hotwired.dev](https://native.hotwired.dev) and [hotwire-native-android](https://github.com/hotwired/hotwire-native-android). Read the version the app pins, not the latest.

## Structure to preserve

- `HotwireActivity` hosts the navigator. Destinations are `HotwireFragment` subclasses registered with their URL pattern. Keep the existing registrations.
- Path configuration is loaded once at start, from a bundled asset and a remote URL. Edit the rule that matches the URL. Do not restructure it.
- `BridgeComponent` subclasses handle messages by name. The name must match the Stimulus component on the web side.
- Keep `minSdk`, the Gradle plugin and the library pins unless the task asks to change them.

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
