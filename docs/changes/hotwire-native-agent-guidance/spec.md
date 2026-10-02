# Spec: Hotwire Native guidance for AI coding agents

From `intent.md` (2026-10-02). Status: accepted.

Scope of this spec: the public dotfiles repository only. The private work overlay and the application repository get their own specs; section "Integration points" states what they must not duplicate or contradict.

## Flagged concerns

- The playbook's test-first rule (§7 rule 3) and `rails-testing` ("all generated code must be driven from tests") conflict with the intent's mobile exception. The `plan` and `implement` skills also demand one acceptance test per criterion and a Proof list. A carve-out in the playbook alone is negated by those skills, so the carve-out must land in all of them (R6).
- `core-values.yml` mirrors no test-first line today, so the mirror needs no change. If a later edit adds one, the playbook, `core-values.yml` and `markdown_rule_mirror_test.rb` move together.
- The community Hotwire Native skills on GitHub are unofficial. One has no licence, one derives from a paid book, and none is official. They cannot be pinned snapshots (see Design decision D1).
- `android/skills` nests sub-skills (for example `navigation/navigation-3`). Skill discovery expects `<name>/SKILL.md`. The plan must flatten or select leaf skills and record the mapping in the manifest.
- MobileBuildMCP sends runtime error telemetry to Sentry. The upstream README names a privacy page with an opt-out. The plan must verify the exact opt-out setting from that page before writing it into any config.
- Permission prefixes for the Gradle wrapper and `adb` do not exist in `codex/.codex/rules/default.rules` (only `xcodebuild` has them). Adding allow rules changes the consent surface, so Etienne confirms the exact list at plan acceptance (R9).

## Requirements

