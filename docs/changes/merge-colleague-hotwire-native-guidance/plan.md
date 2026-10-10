# Plan: fold a colleague's Hotwire Native agent guidance into the hotwire-native skill

From `intent.md` (2026-10-09). Status: accepted.

## Context

The `hotwire-native` skill lives in `claude/.claude/skills/hotwire-native/`. `SKILL.md` routes Swift work to `references/ios.md` and Kotlin work to `references/android.md`. Each reference has two sections today: `## Structure to preserve` and `## Checks`; `ios.md` also has `## Setup` for MobileBuildMCP. `test/hotwire_native_skill_test.rb` guards `SKILL.md` and asserts that `android.md` names no MCP server. `test/mobile_tooling_test.rb` asserts that `ios.md` names exactly one `mobilebuildmcp@<version>`.

This change adds contracts, lifecycle traps, a reporting rule and a skill-prerequisite rule to both references, with an upstream link per restated claim, and guards each rule with a test. The colleague's agent files are not in this repository and are not needed: the acceptance criteria in `intent.md` state every rule, and the wording comes from the upstream pages below, never from the colleague's text.

## Design decisions

- New sections in each reference, in this order: `## Structure to preserve` (unchanged), `## Contracts to keep`, `## Lifecycle traps`, `## Before you apply another skill`, `## Checks` (unchanged), `## Report what you checked`, then `## Setup` (iOS only, unchanged and last). Contracts sit next to structure because both say what to keep. Reporting follows the checks it reports on.
- One rule per list item, one line per list item. Each rule's line carries its own inline links. This lets a test find the rule's line by its key phrase and assert the link on that same line, so a link cannot drift away from its rule.
- Shared rules use the same key phrase in both files, with platform words around it (for example "`BridgeComponent` subclass registered with `Hotwire.registerBridgeComponents`" on iOS, "`BridgeComponentFactory` registered in the `Application` subclass" on Android). The key phrases are fixed in `## Proof` below; the implementer must keep them verbatim.
- No exception to the link rule: every line that restates Hotwire Native behaviour links the `native.hotwired.dev` page that backs it.
- Cleanup (revised 2026-10-10 after review rounds 3 to 5): the Hotwire Native behaviour it restates is that a native component adds native controls when it receives a message from the web side, and that each destination owns its `BridgeDelegate` and component instances. The platform bridge components page on `native.hotwired.dev` backs the first; the upstream source backs the rest: `hotwire-native-ios` `Source/Bridge/BridgeDelegate.swift` and `Source/Turbo/Session/Session.swift` (lifecycle events reach only an active component, and a new visit deactivates the previous web view first), `hotwire-native-android` `core/src/main/kotlin/dev/hotwire/core/bridge/BridgeDelegate.kt` and `core/src/main/assets/js/turbo.js` (`native:restore`), and `hotwire-native-bridge` `src/bridge_component.js` (`disconnect()` sends nothing to native). The rule therefore puts cleanup in an idempotent `onReceive`, names the lifecycle hooks as overrides that do nothing by default, and on iOS says not to put cleanup in the disappear hooks. `SKILL.md` already names these repositories as upstream source of truth.
- The cookies and sessions rule on iOS restates Hotwire Native behaviour (401 handling in the app's own error handler to present a login screen, cookie sharing by one `WKWebsiteDataStore` for the Hotwire Native web view and the outside web views) and links `https://native.hotwired.dev/ios/reference`, Apple's `WKWebsiteDataStore` page and Apple's `WKProcessPool` page, because the upstream example's process pool is deprecated since iOS 15 and has no effect on iOS 15 and later. `native.hotwired.dev/android/reference` documents neither. The Android line is narrowed to project guidance only: it restates no Hotwire Native behaviour, so the link criterion does not apply to it. The test asserts the link on iOS only.
- iOS process termination: `Navigator` in `hotwire-native-ios` already reloads a terminated web view (`sessionWebViewProcessDidTerminate`). The trap is a custom `SessionDelegate` or navigation delegate that overrides this and leaves a blank screen. The line links Apple's `webViewWebContentProcessDidTerminate(_:)` page and the upstream `Navigator.swift` source.
- Rules that give guidance only and restate no upstream behaviour (reporting split, skill prerequisites, "never log tokens") carry no link.
- Every URL below was reachable on 2026-10-09. The implementer fetches each page again before writing its line and confirms the page backs the claim. An optional detail the page does not back (a hook name, an API name) is dropped, not paraphrased. A claim that an acceptance criterion requires and no official page backs stops the work: the implementer reports it as an open decision and does not drop the criterion or its test.

## Integration points

- Claude Code and Codex both load the same skill directory; Codex reaches it through the `agents` stow package symlink. No symlink or stow change.
- `claude/.claude/skills/android-intent-security/SKILL.md` (vendored). `android.md` points to it by name and path; the vendored file stays untouched.
- `test/mobile_tooling_test.rb` reads `ios.md`: the new text must not name `mobilebuildmcp` again with another version.
- `test/hotwire_native_skill_test.rb` `test_android_reference_uses_the_gradle_wrapper_and_adb_and_names_no_mcp_server`: the new Android text must not contain the word `MCP`.
- `lefthook.yml` `no-hardwrap` pre-commit hook runs markdownlint on staged markdown.

## Files that change

- `test/hotwire_native_skill_test.rb` — new tests for each rule, a parity test across both references, link-on-the-same-line assertions, and refutations for persona, Copilot and blanket regression wording.
- `claude/.claude/skills/hotwire-native/references/ios.md` — four new sections with iOS wording and links.
- `claude/.claude/skills/hotwire-native/references/android.md` — four new sections with Android wording and links, including the `android-intent-security` pointer.

Nothing else changes. `SKILL.md` stays byte-for-byte equal to `main`.

## Upstream pages per rule

- Path configuration order: `https://native.hotwired.dev/reference/path-configuration` (rules are read in order; a later rule overrides an earlier one). Shipped versions: `https://native.hotwired.dev/overview/path-configuration` (version the file, keep old versions on the server for older clients).
- Bridge component contract and progressive enhancement: `https://native.hotwired.dev/ios/bridge-components` or `https://native.hotwired.dev/android/bridge-components` (registration, matching `name`, `send`, `onReceive`, `reply(to:)` / `replyTo`, the `[data-bridge-components~="..."]` CSS that hides web UI). Plus `https://native.hotwired.dev/reference/bridge-components` (`this.enabled`, `this.send(event, data, callback)`).
- Cleanup: platform bridge components page, plus `https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Bridge/BridgeDelegate.swift`, `https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Bridge/BridgeComponent.swift` and `https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Turbo/Session/Session.swift` on iOS; `https://github.com/hotwired/hotwire-native-android/blob/main/core/src/main/kotlin/dev/hotwire/core/bridge/BridgeDelegate.kt`, `https://github.com/hotwired/hotwire-native-android/blob/main/core/src/main/kotlin/dev/hotwire/core/bridge/BridgeComponent.kt` and `https://github.com/hotwired/hotwire-native-android/blob/main/core/src/main/assets/js/turbo.js` on Android; `https://github.com/hotwired/hotwire-native-bridge/blob/main/src/bridge_component.js` on both.
- Sessions (iOS only): `https://native.hotwired.dev/ios/reference`.
- Untrusted destinations: `https://native.hotwired.dev/reference/navigation` (external URLs open outside the app; route decision handlers). Android adds `https://developer.android.com/guide/topics/manifest/activity-element#exported` and the path `claude/.claude/skills/android-intent-security/SKILL.md`.
- Android traps: Activity recreation `https://developer.android.com/guide/components/activities/state-changes`; process death `https://developer.android.com/topic/libraries/architecture/saving-states`; predictive back `https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture`; `CancellationException` `https://kotlinlang.org/docs/cancellation-and-timeouts.html`.
- iOS traps: `https://developer.apple.com/documentation/webkit/wknavigationdelegate/webviewwebcontentprocessdidterminate(_:)` and `https://github.com/hotwired/hotwire-native-ios/blob/main/Source/Turbo/Navigator/Navigator.swift`; `@MainActor` `https://developer.apple.com/documentation/swift/mainactor` and `https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/`.

## Order of work

1. Write the acceptance test for path configuration order in `test/hotwire_native_skill_test.rb`. Run `ruby -Itest test/hotwire_native_skill_test.rb -n /path_configuration/`. Watch it fail on both references.
2. Write every other test in `## Proof` in the same file. Run the file. Confirm each new positive rule test fails because the key phrase is missing, not because of a typo or a load error. The negative-content tests and the parity helper test pass already; that is expected. Confirm the 11 existing tests still pass. Commit: `test: guard hotwire-native reference contracts and traps`.
3. Fetch each page in `## Upstream pages per rule` and confirm it backs the claim. Drop an unbacked optional detail. Stop and report when a required claim has no backing.
4. Add `## Contracts to keep` to `ios.md` and `android.md`. Run the test file. The contract and parity tests turn green. Commit: `docs: add contracts to keep to hotwire-native references`.
5. Add `## Lifecycle traps` to both references. Run the test file. Commit: `docs: add lifecycle traps to hotwire-native references`.
6. Add `## Before you apply another skill` and `## Report what you checked` to both references. Run the test file; all green. Commit: `docs: add skill prerequisites and reporting to hotwire-native references`.
7. Run the checks in `## Proof` that are not tests: SKILL.md diff, public content search, markdownlint, full suite.
8. Re-read the full diff against `main`. Revert any hunk the task did not ask for.

## Risks

- The Android sessions line carries no link, because no upstream Android page covers cookies or sign-out. The line must stay guidance only; if it ever restates Hotwire Native behaviour, it needs a backing page.
- Key phrase tests can pass on a phrase that sits in the wrong section. Each rule test asserts every required clause on one line, plus the link on that line, which reduces that risk.
- The cleanup rule rests on library source, not on `native.hotwired.dev`. Decided 2026-10-09 (hook names allowed, library source counts as backing) and revised 2026-10-10 (cleanup through an idempotent `onReceive`; hooks are no-op overrides). Both decisions are recorded in `intent.md`.
- Source file links point at `main` and can move upstream. A pinned commit link would not move but would age. Chosen: `main`, the same as the repository links in `SKILL.md`.
- `ios.md` must keep exactly one `mobilebuildmcp@` version, and `android.md` must stay free of the word `MCP`. Both are guarded by existing tests.
- Rejected: a shared `references/contracts.md`. It would add a routing hop and a file the intent did not name. The intent chose duplication with a parity test.
- Rejected: changing `SKILL.md` to point at the new sections. Out of scope by intent.

## Out of scope

- `SKILL.md`, `SKILLS-INDEX.md`, `VENDORED-SKILLS.yml`, `codex/.codex/config.toml`, the `agents` package symlinks, the vendored `android-intent-security` skill.
- The files guarded by `test/mobile_testing_exception_test.rb`.
- Vendoring more upstream skills, a Swift concurrency skill, or any Copilot agent file.
- Pushing the branch or opening a pull request during implementation. `intent.md` requires explicit approval for both.

## Proof

Each test below lives in `test/hotwire_native_skill_test.rb`. A shared rule is a constant `SHARED_RULES` that maps a rule name to its key phrase regex; each shared test iterates both references and names the failing file in its message.

- Path configuration is an ordered contract, later rule overrides, shipped versions keep working, linked → `test/hotwire_native_skill_test.rb` `test_both_references_state_path_configuration_as_an_ordered_contract` (one line holds `/later matching rule overrides/i`, `/already shipped app versions/i` and `native.hotwired.dev/reference/path-configuration`)
- Bridge component is one contract across all sides, read every side first, linked → `test_both_references_state_the_bridge_component_as_one_contract` (one line holds `/one contract/i`, `/HTML data attributes/i`, `/Stimulus component/i`, `/native registration/i`, `/message names/i`, `/payloads/i`, `/replies/i`, `/read every side before changing one/i`, plus `Hotwire.registerBridgeComponents` and `native.hotwired.dev/ios/bridge-components` in `ios.md`, `BridgeComponentFactory` and `native.hotwired.dev/android/bridge-components` in `android.md`)
- Progressive enhancement → `test_both_references_state_progressive_enhancement` (one line holds `/web control stays usable/i`, `/plain browser/i`, `/older app versions/i`, `/hide web UI only when the native side supports/i`, `data-bridge-components` and the platform bridge components page)
- Cleanup → `test_both_references_keep_repeat_visits_free_of_stale_and_duplicate_controls` (one line holds `/own `BridgeDelegate`/`, `/from its own `connect\(\)`/`, `/`onReceive` must replace/i`, `/repeat visit shows no stale/i`, `/fires no duplicate action/i`, `/sends nothing to native/i`, the platform bridge components page and the platform `hotwired` repository; `android.md` also names `native:restore` and links `core/src/main/assets/js/turbo.js`) and `test_both_references_describe_lifecycle_hooks_as_overrides_that_do_nothing_by_default` (the `lifecycle_hooks` shared rule: hooks do nothing by default and reach only an active component; `ios.md` names the disappear hooks, says not to put cleanup there and links `Source/Turbo/Session/Session.swift`; `android.md` says `onStop` means inactive and `onStart` restores, idempotent). Revised 2026-10-10 with the intent's cleanup criterion after review rounds 3 to 5.
- Cookies, sessions, no logging → `test_both_references_preserve_sessions_and_never_log_secrets` (one line holds `/cookies/i`, `/authentication/i`, `/session expiry/i`, `/sign-out/i`; one line holds `/never log/i`, `/tokens/i`, `/sensitive bridge payloads/i`; the `ios.md` sessions line includes `native.hotwired.dev/ios/reference`)
- Untrusted destinations; Android Intents through the vendored skill → `test_both_references_validate_untrusted_destinations` (one line holds `/untrusted destinations/i`, `/authenticated web content/i`, `/arbitrary origin/i` and `native.hotwired.dev/reference/navigation`) and `test_android_reference_validates_intents_and_exported_components_with_the_vendored_skill` (one line holds `/incoming Intents/`, `/exported components/i`, `claude/.claude/skills/android-intent-security/SKILL.md` and `developer.android.com/guide/topics/manifest/activity-element#exported`)
- Android lifecycle traps → `test_android_reference_names_its_lifecycle_traps` (`/Activity recreation/` with `developer.android.com/guide/components/activities/state-changes`; `/process death/i` with `developer.android.com/topic/libraries/architecture/saving-states`; `/predictive back/i` with `developer.android.com/guide/navigation/custom-back/predictive-back-gesture`; `/never swallow `CancellationException`/` with `kotlinlang.org/docs/cancellation-and-timeouts.html`, each pair on one line)
- iOS lifecycle traps → `test_ios_reference_names_its_lifecycle_traps` (`/WKWebView process termination/i` with `webviewwebcontentprocessdidterminate`; `/no blanket `@MainActor`/` with `developer.apple.com/documentation/swift/mainactor`, each pair on one line)
- Three-way report split → `test_both_references_report_checks_observations_and_untested_behaviour_separately` (one line holds `/three separate/i`, `/automated checks/i`, `/untested device-only behaviour/i`, plus `/simulator/i` in `ios.md` and `/emulator/i` in `android.md`)
- Skill prerequisites → `test_both_references_check_skill_prerequisites_before_applying_a_skill` (one line holds `/prerequisites/i`, `/against the project/i`, plus `/Compose skill does not apply to a Views shell/i` in `android.md` and `/SwiftUI skill does not apply to a UIKit shell/i` in `ios.md`)
- Links on every restated rule → covered by the same-line assertions above.
- Each positive rule test fails on `main` and passes after → check: step 2 of `## Order of work`, the file run against unchanged references shows every positive rule test red.
- Parity fails when a shared rule is in one reference only → `test_parity_check_reports_a_rule_present_in_one_reference_only` (feeds `shared_rule_gaps` an in-memory iOS text that holds one rule's key phrase and an Android text that lacks it; asserts the gap names that rule) and `test_shared_rules_appear_in_both_references` (asserts `shared_rule_gaps(ios, android)` is empty for the real files and every `SHARED_RULES` phrase matches both)
- `SKILL.md` unchanged → check: `git diff --exit-code main -- claude/.claude/skills/hotwire-native/SKILL.md`. Mobile tests unchanged and green → check: `git diff --exit-code main -- test/mobile_testing_exception_test.rb test/mobile_tooling_test.rb` then `ruby -Itest test/mobile_testing_exception_test.rb && ruby -Itest test/mobile_tooling_test.rb`. `android.md` names no MCP → existing `test_android_reference_uses_the_gradle_wrapper_and_adb_and_names_no_mcp_server`.
- No blanket "regression test first" → `test_references_leave_the_testing_rule_to_the_mobile_exception` (refutes `/regression test (comes )?first/i` and `/(every|any) behaviou?r change/i` in both references)
- No company, product, colleague names, hosts, bundle IDs or signing details → check: `set -o pipefail; ! git diff main -- claude test | grep -inE 'nedap|caren|ons-client|\.home\.arpa|\.internal|\.local\b|com\.[a-z0-9]+\.[a-z0-9]+|DEVELOPMENT_TEAM|provisioning|codesign'` exits 0 and prints nothing.
- No persona, `~/.copilot`, "personal preferences" or front matter → `test_references_carry_no_persona_or_copilot_framing` (refutes `~/.copilot`, `/personal preferences/i`, `/\A---/` front matter, and `/^\s*(You are an? |Act as |Role:|Persona:)/i` in both references)
- Markdown and full suite → check: `markdownlint --config markdownlint/.config/markdownlint/no-hardwrap.json --rules markdownlint/.config/markdownlint/no-hardwrap.cjs claude/.claude/skills/hotwire-native/references/*.md docs/changes/merge-colleague-hotwire-native-guidance/*.md` exits 0; `set -o pipefail; for file in test/*_test.rb; do ruby -Itest "$file" || exit 1; done` is green; `rubocop test/hotwire_native_skill_test.rb` is clean.

Per changed file, the unit tests expected:

- `test/hotwire_native_skill_test.rb`: all tests named above. `SHARED_RULES` maps each shared rule name to its key phrase regex. Private helpers: `assert_rule(file, *patterns, links:)` finds the line that matches the first pattern, failing with the file name when none does, and asserts every pattern and link on that one line; `shared_rule_gaps(ios_text, android_text)` returns the rule names that match exactly one of the two texts.
- `references/ios.md`, `references/android.md`: no tests of their own; guarded by the file above.

Test setup: plain file reads from `SKILL_DIR`, as the existing tests do. No fixtures, no network.

---
Domain skills applied: hotwire-native, android-intent-security (as a pointer target only), ruby-style (test helpers), rails-testing (test naming).

## Critique

### Round 1 (codex exec -p terra)

- The cleanup and Android session exceptions contradict the link criterion. → fixed (Design decisions now allow no exception: the cleanup line links the native.hotwired.dev bridge components page; the hook names rest on library source and are reported as an open decision with a generic fallback; the Android sessions line is narrowed to guidance that restates no Hotwire Native behaviour)
- Step 3 permits dropping required claims and tests when a source is unavailable. → fixed (only optional details are dropped; a required claim without backing stops the work and is reported as an open decision)
- The bridge proof does not test the Stimulus component or the native registration. → fixed (the bridge test now requires HTML data attributes, Stimulus component, native registration and the platform registration API on the same line)
- The progressive enhancement and cleanup proofs are token checks, not behaviour checks. → fixed (the tests now require full clauses: web control stays usable, hide web UI only when the native side supports, disconnect, removes native controls and callbacks, repeat visit shows no stale, fires no duplicate action)
- The sessions and destination proofs omit authentication, tokens, sensitive bridge payloads, authenticated web content and the Android exported component link. → fixed (each clause and the Android activity-element exported link are now asserted)
- The claim that each new test fails on main is false for the parity and negative tests. → fixed (only positive rule tests must fail first; parity is proven with an in-memory one-sided fixture through shared_rule_gaps)
- The negative regexes are too broad and incomplete. → fixed (the copilot word match is replaced by the ~/.copilot path, front matter at file start and persona openers; the regression refutation also rejects every or any behaviour change wording)
- The privacy grep reports failure when it finds nothing. → fixed (the check now negates grep under pipefail, so it exits 0 only when nothing matches)
- The plan weakens the no-push and no-PR constraint to coordinator involvement. → fixed (Out of scope now says pushing and opening a pull request need explicit approval, as intent.md states)
