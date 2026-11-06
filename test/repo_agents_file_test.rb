require "minitest/autorun"
require "yaml"
require_relative "isolated_git"

class RepoAgentsFileTest < Minitest::Test
  ROOT = File.realpath(File.expand_path("..", __dir__))
  AGENTS_FILE = File.join(ROOT, "agents.md")
  LINTERS = %w[rubocop shellcheck shellcheck-zsh yamllint no-hardwrap].freeze

  def test_root_agents_md_is_not_the_playbook
    refute_includes text, "Personal and Work Rails Playbook"
    refute_includes text, "## 7. AI Agent Workflow"
  end

  def test_root_claude_md_still_links_to_root_agents_md
    assert_equal "agents.md", File.readlink(File.join(ROOT, "CLAUDE.md"))
    assert File.file?(AGENTS_FILE)
  end

  def test_names_every_stow_package
    missing = stow_packages.reject { |package| text.include?("`#{package}`") }
    assert_empty missing, "agents.md does not name these stow packages"
  end

  def test_names_no_package_that_packages_conf_dropped
    stale = named_packages - stow_packages
    assert_empty stale, "agents.md names packages that packages.conf no longer stows"
  end

  def test_names_the_skill_source_the_work_overlay_and_the_no_stow_rule
    assert_includes text, "agents/.agents/skills/"
    assert_includes text, "claude/.claude/skills/"
    assert_includes text, "dotfiles-work"
    assert_match(/never run `stow`/i, text)
  end

  def test_every_listed_test_command_exists
    assert_includes text, "`bin/test`"
    assert File.executable?(File.join(ROOT, "bin/test"))
    assert_includes text, "claude/.claude/test/statusline_command_test.rb"
    assert File.file?(File.join(ROOT, "claude/.claude/test/statusline_command_test.rb"))
  end

  def test_every_listed_linter_is_a_lefthook_command
    commands = YAML.load_file(File.join(ROOT, "lefthook.yml")).fetch("pre-commit").fetch("commands").keys
    LINTERS.each do |linter|
      assert_includes text, "`#{linter}`"
      assert_includes commands, linter
    end
  end

  def test_links_the_dotfiles_maintenance_skill
    skill = "agents/.agents/skills/dotfiles-maintenance/SKILL.md"
    assert_includes text, skill
    assert File.file?(File.join(ROOT, skill))
  end

  def test_fits_on_one_page
    assert_operator text.lines.size, :<=, 40
  end

  private

  def text
    @text ||= File.read(AGENTS_FILE)
  end

  def named_packages
    text[/^- Packages in `packages\.conf`: (.*)$/, 1].scan(/`([^`]+)`/).flatten
  end

  def stow_packages
    list = File.read(File.join(ROOT, "packages.conf"))[/^STOW=\((.*?)^\)/m, 1]
    list.lines.map { |line| line.sub(/#.*/, "").strip }.reject(&:empty?)
  end
end
