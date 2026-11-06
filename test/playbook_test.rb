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

  private

  def assert_link_resolves_to_the_playbook(link)
    path = File.join(REPO_ROOT, link)
    refute File.readlink(path).start_with?("/"), "#{link} must be a relative link"
    assert_equal File.expand_path(Playbook::PATH, REPO_ROOT), File.realpath(path)
  end
end
