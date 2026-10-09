# Intent: fold a colleague's Hotwire Native agent guidance into the hotwire-native skill

Author: Etienne van Delden. Status: accepted. Type: feature. Delivery: autonomous.

## Problem

The `hotwire-native` skill (PR #187) tells an agent where the parts live and how to validate a change. It does not yet tell the agent which contracts a Hotwire Native change must keep intact, or which platform lifecycle traps break a shell in ways a build does not catch. A colleague's two agent files (one for Android, one for iOS) cover those gaps well, but they are written as Copilot personas with private skill paths and cannot be adopted whole into a public, shared skill.

## Proposed outcome

An agent that reads `references/ios.md` or `references/android.md` knows the contracts to keep (path configuration order, the bridge component contract, progressive enhancement, cleanup on repeat visits, cookies and sessions, untrusted URLs and Intents), the lifecycle traps of its platform, how to report what it checked, and that a skill's prerequisites must hold before it applies. Every restated upstream claim links to the official page that backs it. `SKILL.md` stays as merged, so the skill stays small.

## Affected users and systems

- Claude Code and Codex sessions that load `hotwire-native` (one shared skill, served to Codex through the `agents` stow package symlink).
- `claude/.claude/skills/hotwire-native/references/ios.md` and `references/android.md`.
- `test/hotwire_native_skill_test.rb`, which gains the guarding assertions.
- Readers of the public dotfiles repository.

## Constraints

- Public repository: no company, product or colleague names, no internal hosts, bundle IDs or signing details.
- Verify every copied claim against the official Hotwire Native docs (`native.hotwired.dev`) before adding it. Never copy from memory. A claim about the platform rather than Hotwire Native (for example Activity recreation, `CancellationException`, WKWebView process termination) is verified against the official platform documentation instead, and linked there.
- Keep: one shared skill for Claude and Codex; the pinned vendored upstream skills with licences and `VENDORED-SKILLS.yml`; the mobile testing exception as written in `SKILL.md`; the explicit targeting rule (never guess worktree, scheme or variant, device); the public-only content rule; MobileBuildMCP pinned at one exact version with telemetry off, named only in `ios.md`.
- Drop: persona framing, `~/.copilot/skills` paths, "personal preferences" wording, Copilot-style front matter, the Communication sections, the commit and push etiquette (the playbook owns it).
- Shared rules are duplicated in both references in each platform's words. A parity test guards the duplication.
- One line per paragraph and list item in markdown. The `no-hardwrap` markdownlint rule passes.
- Tests first, then lint, then the full suite. Commit small, one logical change each, never to `main`. No push and no pull request without asking.
- Permissions approved for autonomous delivery: none are needed. No dependency, no Stow, no symlink, no system tool, no deploy file changes. Any step that would need one stops and asks.

## In scope

- `references/ios.md`: contracts, iOS lifecycle traps, reporting split, skill prerequisites, with upstream links per rule.
- `references/android.md`: the same contracts in Android words, Android lifecycle traps, Intent and exported component validation through the vendored `android-intent-security` skill, reporting split, skill prerequisites, with upstream links per rule.
- `test/hotwire_native_skill_test.rb`: assertions for each new rule, plus parity assertions that each shared rule appears in both references by a key phrase.

## Out of scope

- `SKILL.md` (routing table, rules, targeting, validation matrix): unchanged.
- `SKILLS-INDEX.md`, `VENDORED-SKILLS.yml`, `codex/.codex/config.toml`, the `agents` package symlinks.
- The mobile testing exception files guarded by `test/mobile_testing_exception_test.rb`.
- Vendoring the rest of the `android/skills` collection or a Swift concurrency skill.
- Any Copilot agent file, persona or `.agent.md` format in this repository.

## Acceptance criteria

- Both references state path configuration as an ordered contract: a later matching rule overrides the properties of an earlier one, and a change keeps already shipped app versions working. The rule links the upstream path configuration reference.
- Both references state the bridge component as one contract across the HTML data attributes, the Stimulus component, the native registration, the message names, the payloads and the replies, and tell the agent to read every side before changing one. The rule links the upstream bridge component guide for that platform.
- Both references state progressive enhancement: the web control stays usable in a plain browser and in older app versions, and web UI is hidden only when the native side supports the component.
- Both references state cleanup: when a destination disconnects or its view goes away, native controls and callbacks are removed, so a repeat visit shows no stale button and fires no duplicate action.
- Both references state that cookies, authentication, session expiry and sign-out behaviour are preserved, and that tokens, cookies and sensitive bridge payloads are never logged.
- Both references state that untrusted destinations are validated and authenticated web content never goes to an arbitrary origin. `android.md` adds that incoming Intents and exported components are validated with the vendored `android-intent-security` skill.
- `android.md` names these lifecycle traps: Activity recreation, process death, predictive back, and never swallowing `CancellationException` in broad error handling.
- `ios.md` names these lifecycle traps: WKWebView process termination, and no blanket `@MainActor` as a concurrency fix.
- Both references tell the agent to report automated checks, simulator or emulator observations and untested device-only behaviour as three separate things.
- Both references tell the agent to check a skill's prerequisites against the project before applying it, with the example that a Compose skill does not apply to a Views shell (Android) and a SwiftUI skill does not apply to a UIKit shell (iOS).
- Every new rule that restates Hotwire Native behaviour carries an inline link to the `native.hotwired.dev` page that backs it. Every platform claim links its official platform page.
- `test/hotwire_native_skill_test.rb` fails on the merged `main` content for each new rule and passes after the change. A parity assertion fails when a shared rule is present in one reference and missing in the other.
- `SKILL.md` is byte-for-byte unchanged. `test/mobile_testing_exception_test.rb` and `test/mobile_tooling_test.rb` still pass unchanged. `android.md` still names no MCP server.
- Neither reference contains "regression test first" as a blanket rule for any behaviour change. The mobile exception in `SKILL.md` governs.
- A search of the diff for company, product and colleague names, internal hosts, bundle IDs and signing details finds nothing.
- Neither reference contains a persona, a `~/.copilot` path, "personal preferences" or Copilot front matter.
- The `no-hardwrap` markdownlint rule passes on both references and on this change folder. The full `test/` suite is green.

## Flagged concerns

- Duplicating shared rules in two files risks drift. Chosen side: duplicate, in each platform's words, with a parity test by key phrase, so the skill file stays short and each reference reads on its own.
- The colleague's "regression test first for any behaviour change" conflicts with the mobile testing exception. Chosen side: the mobile exception wins. Regressions, meaningful logic and security-sensitive behaviour keep the test-first rule through the validation matrix.
- Not every platform trap is documented on `native.hotwired.dev`. Chosen side: a Hotwire Native claim must be backed by `native.hotwired.dev`; a platform claim must be backed by official Apple, Android or Kotlin documentation. A claim with no official backing is dropped, not paraphrased. Decided 2026-10-09: the official `hotwired` library source on GitHub also counts as backing, so the cleanup rule names the bridge lifecycle hooks and links that source next to the `native.hotwired.dev` page.

## Open questions

None.
