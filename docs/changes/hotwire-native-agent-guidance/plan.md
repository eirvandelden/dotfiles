# Plan: Hotwire Native guidance for AI coding agents

From `intent.md` and `spec.md` (2026-10-02). Status: accepted.

## Context

The public dotfiles give Claude and Codex Rails and web guidance only. This change adds a first-party `hotwire-native` skill, two pinned upstream mobile skills, MobileBuildMCP registration for iOS, Gradle and `adb` guidance for Android, and one mobile testing exception that every test-first instruction carries. Scope is the public dotfiles repository only. The private work overlay and the application repository get their own changes.

The branch started from `b2f29286`. `origin/main` is now at `1c912dce` and has 238 changed files: 16 vendored superpowers-ruby skills, `VENDORED-LICENSES.md`, `guard_parity_test.rb`, a rewritten `default.rules`, and a new playbook rule 1. This plan is written against `origin/main`. The executor rebases first (step 0).

Facts checked on 2026-10-02:

- `getsentry/MobileBuildMCP` (MIT, renamed from XcodeBuildMCP): latest release `v2.7.1`, annotated tag, commit `d13ff0c707b0681769cf31da0eb42c4f94ceafff`. npm package `mobilebuildmcp@2.7.1`, bin `mobilebuildmcp`. Bundled skill: `skills/mobilebuildmcp/SKILL.md` (one file). Licence file: `LICENSE`.
- Telemetry opt-out (upstream privacy page): env var `MOBILEBUILDMCP_SENTRY_DISABLED=true`.
- Upstream client snippets: Claude `claude mcp add MobileBuildMCP -- npx -y mobilebuildmcp@latest mcp`; Codex `[mcp_servers.MobileBuildMCP]` with `command = "npx"`, `args = [...]`, and `tool_timeout_sec = 600` for long builds.
- `android/skills` (Apache-2.0): latest release `v1.0.13`, commit `42dc2270e96032bd860bb94511e440aa00a43125`. Licence file: `LICENSE.txt`, no `NOTICE`. Selected leaf: `security/android-intent-security/SKILL.md` (one file).
- `hotwired/hotwire-native-ios` 1.3.1, `hotwired/hotwire-native-android` 1.3.1, `hotwired/hotwire-native-bridge` v1.2.2, all MIT.
- `codex/.codex/rules/default.rules` on main has no `xcodebuild`, Gradle or `adb` rule. The spec's claim about existing `xcodebuild` rules is wrong.
- `core-values.yml` on main has no test-first line. It needs no change.
- Existing vendoring convention on main: an `<!-- upstream: <repo>@<tag> <path> — re-sync: ... -->` comment under the frontmatter, an `agents/openai.yaml` with an `interface` block, and the licence text in `VENDORED-LICENSES.md`.

Decisions Etienne made during planning:

- Android snapshot: `android-intent-security` only. `navigation-3` and `edge-to-edge` are Compose migration guides and conflict with R3. `testing-setup` installs test libraries and conflicts with the dependency-consent rule. `android-cli` needs a new CLI install.
- Codex MCP registration: an active, pinned block in `codex/.codex/config.toml`.
- Codex allow rules: `adb devices` only. No Gradle rule.
- MobileBuildMCP setup lives in `hotwire-native/references/ios.md`, not `HEADROOM.md`, which loads into every session. `spec.md` R8 and A12 are amended to say so, in a separate commit at plan acceptance.
- `mobile_tooling_test.rb` stays, as a drift guard (see Test setup).
- A Codex `-p terra` critique ran before acceptance. Accepted from it: `implementer.md` handling, the index moved into the step that tests it, project-local skills for the manual session checks, and the fence on vendored dependency demands. Rejected: a claimed pre-existing `skill_parity_test` failure (the suite passes on `origin/main`), and editing the vendored `systematic-debugging` skill.

## Canonical exception wording

Every R6 file carries this text, verbatim, as one paragraph or list item:

> Mobile exception: native UI, configuration and straightforward wiring in Swift or Kotlin may use build, lint and simulator or device checks instead of a test written first. Meaningful logic, security-sensitive behaviour and regressions keep automated tests, and a regression test comes first. Rails and web code keep the test-first rule unchanged.

The test greps for two key phrases: `build, lint and simulator or device checks` and `Rails and web code keep the test-first rule`.

