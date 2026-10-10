# Review: merge-colleague-hotwire-native-guidance

## Round 1 — 2026-10-09T22:13Z — bbba3ec2

- [x] Important: The iOS sessions line states two upstream behaviours that `native.hotwired.dev/ios/reference` does not back as worded. "The app handles a 401 by presenting its login screen" is only a code example the app writes itself in its error handler (`case .http(.client(.unauthorized)): // Present your login screen.`), not built-in behaviour. "Web views share cookies through their configuration" is, upstream, a custom `WKProcessPool` set through `Hotwire.config.makeCustomWebView` to share cookies with web views outside Hotwire Native. An agent reads both as defaults to rely on. The intent requires every restated claim to be backed by its page. — `claude/.claude/skills/hotwire-native/references/ios.md:18` → fixed (docs: state the iOS session behaviours as app code and a custom process pool)
- [x] Nit: `test_shared_rules_appear_in_both_references` asserts only that `shared_rule_gaps` is empty. The plan's Proof also requires that every `SHARED_RULES` phrase matches both files. A rule removed from both references passes this test; only the per-rule tests catch it. — `test/hotwire_native_skill_test.rb:183` → fixed (test: anchor rule assertions on key phrases and check every shared rule)
- [x] Nit: `assert_rule` takes the first line that matches the first pattern. The sessions assertion starts with `/cookies/i`, so it depends on "Preserve cookies" coming before "Never log tokens, cookies". If the two lines swap, the test fails although both rules are present. Anchoring on the rule's key phrase from `SHARED_RULES` avoids this. — `test/hotwire_native_skill_test.rb:219` → fixed (test: anchor rule assertions on key phrases and check every shared rule)
- [x] Nit: The cleanup lines pair "the controller disconnects" with `onStop` / `onViewWillDisappear`. Upstream, those hooks fire when the destination stops or its view leaves the hierarchy, not when the Stimulus controller disconnects; a disconnect reaches native only if the web component sends a message. The sentence can make an agent think the hook covers both cases. — `claude/.claude/skills/hotwire-native/references/android.md:17` → fixed (docs: tie iOS bridge cleanup to the view lifecycle hooks; docs: tie Android bridge cleanup to onStop and onStart)
- [x] Nit: The commits do not follow the plan's Order of work. The plan names one commit per section group across both files (contracts, traps, prerequisites and reporting); the branch has one commit per platform. Each commit is still one logical change. — `docs/changes/merge-colleague-hotwire-native-guidance/plan.md` → dismissed: each commit holds one logical change; grouping by file keeps each reference's diff readable in one commit, and the plan's order of work is guidance, not an acceptance criterion
- [x] Nit: The branch is 19 commits behind `origin/main` (PR #191 and others). Rebase before the push (playbook rule 20). `git merge-tree` shows no conflict. — `(branch)` → fixed (rebased onto origin/main at 96625a85, no conflicts)

### Compliance

- Path configuration ordered contract, linked → `test_both_references_state_path_configuration_as_an_ordered_contract`.
- Bridge component one contract, read every side, linked → `test_both_references_state_the_bridge_component_as_one_contract`.
- Progressive enhancement → `test_both_references_state_progressive_enhancement`.
- Cleanup on disconnect → `test_both_references_require_cleanup_on_disconnect`.
- Cookies, sessions, no logging → `test_both_references_preserve_sessions_and_never_log_secrets` (see the Important finding on the iOS line's content).
- Untrusted destinations; Android Intents through the vendored skill → `test_both_references_validate_untrusted_destinations`, `test_android_reference_validates_intents_and_exported_components_with_the_vendored_skill`.
- Android lifecycle traps → `test_android_reference_names_its_lifecycle_traps`.
- iOS lifecycle traps → `test_ios_reference_names_its_lifecycle_traps`.
- Three-way report split → `test_both_references_report_checks_observations_and_untested_behaviour_separately`.
- Skill prerequisites → `test_both_references_check_skill_prerequisites_before_applying_a_skill`.
- Links on every restated rule → same-line link assertions in the tests above.
- Positive tests fail on `main`, parity fails one-sided → `test_parity_check_reports_a_rule_present_in_one_reference_only`, `test_shared_rules_appear_in_both_references` (see Nit on line 183); red-first not re-run in this review.
- `SKILL.md` and mobile tests unchanged → `git diff --exit-code origin/main` clean; mobile tests green; no `MCP` in `android.md` guarded by the existing test.
- No blanket regression rule → `test_references_leave_the_testing_rule_to_the_mobile_exception`.
- No company names, hosts, bundle IDs, signing details → privacy grep on `git diff origin/main...HEAD` prints nothing.
- No persona or Copilot framing → `test_references_carry_no_persona_or_copilot_framing`.
- Markdown and suite → markdownlint `no-hardwrap` passes on both references and the change folder; `rubocop` clean.

Every test named in the plan's Proof exists. No existing test was weakened, skipped or deleted.

### Checks run

- `test/hotwire_native_skill_test.rb`: 26 runs, 0 failures. `test/mobile_testing_exception_test.rb` and `test/mobile_tooling_test.rb`: green.
- Full `test/` suite: not complete in this environment. `test/agent_worktree_test.rb` and `test/herdr_worker_scripts_test.rb` fail and `test/lefthook_pull_hooks_test.rb` hangs. The `agent_worktree` errors come from the SSH agent refusing to sign commits (`commit.gpgsign = true`, `gpg.format = ssh`); the other two were not diagnosed. No such file is touched by this branch. Re-run the suite with the agent unlocked before the push.
- Security pass: documentation and tests only; links go to official Hotwire, Apple, Android, Kotlin and Swift pages. Nothing found.
- Upstream spot checks (2026-10-09): path configuration override order, navigation external URLs and route decision handlers, Android registration in the `Application` subclass with `BridgeComponentFactory`, and the `onStop` / `onViewWillDisappear` / `onViewDidDisappear` hooks are backed as written.

## Round 2 — 2026-10-09T22:15Z — bbba3ec2 (codex)

- [x] Important: Distinguish Android `onStop` from component removal. When a destination becomes inactive, `onStop` runs even if its fragment remains and may later resume. `BridgeComponent` only forwards this lifecycle event; it does not remove controls or callbacks automatically. The wording can lead an agent to tear down controls without restoring them on `onStart`, or to assume `onStop` handles web-controller disconnects. Clarify that `onStop` means inactive, and pair cleanup with restoration or actual disconnect handling. — `claude/.claude/skills/hotwire-native/references/android.md:17` → fixed (docs: tie Android bridge cleanup to onStop and onStart)

## Round 3 — 2026-10-10T06:03Z — b91c23b8

- [x] Important: The iOS cleanup rule tells the agent to remove controls in `onViewWillDisappear` / `onViewDidDisappear`, but upstream source shows those hooks often never reach the component. `BridgeDelegate` forwards lifecycle events only to `activeComponents`, which is empty once `bridge` is nil (`Source/Bridge/BridgeDelegate.swift`, `destinationIsActive`). On a push, `NavigationHierarchyController.navigate` calls `session.visit` before `pushViewController`; `Visit.start` → `Session.visitWillStart` → `activateVisitable` deactivates the old visitable first, so its `onViewWillDisappear` and `onViewDidDisappear` reach no component. On a pop, `VisitableViewController.viewDidDisappear` runs `Session.visitableViewDidDisappear` → `deactivateVisitable` inside `super`, before `HotwireWebViewController` calls `bridgeDelegate.onViewDidDisappear()`, so that hook reaches no component either. Android differs: `BridgeDelegate.onStop` forwards to components before it sets `destinationIsActive = false`, so the Android line holds. An agent that follows the iOS line puts cleanup where it does not run on the main forward path. Traced in source at `hotwire-native-ios` `main` (2026-10-10), not on a simulator. — `claude/.claude/skills/hotwire-native/references/ios.md:17` → fixed (docs: ground iOS bridge cleanup in per-destination components and an idempotent onReceive)
- [x] Nit: Both cleanup lines say to restore controls in `onStart` / `onViewWillAppear`. On return, Turbo renders the restored page and the Stimulus controller connects again, which sends `connect` and reaches `onReceive` a second time. If both paths add the control or register the callback, the result is the duplicate action the rule wants to prevent. The line can say that the restore must be idempotent with what `onReceive` adds. — `claude/.claude/skills/hotwire-native/references/android.md:17` → fixed (docs: ground iOS bridge cleanup in per-destination components and an idempotent onReceive; docs: ground Android bridge cleanup in per-destination components and an idempotent onReceive)
- [x] Nit: `test_both_references_require_cleanup_on_disconnect` asserts `/disconnect/i`, which now matches only the negation "not that the web controller disconnected". The test name and that assertion describe cleanup on disconnect, which the rule no longer says. A rename (for example `..._require_cleanup_when_the_destination_goes_inactive`) and an assertion on the inactive wording would match the rule. — `test/hotwire_native_skill_test.rb:126` → fixed (test: expect repeat-visit cleanup through onReceive and lifecycle hooks as overrides)

### Compliance

- Round 1 and round 2 findings are all closed with a commit subject or a reason.
- Cleanup criterion → `test_both_references_require_cleanup_on_disconnect` passes; see the Important finding on the iOS content and the Nit on the test.
- Every other acceptance criterion maps to the same test as in round 1. Every test named in the plan's Proof exists. No existing test was weakened, skipped or deleted.
- `SKILL.md`, `test/mobile_testing_exception_test.rb` and `test/mobile_tooling_test.rb` unchanged against `origin/main`.
- Privacy grep on `git diff origin/main...HEAD -- claude test` prints nothing.

### Checks run

- `test/hotwire_native_skill_test.rb`: 26 runs, 430 assertions, 0 failures. Mobile tests green. `rubocop test/hotwire_native_skill_test.rb` clean. markdownlint `no-hardwrap` passes on both references and the change folder.
- Full `test/` suite, per file with a 90 s limit: all green except `test/review_report_check_test.rb` (1 error: `git commit --quiet -m advance main failed` in its temporary repository) and `test/herdr_worker_scripts_test.rb` (does not finish). The branch does not touch either file. Same pattern as round 1: environmental, not diagnosed here.
- Branch is current with `origin/main` (0 commits behind).
- Security pass: documentation and tests only; all links go to official Hotwire, Apple, Android, Kotlin and Swift pages or the `hotwired` repositories. Nothing found.

## Round 4 — 2026-10-10T04:30Z — b91c23b8 (codex)

- [x] Important: Describe lifecycle hooks as callbacks, not automatic cleanup. The Android `BridgeComponent` and iOS `BridgeComponent` only forward lifecycle events; their default hooks do nothing. The wording implies the library removes controls and callbacks automatically. Tell agents to implement cleanup and restoration in their component overrides. The same claim appears in both platform references. — `claude/.claude/skills/hotwire-native/references/android.md:17` → fixed (docs: ground iOS bridge cleanup in per-destination components and an idempotent onReceive; docs: ground Android bridge cleanup in per-destination components and an idempotent onReceive)
