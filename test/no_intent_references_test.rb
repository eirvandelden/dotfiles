#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require "open3"

# The change document is plan.md alone. No tracked file outside the change folders refers to the
# deleted `intent` skill, to intent.md, or to the helpers that served them.
class NoIntentReferencesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  # The one test that proves a folder holding only the old document is not a plan.
  ALLOWED = %w[test/no_intent_references_test.rb test/commit_plan_test.rb].freeze
  PATTERNS = [
    /intent\.md/,
    %r{skills/intent\b},
    /`intent` skill|intent skill/i,
    /intent-pane/,
    /intent_metadata|IntentMetadata/,
    /hand-off-plan(?:\.sh)? intent/,
    /auto-accept/
  ].freeze
  # rails-upgrade's own advice about `bin/rails app:update`, unrelated to a plan status.
  UNRELATED = [ %r{agents/\.agents/skills/rails-upgrade/SKILL\.md} ].freeze

  def test_names_no_intent_artefact_outside_change_folders
    offences = tracked_files.flat_map { |path| offences_in(path) }

    assert_empty(offences, "files still name the intent artefacts:\n#{offences.join("\n")}")
  end

  private

  def tracked_files
    stdout, = Open3.capture2("git", "ls-files", "-z", chdir: ROOT)
    stdout.split("\0").reject do |path|
      path.start_with?("docs/changes/") || ALLOWED.include?(path) || UNRELATED.any? { |unrelated| path.match?(unrelated) } ||
        !File.file?(File.join(ROOT, path))
    end
  end

  def offences_in(path)
    text = File.binread(File.join(ROOT, path))
    return [] if text.include?("\0")

    text.force_encoding(Encoding::UTF_8).each_line.with_index(1).filter_map do |line, number|
      next unless line.valid_encoding? && PATTERNS.any? { |pattern| line.match?(pattern) }

      "#{path}:#{number}: #{line.strip[0, 120]}"
    end
  end
end
