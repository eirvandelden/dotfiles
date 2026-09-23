#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require "yaml"

# Claude and Codex share skills from one source: a Claude skill folder under
# claude/.claude/skills/<name>/, linked into agents/.agents/skills/<name> for
# Codex to read (codex/.codex/skills/ is not scanned by Codex and must not
# exist). This test is the drift guard: it reads repo paths, never `~`, so it
# catches a skill added to one side and forgotten on the other before a stow
# run would.
class SkillParityTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  CLAUDE_SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")
  AGENTS_SKILLS = File.join(REPO_ROOT, "agents/.agents/skills")
  CODEX_SKILLS = File.join(REPO_ROOT, "codex/.codex/skills")
  PACKAGES_CONF = File.join(REPO_ROOT, "packages.conf")

  # Process and domain skills not yet vendored onto the shared mechanism — a later
  # phase decides, skill by skill, whether each is worth linking into Codex too.
  CLAUDE_ONLY = %w[
    code-review dependencies dotfiles-maintenance new-repo-setup object-oriented-design
    rails-api-design rails-architecture rails-ops rails-testing rails-ui
    ruby-style sync
  ].freeze
  # Skills that stay Codex-only, with the reason on record. Empty for now.
  CODEX_ONLY = [].freeze
  # Skills whose SKILL.md talks about this repository's own layout on purpose
  # (installing it, setting up a new repo to match it) — a repo-relative path
  # there is documentation, not a command another checkout is meant to run.
  REPO_LAYOUT_SKILLS = %w[dotfiles-maintenance new-repo-setup].freeze
  # Skills where the two flags intentionally disagree: worktree-first must stay
  # model-invocable on Claude (WORKTREES.md and the intent skill call it), while
  # Codex's allow_implicit_invocation only disables automatic triggering, which
  # is the intended behaviour there.
  AGENT_INVOKED = %w[worktree-first].freeze

  def test_agents_skills_are_symlinks_into_the_claude_skill_folder
    assert(Dir.exist?(AGENTS_SKILLS), "#{AGENTS_SKILLS} does not exist")

    skill_names(AGENTS_SKILLS).each do |name|
      link = File.join(AGENTS_SKILLS, name)
      assert(File.symlink?(link), "#{link} is not a symlink")

      target = File.realpath(link)
      expected_target = File.realpath(File.join(CLAUDE_SKILLS, name))
      assert_equal(expected_target, target, "#{link} does not resolve to the Claude #{name} skill")
    end
  end

  def test_codex_skills_directory_is_gone
    assert_not(Dir.exist?(CODEX_SKILLS), "#{CODEX_SKILLS} still exists; Codex does not read it")
  end

  def test_shared_skill_names_match_on_both_sides
    claude_names = skill_names(CLAUDE_SKILLS) - CLAUDE_ONLY
    agents_names = skill_names(AGENTS_SKILLS) - CODEX_ONLY

    assert_equal(claude_names.sort, agents_names.sort)
  end

  def test_implicit_invocation_policy_matches_between_frontmatter_and_openai_yaml
    (skill_names(AGENTS_SKILLS) - AGENT_INVOKED).each do |name|
      skill_md = File.join(CLAUDE_SKILLS, name, "SKILL.md")
      openai_yaml = File.join(CLAUDE_SKILLS, name, "agents/openai.yaml")
      assert(File.exist?(openai_yaml), "#{name} has no agents/openai.yaml")

      disabled_for_model = frontmatter(skill_md)["disable-model-invocation"] == true
      denied_implicit_invocation = YAML.load_file(openai_yaml).dig("policy", "allow_implicit_invocation") == false

      assert_equal(
        disabled_for_model,
        denied_implicit_invocation,
        "#{name}: disable-model-invocation and allow_implicit_invocation disagree"
      )
    end
  end

  def test_codex_worktrees_doc_resolves_to_the_claude_one
    codex_doc = File.join(REPO_ROOT, "codex/.codex/WORKTREES.md")
    claude_doc = File.join(REPO_ROOT, "claude/.claude/WORKTREES.md")

    assert(File.symlink?(codex_doc), "#{codex_doc} is not a symlink")
    assert_equal(File.realpath(claude_doc), File.realpath(codex_doc))
  end

  def test_packages_conf_lists_agents_in_stow_and_stow_shared
    assert_includes(bash_array("STOW"), "agents")
    assert_includes(bash_array("STOW_SHARED"), "agents")
  end

  def test_no_skill_or_agent_body_names_a_repo_relative_path_as_a_command
    pattern = %r{claude/\.claude/skills/|git/\.config/git/}

    (Dir.glob(File.join(CLAUDE_SKILLS, "*/SKILL.md")) + Dir.glob(File.join(REPO_ROOT, "claude/.claude/agents/*.md"))).each do |path|
      next if REPO_LAYOUT_SKILLS.include?(File.basename(File.dirname(path)))

      body = File.read(path).gsub(/<!--.*?-->/m, "")
      assert_not(pattern.match?(body), "#{path} names a repo-relative path where the installed one belongs")
    end
  end

  private

  def skill_names(dir)
    return [] unless Dir.exist?(dir)

    Dir.children(dir).select { |name| File.directory?(File.join(dir, name)) }
  end

  def frontmatter(skill_md_path)
    match = File.read(skill_md_path).match(/\A---\n(.*?)\n---\n/m)
    return {} unless match

    YAML.safe_load(match[1]) || {}
  end

  def bash_array(name)
    stdout, stderr, status = Open3.capture3(
      "bash", "-c", %(source "$0"; printf "%s\\n" "${#{name}[@]}"), PACKAGES_CONF
    )
    raise stderr unless status.success?

    stdout.split("\n")
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end
end
