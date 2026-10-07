#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"

# Third-party skills are pinned snapshots recorded in VENDORED-SKILLS.yml. A snapshot folder is a skill whose
# SKILL.md carries an `<!-- upstream: ... -->` comment that does not name superpowers-ruby, which keeps its own convention.
class VendoredSkillsTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")
  MANIFEST = File.join(REPO_ROOT, "VENDORED-SKILLS.yml")
  REQUIRED_KEYS = %w[skill upstream tag commit licence snapshot_date paths].freeze
  LICENCE_FILES = %w[LICENSE LICENSE.txt LICENSE.md].freeze
  NEW_MOBILE_SKILLS = %w[hotwire-native mobilebuildmcp android-intent-security].freeze

  def test_every_snapshot_folder_has_a_complete_manifest_entry
    entries = manifest.group_by { |entry| entry["skill"] }
    snapshot_names.each do |name|
      entry = entries[name]&.first
      assert(entry, "#{name} has no entry in VENDORED-SKILLS.yml")
      REQUIRED_KEYS.each { |key| assert(entry[key].to_s != "", "#{name} entry lacks #{key}") }
    end
  end

  def test_every_manifest_entry_points_at_an_existing_skill_folder
    manifest.each do |entry|
      assert(File.exist?(File.join(SKILLS, entry["skill"], "SKILL.md")), "#{entry["skill"]} has no skill folder")
    end
  end

  def test_every_snapshot_folder_holds_its_upstream_licence_file
    snapshot_names.each do |name|
      found = LICENCE_FILES.any? { |file| File.exist?(File.join(SKILLS, name, file)) }
      assert(found, "#{name} holds no upstream licence file")
    end
  end

  def test_manifest_commits_are_full_forty_character_shas
    manifest.each do |entry|
      assert_match(/\A\h{40}\z/, entry["commit"].to_s, "#{entry["skill"]} commit is not a full SHA")
    end
  end

  def test_no_marketplace_points_at_a_vendored_upstream
    settings = File.read(File.join(REPO_ROOT, "claude/.claude/settings.json"))
    manifest.each do |entry|
      repo = entry["upstream"].to_s[%r{github\.com/([^/]+/[^/]+)}, 1]
      refute(settings.include?(repo), "settings.json references vendored upstream #{repo}")
    end
  end

  def test_skills_index_lists_every_new_mobile_skill
    index = File.read(File.join(REPO_ROOT, "SKILLS-INDEX.md"))
    NEW_MOBILE_SKILLS.each do |name|
      assert(index.include?("claude/.claude/skills/#{name}/SKILL.md"), "SKILLS-INDEX.md lacks #{name}")
    end
    assert(index.include?("VENDORED-SKILLS.yml"), "SKILLS-INDEX.md does not name VENDORED-SKILLS.yml")
  end

  private

  def manifest
    return [] unless File.exist?(MANIFEST)

    YAML.safe_load_file(MANIFEST, permitted_classes: [ Date ]) || []
  end

  def snapshot_names
    Dir.children(SKILLS).select do |name|
      skill_md = File.join(SKILLS, name, "SKILL.md")
      next false unless File.exist?(skill_md)

      comment = File.read(skill_md)[/<!-- upstream:.*?-->/m]
      comment && !comment.include?("lucianghinda/superpowers-ruby")
    end
  end
end
