require "minitest/autorun"
require_relative "isolated_git"
require_relative "playbook"

class PlaybookTest < Minitest::Test
  REPO_ROOT = File.realpath(File.expand_path("..", __dir__))
  IMPORT_LINKS = %w[claude/.claude/PLAYBOOK.md codex/.codex/PLAYBOOK.md].freeze

  def test_claude_import_link_resolves_to_the_playbook
    assert_link_resolves_to_the_playbook("claude/.claude/PLAYBOOK.md")
  end

  def test_codex_import_link_resolves_to_the_playbook
    assert_link_resolves_to_the_playbook("codex/.codex/PLAYBOOK.md")
  end

  def test_text_is_the_file_at_path
    assert_equal File.read(File.join(REPO_ROOT, Playbook::PATH)), Playbook.text
  end

  def test_no_tracked_file_cites_root_agents_md_as_the_playbook
    citations = tracked_text_files.flat_map { |file| citations_in(file) }
    assert_empty citations, "these lines cite root agents.md as the playbook"
  end

  def test_the_playbook_keyboard_section_names_dvorak_and_the_arrow_keys
    section = Playbook.text[/^## \d+\. Keyboard\n(.*?)(?=^## |\z)/m, 1] || flunk("no Keyboard section")
    assert_match(/Dvorak/, section)
    assert_match(/arrow keys/, section)
    assert_match(/separate layer/, section)
    assert_match(/never `hjkl`/, section)
  end

  private

  CITATION = /(?<![\/.\w])agents\.md\b/
  PLAYBOOK_CITATION = Regexp.union(
    /playbook(?!\.md|::|\w)/i,
    /see agents\.md/i,
    /agents\.md (rule|section) \d/i,
    /File\.read\(File\.join\(\w+, "agents\.md"\)\)/
  )

  def tracked_text_files
    files = IO.popen([ "git", "ls-files", "-z" ], chdir: REPO_ROOT, &:read).split("\0")
    files.reject { |file| file.start_with?("docs/changes/") || file == "test/playbook_test.rb" }
  end

  def citations_in(file)
    path = File.join(REPO_ROOT, file)
    return [] unless File.file?(path) && !File.symlink?(path)

    lines = File.binread(path).force_encoding("UTF-8")
    return [] unless lines.valid_encoding?

    lines.lines.each_with_index.filter_map do |line, index|
      "#{file}:#{index + 1}: #{line.strip}" if line.match?(CITATION) && line.match?(PLAYBOOK_CITATION)
    end
  end

  def assert_link_resolves_to_the_playbook(link)
    path = File.join(REPO_ROOT, link)
    refute File.readlink(path).start_with?("/"), "#{link} must be a relative link"
    assert_equal File.expand_path(Playbook::PATH, REPO_ROOT), File.realpath(path)
  end
end