## Files that change

Exception wording (R6):

- `agents.md` — rule 3 gets the exception as a new sub-bullet. `CLAUDE.md`, `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md` are symlinks to it and do not change.
- `claude/.claude/skills/rails-testing/SKILL.md` — the exception after the "all generated code must be driven from tests" line.
- `claude/.claude/skills/code-review/SKILL.md` — the exception after "failing test first, per the playbook TDD rule".
- `claude/.claude/skills/plan/SKILL.md` — the exception, plus a Proof line form for it: `- <criterion> → check: <exact command or manual step>`. Step 1 of the order of work may be the first failing check when no criterion needs an automated test.
- `claude/.claude/skills/implement/SKILL.md` — the exception. A `check:` Proof line is run and its output pasted, not written as a test.
- `claude/.claude/skills/spec/SKILL.md` — the exception next to "each acceptance criterion becomes exactly one acceptance test". A criterion under the exception names its check instead.
- `claude/.claude/agents/test-writer.md` — the exception. The agent skips `check:` lines and lists them in its output.
- `claude/.claude/agents/implementer.md` — the exception. A `check:` line is not a missing test: the implementer runs it after the code it covers and pastes the output into its report. In single mode the `implement` session does the same. Checks that need Etienne (a device, an install) are listed as pending, never marked done.
- `codex/.codex/agents/test-writer.toml` and `codex/.codex/agents/implementer.toml` — regenerated with `bin/generate-codex-agents`, never hand-edited.
- Not changed: the vendored `systematic-debugging` skill. It defers to playbook rule 3, so it inherits the exception, and it covers bug fixes, which keep their tests.

New first-party skill (R1–R5, R10):

- `claude/.claude/skills/hotwire-native/SKILL.md` — how the parts fit: server-rendered pages, path configuration, native navigation, bridge components, lifecycle. Links native.hotwired.dev and the three `hotwired` repositories. Routes by touched files: `*.swift`, `*.xcodeproj`, `Package.swift` → `references/ios.md`; `*.kt`, `*.gradle*`, `AndroidManifest.xml` → `references/android.md`; Stimulus `BridgeComponent` or `path-configuration` JSON → both plus the bridge row. States the preservation rule (R3), the Rails boundary (R5), the targeting rule (R10) and the validation matrix (R4), with rows: native UI or configuration, simple wiring, bridge component (web side, native side), meaningful logic, security-sensitive behaviour, regression fix. Quotes the canonical exception. States that a vendored skill's own demands to add or upgrade a dependency (for example `android-intent-security`'s "`androidx.core:core:1.9.0` is mandatory") yield to the preservation rule and the dependency-consent rule: report the gap, never add or bump without task scope and approval.
- `claude/.claude/skills/hotwire-native/references/ios.md` — Swift side: `Navigator`, path configuration, `BridgeComponent`, build and simulator checks through MobileBuildMCP (`session_show_defaults` first), `xcodebuild` as the fallback with an explicit `-scheme` and `-destination 'id=<udid>'`. Lint with the project's own SwiftLint config only if present.
- `claude/.claude/skills/hotwire-native/references/android.md` — Kotlin side: `HotwireActivity`, fragments, path configuration, `BridgeComponent`. Checks: `./gradlew :<module>:assemble<Variant>`, `./gradlew :<module>:lint<Variant>`, `./gradlew :<module>:test<Variant>UnitTest`, `adb devices`, `adb -s <serial> install -r <apk>`. No MCP server.
- `claude/.claude/skills/hotwire-native/agents/openai.yaml` — `interface` block, implicit invocation allowed.

Vendored snapshots (R7):

- `claude/.claude/skills/mobilebuildmcp/SKILL.md` — upstream copy, unwrapped per the existing re-sync steps, with the upstream comment line.
- `claude/.claude/skills/mobilebuildmcp/LICENSE` — upstream `LICENSE`, unchanged.
- `claude/.claude/skills/mobilebuildmcp/agents/openai.yaml` — `interface` block.
- `claude/.claude/skills/android-intent-security/SKILL.md`, `LICENSE.txt`, `agents/openai.yaml` — same pattern. Upstream frontmatter already says `license: Complete terms in LICENSE.txt`.
- `agents/.agents/skills/{hotwire-native,mobilebuildmcp,android-intent-security}` — relative symlinks `../../../claude/.claude/skills/<name>`, like the existing ones.
- `VENDORED-SKILLS.yml` (new, repo root) — the manifest. One entry per new snapshot: `skill`, `upstream` (URL), `tag`, `commit` (full SHA), `licence` (SPDX), `snapshot_date`, `paths` (upstream paths copied).
- `VENDORED-LICENSES.md` — one short section per new upstream that points to the licence file in the skill folder and to `VENDORED-SKILLS.yml`.

