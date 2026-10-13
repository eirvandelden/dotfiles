#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"

# Static checks that the dotfiles install and wire up inline RBS tooling, and no YARD tooling.
class RbsInlineToolingTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  RUBOCOP_YARD = %w[rubocop yard].join("-").freeze
  YARD_GEMS = [ RUBOCOP_YARD, "yard", "yard-activesupport-concern", "yard-solargraph" ].freeze
  RBS_GEMS = [ "rbs", "steep", "rubocop-rbs_inline" ].freeze
  SKILLS = "claude/.claude/skills".freeze

  def test_fallback_config_does_not_load_rubocop_yard
    refute_includes(read("rubocop/.rubocop.yml"), RUBOCOP_YARD)
  end

  def test_packages_conf_installs_rbs_tooling
    assert_empty(RBS_GEMS - ruby_gems)
  end

  def test_packages_conf_lists_no_yard_gems
    assert_empty(YARD_GEMS & ruby_gems)
  end

  def test_ci_installs_rubocop_rbs_inline_not_rubocop_yard
    install_line = read(".github/workflows/dotfiles-tests.yml")[/gem install --no-document.*?(?=\n\s*#|\n\s*- )/m]

    assert_match(/\brubocop-rbs_inline\b/, install_line)
    refute_includes(install_line, RUBOCOP_YARD)
  end

  def test_neovim_enables_steep_next_to_solargraph
    enabled = read("neovim/.config/nvim/lua/core/lsp.lua")[/vim\.lsp\.enable\(\{(.*?)\}\)/, 1]

    assert_match(/"steep"/, enabled)
    assert_match(/"solargraph"/, enabled)
  end

  def test_neovim_steep_starts_only_with_a_steepfile
    config = read("neovim/.config/nvim/lsp/steep.lua")

    assert_match(/cmd = \{ "steep", "langserver" \}/, config)
    assert_match(/root_dir = function/, config)
    assert_match(/vim\.fs\.root\(bufnr, \{ "Steepfile" \}\)/, config)
    refute_match(/root_markers/, config)
  end

  def test_zed_runs_steep_next_to_solargraph
    settings = read("zed/.config/zed/settings.json")

    assert_match(/"language_servers": \["solargraph", "steep"\]/, settings)
    assert_match(/"steep": \{\s*"binary": \{\s*"path": "steep",\s*"arguments": \["langserver"\]/, settings)
  end

  def test_vscode_runs_global_steep
    assert_match(/"steep\.command": "steep"/, read("vscode/settings.json"))
  end

  def test_new_repo_setup_adds_inline_steepfile
    skill = read("#{SKILLS}/new-repo-setup/SKILL.md")

    assert_match(/Steepfile/, skill)
    assert_match(/inline: true/, skill)
    assert_match(/rbs collection install/, skill)
    assert_match(/\.gem_rbs_collection\//, skill)
    assert_match(/Ruby 3\.3/, skill)
  end

  def test_ruby_style_personal_rule_names_inline_rbs
    section = documentation_section("ruby-style")

    assert_match(/Personal.*inline RBS/, section)
  end

  def test_ruby_style_keeps_work_yard_rule
    assert_match(/Work.*YARD/, documentation_section("ruby-style"))
  end

  def test_rails_architecture_personal_rule_names_inline_rbs
    assert_match(/Personal.*inline RBS/, documentation_section("rails-architecture"))
  end

  def test_rails_architecture_drops_personal_yard_method_docs
    refute_match(/Personal: also YARD-document every method/, documentation_section("rails-architecture"))
  end

  def test_rails_architecture_keeps_work_action_route_tags
    section = documentation_section("rails-architecture")
    examples = read("#{SKILLS}/rails-architecture/references/examples.md")

    assert_match(/Work.*@action.*@route/, section)
    assert_match(/work-only/i, examples)
  end

  def test_no_rubocop_yard_reference_outside_change_folders
    output, status = Open3.capture2("git", "grep", "-i", "-l", RUBOCOP_YARD, "--", ":!docs/changes", chdir: REPO_ROOT)

    assert_empty(output)
    # git grep exits 1 for no match; anything else means it never searched.
    assert_equal(1, status.exitstatus)
  end

  private

  def read(path)
    File.read(File.join(REPO_ROOT, path))
  end

  def ruby_gems
    read("packages.conf")[/^RUBY_GEMS=\((.*?)^\)/m, 1].split
  end

  def documentation_section(skill)
    read("#{SKILLS}/#{skill}/SKILL.md")[/^## Documentation.*?(?=^## |\z)/m]
  end
end