- R1. A public skill named `hotwire-native` exists. It covers how Hotwire Native apps fit together: server-rendered web content, path configuration, native navigation, bridge components, and platform lifecycle. It links the primary upstream documentation (native.hotwired.dev and the `hotwired/hotwire-native-*` repositories) instead of restating it.
- R2. The `hotwire-native` skill keeps platform detail in `references/`: one file for iOS (Swift) and one for Android (Kotlin). `SKILL.md` stays short and routes to the right reference by the files being touched.
- R3. The skill tells the agent to preserve the app's existing Hotwire Native structure and supported platform versions. It forbids framework or SDK migrations, version bumps and structural rewrites unless the task asks for one.
- R4. The skill contains a validation matrix that maps a change type to the checks that satisfy "done". Minimum rows: native UI or configuration, simple wiring, bridge component (web side and native side), meaningful logic, security-sensitive behaviour, regression fix.
- R5. The skill states the Rails boundary: Rails architecture, strong parameters and Ruby style rules govern the Rails side only. They do not govern Swift or Kotlin. Web code that serves native clients keeps web compatibility.
- R6. The mobile testing exception appears consistently in every applicable instruction: `agents.md` rule 3 (and the worktree-visible copy it feeds), `rails-testing`, `code-review`, `implement`, `plan` and `spec`. Wording is identical in meaning everywhere: native UI, configuration and straightforward wiring may use build, lint and simulator or device checks. Meaningful logic, security-sensitive behaviour and regressions keep automated tests. The Rails and web policy is unchanged.
- R7. Selected third-party mobile skills are brought in as pinned source snapshots under the shared skill layout (`claude/.claude/skills/<name>/`), linked for Codex through `agents/.agents/skills/`. A single manifest records, per snapshot: upstream URL, release tag, full commit SHA, licence, snapshot date, and the upstream paths copied. Each snapshot keeps its upstream licence file.
- R8. MobileBuildMCP (Sentry's MobileBuildMCP repository, formerly XcodeBuildMCP, MIT) is documented for iOS build, simulator and inspection work, pinned to an exact version. Registration instructions exist for Claude (`claude mcp add`, in `HEADROOM.md` style) and Codex (`[mcp_servers.*]` in `codex/.codex/config.toml`). No install happens in this change.
- R9. Android validation is documented as plain Gradle wrapper and `adb` commands, with no MCP server. Allow rules for the read-only and build subset (Gradle wrapper build, lint and test tasks, `adb devices`) are proposed in the plan for Etienne's approval, not added silently.
- R10. The skill requires explicit targeting before any build or device command: the active worktree path, scheme (iOS) or variant (Android), and device or simulator identifier. It tells the agent to read these from the project or ask, and never to guess.
- R11. `SKILLS-INDEX.md` lists every new skill with its trigger, so Codex can find it. The `skill_parity_test.rb` shared and Claude-only lists are updated to match.
- R12. Public content contains no company, product or colleague names, no internal hosts, bundle identifiers, signing details, device names or credentials. Personal work-app setup and device-testing notes stay in the private overlay. Standalone team guidance stays in the application repository.

## Design decisions

- D1. Distribution of upstream skills. Recommendation: pinned source snapshots for third-party skills, and a first-party `hotwire-native` skill written here.
  - Why snapshots: the repo shares one skill source between Claude and Codex through stow symlinks and a parity test. Plugins reach only the client that supports them and add a second update channel that can drift unseen. A pinned tag plus SHA gives reviewable diffs and reproducible behaviour for both agents.
  - Why first-party for Hotwire Native: no official Hotwire Native skill exists. The three community skills found are unofficial, and one has no licence. The skill links the official documentation, so upstream stays the source of truth.
  - Which snapshots: the MobileBuildMCP skill (its bundled skill, MIT, pinned to the release in R8) and a small selection from `android/skills` (Apache-2.0, pinned to a release tag). The plan picks the Android leaf skills that suit WebView-hosting shell apps, with `testing` and `navigation` as candidates.
  - Why not plugins: `android/skills` ships a Claude and Codex plugin manifest, but enabling it would add an update path outside the manifest. Revisit if upstream stops tagging releases.
  - Confirm or reject at spec acceptance.
- D2. One authored skill with references rather than separate iOS, Android and bridge skills. Why: the three areas share the same web contract, and one trigger avoids three partial loads.
- D3. The testing exception lives next to the existing rule, not in a new mobile-only rule file. Why: a separate file is easy to miss, and the intent requires that no blanket rule elsewhere negates it.
- D4. Pin versions in config, not "latest". Why: the intent asks for tooling that builds the intended target predictably, and unpinned `npx` fetches change behaviour without a diff.
- D5. Tests in this repo follow the repo rule on meta-tests. Tests cover behaviour the repo owns: manifest completeness, symlink parity and wording consistency of the exception. They do not assert that config keys exist.

## Integration points

- `agents.md` (symlinked as `claude/.claude/PLAYBOOK.md`), `codex/.codex/PLAYBOOK.md`, `claude/.claude/core-values.yml`, `test/markdown_rule_mirror_test.rb`: the rule 3 carve-out and mirror check.
- `claude/.claude/skills/{rails-testing,code-review,implement,plan,spec}/SKILL.md`: exception wording (R6).
- `claude/.claude/skills/` (new skills), `agents/.agents/skills/` (symlinks), `test/skill_parity_test.rb`, `SKILLS-INDEX.md`.
- `claude/.claude/HEADROOM.md` and `codex/.codex/config.toml`: MobileBuildMCP registration (R8). `codex/.codex/rules/default.rules`: proposed Gradle and `adb` rules (R9).
- Private work dotfiles: contains the personal work-app setup and device-testing guidance. It layers on top of this skill and may restate no public content.
- Application repository: carries standalone team guidance that does not need these dotfiles. It reuses the validation matrix and exception wording by copy, so this skill keeps both free of personal paths and tool preferences.
- Upstream sources: native.hotwired.dev, `hotwired/hotwire-native-ios` (1.3.1 at drafting), `hotwired/hotwire-native-android` (1.3.1 at drafting), `hotwired/hotwire-native-bridge`, Sentry's MobileBuildMCP repository (v2.7.1, commit `d13ff0c707b0681769cf31da0eb42c4f94ceafff`), `android/skills` (v1.0.13, commit `42dc2270e96032bd860bb94511e440aa00a43125`). The plan re-checks the latest tags before pinning.

## Acceptance criteria

- A1 (R1, R2). An agent asked to add a native navigation behaviour finds the `hotwire-native` skill and opens the platform reference for the files it touches.
- A2 (R3). Asked to fix a button on a screen, the agent changes that screen and leaves the app's Hotwire Native version and structure alone.
- A3 (R4). For a native UI change the matrix says build, lint and a simulator or device check, and not "write a unit test".
- A4 (R4). For a bridge component the matrix names both sides: web markup and controller, and native component, each with its own check.
- A5 (R4). For logic, security-sensitive behaviour and a regression fix the matrix requires an automated test, and the regression test comes first.
- A6 (R5). When an agent edits Swift or Kotlin, the Rails architecture and Ruby style rules are not applied to it.
- A7 (R6). Every instruction file listed in R6 states the same exception, and none still says "never generate code without a corresponding test" without it. A repo test greps the listed files for the exception and fails when one is missing.
- A8 (R6). A Rails model change still requires a failing test first.
- A9 (R7). Every directory in the snapshot manifest has an entry with URL, tag, commit SHA, licence, date and copied paths, and holds the upstream licence file. A repo test fails when a snapshot directory has no manifest entry or no licence file.
- A10 (R7, D1). No plugin or marketplace entry for the selected upstream skills is added to `claude/.claude/settings.json`.
- A11 (R7, R11). Each new skill exists once under `claude/.claude/skills/` and is a symlink under `agents/.agents/skills/`, and `skill_parity_test.rb` passes.
- A12 (R8). The registration commands for Claude and the Codex config block name an exact MobileBuildMCP version, and `HEADROOM.md` warns that a live session overwrites `~/.claude.json`.
- A13 (R8). Running the registered MCP server's tool list from a clean shell, after Etienne installs it, shows the build and simulator tools. This is checked by hand and the result is reported in the plan's verification step.
- A14 (R9). The Android section builds, lints and tests with the Gradle wrapper and checks devices with `adb devices`. It mentions no MCP server.
- A15 (R10). Asked to build the app, the agent names the worktree path, scheme or variant, and device before running the command, and asks when one is unknown.
- A16 (R11). `SKILLS-INDEX.md` lists each new skill with its trigger.
- A17 (R12). A case-insensitive search of the public diff and the new files for the company, product and colleague names Etienne supplies, plus hostnames, bundle identifiers and signing terms, returns nothing. The reviewer runs it, since the denylist itself must not be committed.
- A18 (R1). The skill's links to native.hotwired.dev and the `hotwired` repositories resolve when fetched.
- A19 (R6, R4). Linters and the repo test suite pass, and `markdownlint` finds no hard-wrapped prose in any new markdown file.

---
Domain skills applied: rails-ui (Hotwire, Stimulus and Turbo boundaries), rails-testing (test policy and meta-test rule), dependencies (pinning and consent for tooling), dotfiles-maintenance (skill layout, stow and symlink rules, mirror files).
