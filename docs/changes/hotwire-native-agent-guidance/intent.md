# Intent: Hotwire Native guidance for AI coding agents

Author: Etienne van Delden. Status: accepted. Type: chore.

## Problem

The current agent guidance focuses on Rails and web development. It does not give Claude and Codex a clear basis for working on Hotwire Native apps, where server-rendered content, native navigation, bridge components, and platform lifecycle behavior must work together.

Blanket test-first instructions can lead agents to invent tests for simple native UI settings and wiring. Rails-specific architecture and validation instructions also need clear boundaries so they do not govern Swift and Kotlin code.

## Proposed outcome

- Public dotfiles provide reusable Hotwire Native, iOS, and Android guidance that both Claude and Codex can discover and apply to relevant work.
- Selected upstream mobile skills and build/simulator tooling support development, including MobileBuildMCP for iOS and Gradle/adb workflows for Android.
- Private work dotfiles contain personal work-app setup and device-testing guidance that cannot be published in public dotfiles.
- The work application's repository provides standalone team guidance that colleagues' agents can use without installing these personal dotfiles.
- Native UI, configuration, and straightforward wiring may use build, lint, and simulator/device checks instead of mandatory test-first development. Meaningful logic, security-sensitive behavior, and regressions retain automated tests; the Rails/web testing policy remains in place.
- Agents preserve each app's existing Hotwire Native structure and supported platform versions rather than treating mobile guidance as a request for framework migrations.

## Affected users and systems

Etienne's Claude and Codex sessions, colleagues' agents working on the shared application, the public dotfiles repository, the private work dotfiles repository, and the application's Rails, iOS, and Android guidance.

This draft coordinates the three repository changes. Repository-specific artifacts and private implementation details belong in their respective isolated worktrees during the later stages.

## Constraints

- Keep company information, internal discussion content, private hosts, signing details, and credentials out of public dotfiles and public change artifacts.
- Keep personal environment preferences in the private overlay; put shared application conventions in the application repository.
- Scope platform guidance to the affected language, framework, and behavior. Preserve web/native compatibility and existing app architecture.
- Make the mobile testing exception consistent across applicable instructions and workflows so a blanket rule elsewhere does not negate it.
- This change covers agent guidance and selected development tooling. Application fixes, SDK/framework migrations, release work, and CI changes are outside this intent.
- Preserve existing uncommitted work. Use isolated worktrees and the intent, spec, plan, and implement stages before implementation.
- Do not install or change system runtimes, run Stow, or modify existing symlinks as part of drafting this intent.

## Success criteria

- Both personal agents find the applicable mobile guidance and select validation appropriate to a representative native UI change, bridge change, and logic regression.
- Colleagues can obtain the same application-specific guidance from the shared repository alone.
- Simple native wiring does not require invented unit tests, while meaningful logic and security-sensitive boundaries retain test coverage.
- The public change contains only reusable public guidance and tooling information; personal work setup stays private.
- The selected tooling can build and inspect the intended local app target without guessing the active worktree, scheme, variant, or device.

## Open questions

- Manage selected upstream skills as pinned source snapshots in the shared skill layout, or through upstream plugins? Pinned snapshots are the proposed default; this choice is not yet confirmed.
- No issue was supplied. This chore uses the slug `hotwire-native-agent-guidance`.