Discovery (R11):

- `SKILLS-INDEX.md` — a new "Mobile" section with the three skills and their triggers, and one sentence naming `VENDORED-SKILLS.yml`.
- `test/skill_parity_test.rb` — no list change: all three skills are shared, so `CLAUDE_ONLY` and `CODEX_ONLY` stay as they are. The existing tests must pass with the new folders.

Tooling (R8, R9):

- `claude/.claude/skills/hotwire-native/references/ios.md` — a "Setup" section, not `HEADROOM.md`. `HEADROOM.md` is imported into every Claude session through `CLAUDE.md`, so a line there costs context in every session. `ios.md` loads only for iOS work. The section holds `claude mcp add --scope user -e MOBILEBUILDMCP_SENTRY_DISABLED=true MobileBuildMCP -- npx -y mobilebuildmcp@2.7.1 mcp`, the warning that a live session rewrites `~/.claude.json`, and a pointer to the Codex block. Spec R8 and A12 named `HEADROOM.md`; Etienne chose `ios.md` during planning, and `spec.md` is amended to match in its own commit at plan acceptance.
- `codex/.codex/config.toml` — `[mcp_servers.MobileBuildMCP]` with `command = "npx"`, `args = ["-y", "mobilebuildmcp@2.7.1", "mcp"]`, `tool_timeout_sec = 600`, and `env = { MOBILEBUILDMCP_SENTRY_DISABLED = "true" }`. Verify the `env` key against the Codex config documentation before writing it. If Codex blocks or errors loudly on a machine without Xcode, stop and report to Etienne. Do not move or remove the block without his decision, since R8 requires it in `config.toml`.
- `codex/.codex/rules/default.rules` — one rule: `prefix_rule(pattern = ["adb", "devices"], decision = "allow", justification = "lists attached Android devices; read-only", match = [["adb", "devices"]])`.

New tests:

- `test/mobile_testing_exception_test.rb`, `test/vendored_skills_test.rb`, `test/hotwire_native_skill_test.rb`, `test/mobile_tooling_test.rb` — see Proof.

Spelling:

- `project-dictionary.txt` — new words cspell rejects (for example `mobilebuildmcp`, `adb`, `Kotlin`), added only after cspell reports them.

## Order of work

