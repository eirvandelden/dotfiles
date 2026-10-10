#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"

# The hotwire-native skill is first-party guidance the repo owns: how its routing, validation matrix and
# targeting rules read is behaviour an agent acts on (docs/changes/hotwire-native-agent-guidance/plan.md).
class HotwireNativeSkillTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILL_DIR = File.join(REPO_ROOT, "claude/.claude/skills/hotwire-native")
  REFERENCES = %w[ios android].freeze
  SHARED_RULES = {
    path_configuration: /later matching rule overrides/i,
    bridge_component: /read every side before changing one/i,
    progressive_enhancement: /hide web UI only when the native side supports/i,
    cleanup: /repeat visit shows no stale/i,
    lifecycle_hooks: /lifecycle hooks are overrides/i,
    sessions: /session expiry/i,
    logging: /never log/i,
    untrusted_destinations: /untrusted destinations/i,
    report_split: /three separate/i,
    skill_prerequisites: /prerequisites/i
  }.freeze

  def test_skill_routes_swift_files_to_the_ios_reference_and_kotlin_files_to_the_android_reference
    skill = read("SKILL.md")
    assert_row(skill, /\*\.swift/, "references/ios.md")
    assert_row(skill, /\*\.kt/, "references/android.md")
    assert_row(skill, /BridgeComponent/, "references/ios.md", "references/android.md")
  end

  def test_skill_forbids_framework_and_sdk_migrations_unless_asked
    skill = read("SKILL.md")
    assert_match(/preserve/i, skill)
    assert_match(/never[^.]*(migrat|bump|upgrade)[^.]*unless the task asks/i, skill)
  end

  def test_matrix_validates_native_ui_with_build_lint_and_a_device_check
    row = matrix_row("Native UI or configuration")
    assert_match(/build/i, row)
    assert_match(/lint/i, row)
    assert_match(/simulator or device/i, row)
    refute_match(/unit test/i, row)
  end

  def test_matrix_names_a_web_side_and_a_native_side_check_for_bridge_components
    web = matrix_row("Bridge component, web side")
    native = matrix_row("Bridge component, native side")
    assert_match(/Stimulus|markup/i, web)
    assert_match(/build/i, native)
    assert_match(/simulator or device/i, native)
  end

  def test_matrix_requires_an_automated_test_for_logic_security_and_regressions_with_the_regression_test_first
    [ "Meaningful logic", "Security-sensitive behaviour", "Regression fix" ].each do |name|
      assert_match(/automated test/i, matrix_row(name), "#{name} row lacks an automated test")
    end
    assert_match(/test first|test comes first/i, matrix_row("Regression fix"))
  end

  def test_skill_limits_rails_architecture_and_ruby_style_to_the_rails_side
    skill = read("SKILL.md")
    assert_match(/Rails architecture[^.]*Ruby style[^.]*Rails side only/i, skill)
    assert_match(/not (apply )?to Swift or Kotlin/i, skill)
  end

  def test_android_reference_uses_the_gradle_wrapper_and_adb_and_names_no_mcp_server
    android = read("references/android.md")
    assert_includes(android, "./gradlew")
    assert_includes(android, "adb devices")
    refute_match(/\bMCP\b/i, android)
    refute_match(/mobilebuildmcp/i, android)
  end

  def test_skill_requires_worktree_scheme_or_variant_and_device_before_a_build
    skill = read("SKILL.md")
    assert_match(/worktree/i, skill)
    assert_match(/scheme/i, skill)
    assert_match(/variant/i, skill)
    assert_match(/device or simulator|simulator or device/i, skill)
    assert_match(/never guess/i, skill)
  end

  def test_skill_links_upstream_docs_instead_of_restating_them
    skill = read("SKILL.md")
    assert_includes(skill, "native.hotwired.dev")
    %w[hotwire-native-ios hotwire-native-android hotwire-native-bridge].each do |repo|
      assert_includes(skill, "github.com/hotwired/#{repo}")
    end
  end

  def test_vendored_skill_dependency_demands_yield_to_the_consent_rule
    skill = read("SKILL.md")
    assert_match(/dependency-consent rule/i, skill)
    assert_match(/report the gap/i, skill)
  end

  def test_openai_yaml_has_an_interface_block
    yaml = YAML.safe_load_file(File.join(SKILL_DIR, "agents/openai.yaml"))
    assert(yaml.dig("interface", "display_name"))
  end

  def test_both_references_state_path_configuration_as_an_ordered_contract
    each_reference do |file|
      assert_rule(file, /later matching rule overrides/i, /already shipped app versions/i,
        links: %w[native.hotwired.dev/reference/path-configuration])
    end
  end

  def test_both_references_state_the_bridge_component_as_one_contract
    each_reference do |file|
      assert_rule(file, /one contract/i, /HTML data attributes/i, /Stimulus component/i, /native registration/i,
        /message names/i, /payloads/i, /replies/i, /read every side before changing one/i,
        links: [ "native.hotwired.dev/#{file}/bridge-components" ])
    end
    assert_rule("ios", /one contract/i, /Hotwire\.registerBridgeComponents/)
    assert_rule("android", /one contract/i, /BridgeComponentFactory/)
  end

  def test_both_references_state_progressive_enhancement
    each_reference do |file|
      assert_rule(file, /web control stays usable/i, /plain browser/i, /older app versions/i,
        /hide web UI only when the native side supports/i, /data-bridge-components/,
        links: [ "native.hotwired.dev/#{file}/bridge-components" ])
    end
  end

  def test_both_references_keep_repeat_visits_free_of_stale_and_duplicate_controls
    each_reference do |file|
      assert_rule(file, SHARED_RULES[:cleanup], /own `BridgeDelegate`/, /from its own `connect\(\)`/,
        /`connect` again/i, /`onReceive` must replace/i, /fires no duplicate action/i, /sends nothing to native/i,
        /only through a message/i,
        links: [ "native.hotwired.dev/#{file}/bridge-components", "github.com/hotwired/hotwire-native-#{file}" ])
    end
    assert_rule("android", SHARED_RULES[:cleanup], /`native:restore`/, /re-runs the component's `connect\(\)`/,
      links: %w[core/src/main/assets/js/turbo.js])
  end

  def test_both_references_describe_lifecycle_hooks_as_overrides_that_do_nothing_by_default
    each_reference do |file|
      assert_rule(file, SHARED_RULES[:lifecycle_hooks], /do nothing by default/i, /only while/i,
        links: [ "github.com/hotwired/hotwire-native-#{file}" ])
    end
    assert_rule("android", SHARED_RULES[:lifecycle_hooks], /`onStop` means inactive/, /`onStart`/, /idempotent/i)
    assert_rule("ios", SHARED_RULES[:lifecycle_hooks], /`onViewWillDisappear`/, /`onViewDidDisappear`/,
      /do not put cleanup there/i, links: %w[Source/Turbo/Session/Session.swift])
  end

  def test_both_references_preserve_sessions_and_never_log_secrets
    each_reference do |file|
      assert_rule(file, SHARED_RULES[:sessions], /cookies/i, /authentication/i, /sign-out/i)
      assert_rule(file, SHARED_RULES[:logging], /tokens/i, /sensitive bridge payloads/i)
    end
    assert_rule("ios", SHARED_RULES[:sessions], /app's own error handler/i, /login screen/i, /401/,
      /same `WKWebsiteDataStore`/, /`makeCustomWebView`/, /outside Hotwire Native/, /`WKProcessPool` is deprecated/, /on iOS 15 and later/,
      links: %w[native.hotwired.dev/ios/reference developer.apple.com/documentation/webkit/wkwebsitedatastore
                developer.apple.com/documentation/webkit/wkprocesspool])
  end

  def test_both_references_validate_untrusted_destinations
    each_reference do |file|
      assert_rule(file, /untrusted destinations/i, /authenticated web content/i, /arbitrary origin/i,
        links: %w[native.hotwired.dev/reference/navigation])
    end
  end

  def test_android_reference_validates_intents_and_exported_components_with_the_vendored_skill
    assert_rule("android", /incoming Intents/, /exported components/i,
      links: %w[claude/.claude/skills/android-intent-security/SKILL.md
                developer.android.com/guide/topics/manifest/activity-element#exported])
  end

  def test_android_reference_names_its_lifecycle_traps
    assert_rule("android", /Activity recreation/, links: %w[developer.android.com/guide/components/activities/state-changes])
    assert_rule("android", /process death/i, links: %w[developer.android.com/topic/libraries/architecture/saving-states])
    assert_rule("android", /predictive back/i,
      links: %w[developer.android.com/guide/navigation/custom-back/predictive-back-gesture])
    assert_rule("android", /never swallow `CancellationException`/,
      links: %w[kotlinlang.org/docs/cancellation-and-timeouts.html])
  end

  def test_ios_reference_names_its_lifecycle_traps
    assert_rule("ios", /WKWebView process termination/i, links: %w[webviewwebcontentprocessdidterminate])
    assert_rule("ios", /no blanket `@MainActor`/, links: %w[developer.apple.com/documentation/swift/mainactor])
  end

  def test_both_references_report_checks_observations_and_untested_behaviour_separately
    each_reference do |file|
      assert_rule(file, /three separate/i, /automated checks/i, /untested device-only behaviour/i)
    end
    assert_rule("ios", /three separate/i, /simulator/i)
    assert_rule("android", /three separate/i, /emulator/i)
  end

  def test_both_references_check_skill_prerequisites_before_applying_a_skill
    each_reference { |file| assert_rule(file, /prerequisites/i, /against the project/i) }
    assert_rule("android", /prerequisites/i, /Compose skill does not apply to a Views shell/i)
    assert_rule("ios", /prerequisites/i, /SwiftUI skill does not apply to a UIKit shell/i)
  end

  def test_shared_rules_appear_in_both_references
    ios = reference("ios")
    android = reference("android")
    assert_empty(shared_rule_gaps(ios, android))
    SHARED_RULES.each do |name, phrase|
      assert_match(phrase, ios, "ios.md lacks the shared rule #{name}")
      assert_match(phrase, android, "android.md lacks the shared rule #{name}")
    end
  end

  def test_parity_check_reports_a_rule_present_in_one_reference_only
    gaps = shared_rule_gaps("The later matching rule overrides the earlier one.", "Nothing shared here.")
    assert_equal([ :path_configuration ], gaps)
  end

  def test_references_leave_the_testing_rule_to_the_mobile_exception
    each_reference do |file|
      refute_match(/regression test (comes )?first/i, reference(file))
      refute_match(/(every|any) behaviou?r change/i, reference(file))
    end
  end

  def test_references_carry_no_persona_or_copilot_framing
    each_reference do |file|
      text = reference(file)
      refute_includes(text, "~/.copilot")
      refute_match(/personal preferences/i, text)
      refute_match(/\A---/, text)
      refute_match(/^\s*(You are an? |Act as |Role:|Persona:)/i, text)
    end
  end

  private

  def each_reference(&block)
    REFERENCES.each(&block)
  end

  def reference(file)
    read("references/#{file}.md")
  end

  def assert_rule(file, *patterns, links: [])
    line = reference(file).lines.find { |candidate| candidate.match?(patterns.first) }
    assert(line, "#{file}.md has no line matching #{patterns.first.inspect}")
    patterns.each { |pattern| assert_match(pattern, line, "#{file}.md rule line lacks #{pattern.inspect}") }
    links.each { |link| assert_includes(line, link, "#{file}.md rule line lacks the link #{link}") }
  end

  def shared_rule_gaps(ios_text, android_text)
    SHARED_RULES.select { |_, phrase| ios_text.match?(phrase) != android_text.match?(phrase) }.keys
  end

  def read(relative)
    File.read(File.join(SKILL_DIR, relative))
  end

  def matrix_row(name)
    row = read("SKILL.md").lines.find { |line| line.start_with?("| #{name} |") }
    assert(row, "validation matrix has no row named #{name}")
    row
  end

  def assert_row(skill, pattern, *targets)
    row = skill.lines.find { |line| line.start_with?("|") && line.match?(pattern) }
    assert(row, "routing table has no row for #{pattern.inspect}")
    targets.each { |target| assert_includes(row, target) }
  end
end
