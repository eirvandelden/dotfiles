#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"

# The hotwire-native skill is first-party guidance the repo owns: how its routing, validation matrix and
# targeting rules read is behaviour an agent acts on (docs/changes/hotwire-native-agent-guidance/plan.md).
class HotwireNativeSkillTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILL_DIR = File.join(REPO_ROOT, "claude/.claude/skills/hotwire-native")

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

  private

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