0. Rebase this branch onto `origin/main` (`sync` skill). Re-check that every file above exists in the stated form. Report any difference instead of improvising.
1. Write `test/mobile_testing_exception_test.rb`. Run it. Watch it fail because `agents.md` lacks the exception.
2. Add the canonical exception to `agents.md`, then `rails-testing`, `code-review`, `plan`, `implement`, `spec`, `test-writer.md` and `implementer.md`, one file per green run. Add the `check:` Proof form to `plan` and the matching handling to `implement`, `test-writer.md` and `implementer.md`. Regenerate both Codex agents. Run `test/codex_agent_generation_test.rb`. Commit.
3. Write `test/hotwire_native_skill_test.rb`. Watch it fail on the missing skill. Write `hotwire-native/SKILL.md`, both references and `agents/openai.yaml`. Add the symlink. Run the skill test and `skill_parity_test.rb`. Commit.
4. Write `test/vendored_skills_test.rb`. Watch it fail on the missing manifest. Copy the two upstream skills at the pinned commits (`gh api repos/<repo>/contents/<path>?ref=<sha>`), add the licence files, the upstream comment, `agents/openai.yaml`, and the symlinks. Unwrap prose with the existing markdownlint unwrap command. Write `VENDORED-SKILLS.yml` and the `VENDORED-LICENSES.md` sections. Add the "Mobile" section to `SKILLS-INDEX.md`, since `vendored_skills_test.rb` checks it. Commit.
5. Write `test/mobile_tooling_test.rb`. Watch it fail. Add the `ios.md` Setup section, the `config.toml` block and the `default.rules` rule. Run `guard_parity_test.rb`. Commit.
6. Run the full suite (`ruby -Itest -e 'Dir["test/*_test.rb"].each { |f| require_relative f }'` or the repo's lefthook equivalent), markdownlint with the no-hardwrap rule on every new markdown file, cspell, yamllint, and `ruby -c`. Add dictionary words. Commit.
7. Manual checks (A1, A2, A13, A15, A18), outputs recorded in the PR body:
   - `curl -sSfIL` every native.hotwired.dev and `github.com/hotwired/*` link in the skill (A18).
   - The installed skills under `~/.claude/skills` and `~/.agents/skills` are the old ones, and Stow is not allowed. So build a scratch directory in the session scratchpad, with a `.swift` and a `.kt` file, and project-local symlinks `.claude/skills/<name>` and `.agents/skills/<name>` into this worktree's three new skill folders. First confirm, from the Claude and Codex documentation, that each tool loads project-local skills from those paths. If one does not, record that check as pending until Etienne stows the merged branch. In a fresh `claude -p` and `codex exec` session there, ask: "add a native navigation behaviour", "fix a button on this screen", "build the app". Record whether each agent opens the skill and the right reference, leaves versions alone, and names or asks for worktree, scheme or variant, and device (A1, A2, A15).
   - After Etienne registers MobileBuildMCP, list its tools from a clean shell and confirm build and simulator tools appear (A13). Etienne runs the install; the executor never does.
8. Re-read the full diff. Run `review`.

## Risks

- Main moved by 238 files. The rebase can conflict in `agents.md`, `SKILLS-INDEX.md`, `default.rules` and `project-dictionary.txt`. Resolve each on its merits.
- The active Codex block makes every Codex launch spawn `npx mobilebuildmcp@2.7.1`, on Linux too. Verify in step 7 that Codex starts normally on a machine without Xcode and only logs the failed server. If Codex blocks or errors loudly, stop and report to Etienne; do not change the block on your own.
- `npx` fetches a package on first launch. That is the dependency Etienne approves by accepting this plan, pinned to `2.7.1`.
- Telemetry stays on if the env var name changes upstream. The test pins the name to the value in this plan; re-check the privacy page on every version bump.
- The upstream `mobilebuildmcp` skill says to prefer its tools over raw `xcodebuild`. `ios.md` keeps `xcodebuild` as a fallback only when the server is not registered, so the two do not contradict.
- The exception could read as permission to skip tests for logic hidden in Swift or Kotlin. The matrix names logic, security and regressions as test-required, and the code-review skill carries the same text.
- The manifest covers new snapshots only. The 16 superpowers-ruby skills keep their existing convention; `vendored_skills_test.rb` skips skills whose upstream comment names `lucianghinda/superpowers-ruby`. Backfilling them into the manifest is a separate PR.
- Rejected: upstream plugins (D1), separate iOS, Android and bridge skills (D2), a mobile-only rule file (D3), `@latest` (D4), Gradle allow rules (Etienne declined), `testing-setup`, `navigation-3`, `edge-to-edge`, `android-cli` (see Context).

## Out of scope

- The private work overlay and the application repository.
- Installing MobileBuildMCP, Node, Xcode, the Android SDK or any other tool.
- Any Android MCP server.
- Hotwire Native SDK upgrades, app fixes, release work and CI changes.
- `core-values.yml` and `markdown_rule_mirror_test.rb`: no test-first line is mirrored today.
- Backfilling superpowers-ruby skills into `VENDORED-SKILLS.yml`.
- Plugin or marketplace entries in `claude/.claude/settings.json`.
- `claude/.claude/HEADROOM.md`: it stays the Headroom and always-on MCP document.

## Proof

- A1 (R1, R2) → `test/hotwire_native_skill_test.rb` `test_skill_routes_swift_files_to_the_ios_reference_and_kotlin_files_to_the_android_reference`; manual session check in step 7.
- A2 (R3) → `test/hotwire_native_skill_test.rb` `test_skill_forbids_framework_and_sdk_migrations_unless_asked`; manual session check in step 7.
- A3 (R4) → `test/hotwire_native_skill_test.rb` `test_matrix_validates_native_ui_with_build_lint_and_a_device_check`
- A4 (R4) → `test/hotwire_native_skill_test.rb` `test_matrix_names_a_web_side_and_a_native_side_check_for_bridge_components`
- A5 (R4) → `test/hotwire_native_skill_test.rb` `test_matrix_requires_an_automated_test_for_logic_security_and_regressions_with_the_regression_test_first`
- A6 (R5) → `test/hotwire_native_skill_test.rb` `test_skill_limits_rails_architecture_and_ruby_style_to_the_rails_side`
- A7 (R6) → `test/mobile_testing_exception_test.rb` `test_every_listed_instruction_states_the_mobile_exception` and `test_no_file_says_never_generate_code_without_a_test_without_the_exception`
- A8 (R6) → `test/mobile_testing_exception_test.rb` `test_rails_testing_still_requires_tests_first_for_rails_code`
- A9 (R7) → `test/vendored_skills_test.rb` `test_every_snapshot_folder_has_a_complete_manifest_entry` and `test_every_snapshot_folder_holds_its_upstream_licence_file`
- A10 (R7, D1) → `test/vendored_skills_test.rb` `test_no_marketplace_points_at_a_vendored_upstream`
- A11 (R7, R11) → `test/skill_parity_test.rb` (existing tests, unchanged)
- A12 (R8) → `test/mobile_tooling_test.rb` `test_claude_and_codex_pin_the_same_exact_mobilebuildmcp_version` and `test_ios_setup_warns_that_a_live_session_rewrites_claude_json`
- A13 (R8) → check: list the registered server's tools from a clean shell after Etienne installs it; output in the PR body.
- A14 (R9) → `test/hotwire_native_skill_test.rb` `test_android_reference_uses_the_gradle_wrapper_and_adb_and_names_no_mcp_server`
- A15 (R10) → `test/hotwire_native_skill_test.rb` `test_skill_requires_worktree_scheme_or_variant_and_device_before_a_build`; manual session check in step 7.
- A16 (R11) → `test/vendored_skills_test.rb` `test_skills_index_lists_every_new_mobile_skill`
- A17 (R12) → check: the reviewer runs a case-insensitive search of the diff with the denylist Etienne supplies; the denylist is never committed.
- A18 (R1) → check: `curl -sSfIL` on every upstream link in the skill.
- A19 (R6, R4) → check: full suite, markdownlint no-hardwrap, cspell, yamllint, `ruby -c` all green.

Per changed file, the unit tests expected:

- `test/mobile_testing_exception_test.rb`: `every listed instruction states the mobile exception` (one assertion per file: `agents.md`, `rails-testing`, `code-review`, `implement`, `plan`, `spec`, `test-writer.md`, `implementer.md`), `no file says never generate code without a test without the exception`, `rails testing still requires tests first for rails code`, `plan skill defines the check proof line`.
- `test/vendored_skills_test.rb`: `every snapshot folder has a complete manifest entry`, `every manifest entry points at an existing skill folder`, `every snapshot folder holds its upstream licence file`, `manifest commits are full forty-character SHAs`, `no marketplace points at a vendored upstream`, `skills index lists every new mobile skill`.
- `test/hotwire_native_skill_test.rb`: the eight A1–A6, A14, A15 tests above, plus `skill links upstream docs instead of restating them` (names native.hotwired.dev and each `hotwired/hotwire-native-*` repository) and `vendored skill dependency demands yield to the consent rule`.
- `test/mobile_tooling_test.rb`: `claude and codex pin the same exact mobilebuildmcp version`, `no mobilebuildmcp registration uses latest`, `both registrations disable sentry telemetry`, `ios setup warns that a live session rewrites claude json`.

D5 reading: `mobile_tooling_test.rb` is a drift guard between two files that must agree, in the same way as `guard_parity_test.rb`. It does not test that a key exists for its own sake. Etienne confirmed this reading during planning.

Test setup: plain Minitest reading repo files by path from `REPO_ROOT`, like `skill_parity_test.rb`. A snapshot folder is a skill folder whose `SKILL.md` carries an `<!-- upstream: ... -->` comment that does not name `lucianghinda/superpowers-ruby`. YAML through `YAML.safe_load_file`. No network, no `~` paths, no fixtures.
