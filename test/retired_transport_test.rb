#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require_relative "isolated_git"

# Proves that hc is the only transport left: no tracked file names a retired token, no herdr or rex package remains.
class RetiredTransportTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  # Built from parts, so this file never holds a whole token.
  RETIRED = [ %w[HERDR PANE ID].join("_"), [ "herdr", "pane" ].join(" "), %w[REX SESSION].join("_") ].freeze
  RETIRED_PACKAGES = %w[herdr rex].freeze
  CLEARED_GIT_ENV = { "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil }.freeze

  def test_no_tracked_file_outside_docs_changes_names_a_retired_token
    offenders = tracked_files.flat_map { |path| tokens_in(path).map { |token| "#{path}: #{token}" } }

    assert_empty(offenders, "retired tokens are still named:\n#{offenders.join("\n")}")
  end

  def test_packages_conf_and_the_tree_hold_neither_herdr_nor_rex
    listed = package_elements & RETIRED_PACKAGES
    present = RETIRED_PACKAGES.select { |name| File.exist?(File.join(ROOT, name)) }

    assert_empty(listed, "packages.conf still lists #{listed.join(', ')}")
    assert_empty(present, "the repository still has #{present.join('/, ')}/")
  end

  private

  def tracked_files
    output, status = Open3.capture2(CLEARED_GIT_ENV, "git", "ls-files", "-z", chdir: ROOT)
    assert_predicate(status, :success?)
    output.split("\0").reject { |path| path.start_with?("docs/changes/") }
          .select { |path| File.file?(File.join(ROOT, path)) && !File.symlink?(File.join(ROOT, path)) }
  end

  def tokens_in(path)
    text = File.binread(File.join(ROOT, path))
    RETIRED.select { |token| text.include?(token) }
  end

  # Every whole word of an uncommented packages.conf line. `herdr=` starts a plugin entry, so it counts too.
  def package_elements
    File.readlines(File.join(ROOT, "packages.conf"), chomp: true).flat_map do |line|
      line.sub(/#.*/, "").split(/[\s()]+/).map { |element| element.sub(/=.*\z/, "") }
    end
  end
end
