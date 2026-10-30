#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"
require "yaml"
require_relative "isolated_git"

# Claude and Codex share skills from one source: a skill folder under
# agents/.agents/skills/<name>/, which Codex reads installed at ~/.agents/skills/.
# claude/.claude/skills/<name> is a relative link to it, so Claude reads the same
# folder at ~/.claude/skills/ (codex/.codex/skills/ is not scanned by Codex and
# must not exist). This test is the drift guard: it reads repo paths, never `~`,
# so it catches a skill source added on the wrong side before a stow run would.
class SkillParityTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  CLAUDE_SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")
  AGENTS_SKILLS = File.join(REPO_ROOT, "agents/.agents/skills")
  CODEX_SKILLS = File.join(REPO_ROOT, "codex/.codex/skills")
  PACKAGES_CONF = File.join(REPO_ROOT, "packages.conf")
  UNUSED_AGENT_RULE_FOLDERS = %w[.clinerules .cursor .opencode .windsurf].freeze

  # Skills that stay Codex-only, with the reason on record. Empty for now.
  CODEX_ONLY = [].freeze
  # Skills whose SKILL.md talks about this repository's own layout on purpose
  # (installing it, setting up a new repo to match it) — a repo-relative path
  # there is documentation, not a command another checkout is meant to run.
  REPO_LAYOUT_SKILLS = %w[dotfiles-maintenance new-repo-setup].freeze
  # Skills where the two flags intentionally disagree: worktree-first must stay
  # model-invocable on Claude (WORKTREES.md and the intent skill call it), and so
  # must review (the autonomous coordinator calls it through the Skill tool; Codex
  # coordinators follow the file). Codex's allow_implicit_invocation only disables
  # automatic triggering, which is the intended behaviour there.
  AGENT_INVOKED = %w[review worktree-first].freeze

  def test_every_agents_skill_is_a_real_folder_with_a_skill_md
    assert(Dir.exist?(AGENTS_SKILLS), "#{AGENTS_SKILLS} does not exist")

    Dir.children(AGENTS_SKILLS).each do |name|
      path = File.join(AGENTS_SKILLS, name)
      refute(File.symlink?(path), "#{path} is a link; the agents package holds the source")
      assert(File.exist?(File.join(path, "SKILL.md")), "#{path} has no SKILL.md")
    end
  end

  def test_claude_skills_are_relative_links_into_the_agents_package
    assert_empty(misplaced_claude_skills(CLAUDE_SKILLS), "claude/.claude/skills must only hold relative links")
  end

  def test_a_real_folder_under_claude_skills_is_reported
    in_fixture do |claude, _agents|
      FileUtils.mkdir_p(File.join(claude, "probe"))

      assert_equal([ "probe" ], misplaced_claude_skills(claude))
    end
  end

  def test_an_absolute_link_under_claude_skills_is_reported
    in_fixture do |claude, agents|
      FileUtils.mkdir_p(File.join(agents, "probe"))
      File.symlink(File.join(agents, "probe"), File.join(claude, "probe"))

      assert_equal([ "probe" ], misplaced_claude_skills(claude))
    end
  end

  def test_a_dangling_link_under_claude_skills_is_reported
    in_fixture do |claude, _agents|
      File.symlink("../../../agents/.agents/skills/gone", File.join(claude, "gone"))

      assert_equal([ "gone" ], misplaced_claude_skills(claude))
    end
  end

  def test_a_plain_file_under_claude_skills_is_reported
    in_fixture do |claude, _agents|
      File.write(File.join(claude, "stray.md"), "")

      assert_equal([ "stray.md" ], misplaced_claude_skills(claude))
    end
  end

  def test_a_relative_link_into_the_agents_package_is_accepted
    in_fixture do |claude, agents|
      FileUtils.mkdir_p(File.join(agents, "probe"))
      File.symlink("../../../agents/.agents/skills/probe", File.join(claude, "probe"))

      assert_empty(misplaced_claude_skills(claude))
    end
  end

  def test_every_agents_skill_has_an_openai_yaml
    skill_names(AGENTS_SKILLS).each do |name|
      openai_yaml = File.join(AGENTS_SKILLS, name, "agents/openai.yaml")
      assert(File.exist?(openai_yaml), "#{name} has no agents/openai.yaml")
    end
  end

  def test_codex_skills_directory_is_gone
    refute(Dir.exist?(CODEX_SKILLS), "#{CODEX_SKILLS} still exists; Codex does not read it")
  end

  def test_skill_names_match_on_both_sides
    claude_names = entry_names(CLAUDE_SKILLS)
    agents_names = skill_names(AGENTS_SKILLS) - CODEX_ONLY

    assert_equal(agents_names.sort, claude_names.sort)
  end

  def test_implicit_invocation_policy_matches_between_frontmatter_and_openai_yaml
    (skill_names(AGENTS_SKILLS) - AGENT_INVOKED).each do |name|
      skill_md = File.join(AGENTS_SKILLS, name, "SKILL.md")
      openai_yaml = File.join(AGENTS_SKILLS, name, "agents/openai.yaml")
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

  def test_agent_invoked_skills_are_model_invocable_on_claude_and_deny_implicit_invocation_on_codex
    AGENT_INVOKED.each do |name|
      skill_md = File.join(AGENTS_SKILLS, name, "SKILL.md")
      openai_yaml = File.join(AGENTS_SKILLS, name, "agents/openai.yaml")

      refute_equal(true, frontmatter(skill_md)["disable-model-invocation"], "#{name} is disabled for the model")
      assert_equal(false, YAML.load_file(openai_yaml).dig("policy", "allow_implicit_invocation"), "#{name} allows implicit invocation")
    end
  end

  def test_deliver_and_finish_stay_disabled_for_model_invocation
    %w[deliver finish].each do |name|
      skill_md = File.join(AGENTS_SKILLS, name, "SKILL.md")

      assert_equal(true, frontmatter(skill_md)["disable-model-invocation"], "#{name} lost disable-model-invocation")
    end
  end

  def test_codex_worktrees_doc_resolves_to_the_claude_one
    codex_doc = File.join(REPO_ROOT, "codex/.codex/WORKTREES.md")
    claude_doc = File.join(REPO_ROOT, "claude/.claude/WORKTREES.md")

    assert(File.symlink?(codex_doc), "#{codex_doc} is not a symlink")
    assert_equal(File.realpath(claude_doc), File.realpath(codex_doc))
  end

  def test_claude_and_codex_import_the_one_agent_neutral_mcp_doc
    assert(File.file?(File.join(REPO_ROOT, "agents/.agents/MCP.md")), "agents/.agents/MCP.md is missing")
    assert_includes(File.read(File.join(REPO_ROOT, "claude/.claude/CLAUDE.md")), "@~/.agents/MCP.md")
    assert_includes(File.read(File.join(REPO_ROOT, "codex/.codex/AGENTS.md")), "@/Users/etienne.vandelden/.agents/MCP.md")
  end

  def test_packages_conf_lists_agents_in_stow_and_stow_shared
    assert_includes(bash_array("STOW"), "agents")
    assert_includes(bash_array("STOW_SHARED"), "agents")
  end

  def test_no_skill_or_agent_body_names_a_repo_relative_path_as_a_command
    pattern = %r{claude/\.claude/skills/|agents/\.agents/skills/|git/\.config/git/}

    (Dir.glob(File.join(AGENTS_SKILLS, "*/SKILL.md")) + Dir.glob(File.join(REPO_ROOT, "claude/.claude/agents/*.md"))).each do |path|
      next if REPO_LAYOUT_SKILLS.include?(File.basename(File.dirname(path)))

      body = File.read(path).gsub(/<!--.*?-->/m, "")
      refute(pattern.match?(body), "#{path} names a repo-relative path where the installed one belongs")
    end
  end

  def test_unused_agent_rule_folders_are_gone
    UNUSED_AGENT_RULE_FOLDERS.each do |folder|
      refute(Dir.exist?(File.join(REPO_ROOT, folder)), "#{folder} still exists; no agent reads it")
    end
  end

  def test_codex_gets_the_design_diagrams_and_glossary_skills
    index = File.read(File.join(REPO_ROOT, "SKILLS-INDEX.md"))

    %w[software-design diagrams glossary].each do |name|
      assert_includes(skill_names(AGENTS_SKILLS), name, "#{name} is not linked for Codex")
      assert_includes(skill_names(CLAUDE_SKILLS), name, "#{name} has no Claude skill")
      assert_includes(index, name, "SKILLS-INDEX.md does not list #{name}")
    end
  end

  private

  # Names under the Claude skills folder that are not a resolving relative link into the agents package.
  def misplaced_claude_skills(claude_dir)
    entry_names(claude_dir).reject do |name|
      path = File.join(claude_dir, name)
      File.symlink?(path) && File.readlink(path) == "../../../agents/.agents/skills/#{name}" && File.directory?(path)
    end
  end

  # Every entry except hidden ones such as .DS_Store, including plain files and dangling links.
  def entry_names(dir)
    return [] unless Dir.exist?(dir)

    Dir.children(dir).reject { |name| name.start_with?(".") }
  end

  def in_fixture
    Dir.mktmpdir do |root|
      claude = File.join(root, "claude/.claude/skills")
      agents = File.join(root, "agents/.agents/skills")
      FileUtils.mkdir_p([ claude, agents ])
      yield claude, agents
    end
  end

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
end
