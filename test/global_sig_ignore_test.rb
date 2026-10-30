#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"
require "yaml"
require_relative "git_fixture"
require_relative "isolated_git"

# Guards the global ignore of generated RBS folders and the skill wording that relies on it.
class GlobalSigIgnoreTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  GIT_CONFIG = File.join(REPO_ROOT, "git/.config/git/config").freeze
  IGNORE_GLOBAL = File.join(REPO_ROOT, "git/.config/git/ignore.global").freeze
  NEW_REPO_SETUP = "agents/.agents/skills/new-repo-setup/SKILL.md".freeze
  RUBY_STYLE = "agents/.agents/skills/ruby-style/SKILL.md".freeze
  GENERATED = [ "sig/foo.rbs", ".gem_rbs_collection/x" ].freeze

  # A home with the global excludes at <root>/home and an empty repository at <root>/repo.
  REPOSITORY = GitFixture.new do |root|
    FileUtils.mkdir_p(File.join(root, "home/.config/git"))
    FileUtils.cp(IGNORE_GLOBAL, File.join(root, "home/.config/git/ignore.global"))
    FileUtils.mkdir_p(File.join(root, "repo"))
    environment = { "HOME" => File.join(root, "home"), "GIT_CONFIG_GLOBAL" => GIT_CONFIG }
    system(environment, "git", "init", "-q", chdir: File.join(root, "repo"), exception: true)
  end

  def test_global_excludes_hide_sig_and_rbs_collection
    with_repo do
      GENERATED.each { |path| write(path) }

      GENERATED.each { |path| assert_ignored(path) }
      assert_empty(git("status", "--porcelain", "--untracked-files=all").strip)
    end
  end

  def test_gem_gitignore_reincludes_sig
    with_repo do
      File.write("repo/.gitignore", "!sig/\n")
      write("sig/foo.rbs")

      assert_includes(git("status", "--porcelain", "--untracked-files=all"), "sig/foo.rbs")
      git("add", "sig/foo.rbs")
      assert_equal("sig/foo.rbs", git("diff", "--cached", "--name-only").strip)
    end
  end

  def test_new_repo_setup_drops_per_repo_rbs_collection_ignore
    step = step_twelve

    refute_match(/add `\.gem_rbs_collection\/` to the repo's `\.gitignore`/, step)
    assert_match(/global excludes file ignores `sig\/` and `\.gem_rbs_collection\/`/, step)
  end

  def test_new_repo_setup_shows_gem_sig_ci_step
    step = step_twelve

    assert_includes(step, "!sig/")
    commands = YAML.safe_load(step[/```yaml\n(.*?)```/m, 1]).map { |item| item.fetch("run") }
    assert_match(/rbs-inline --opt-out --output=sig lib/, commands.fetch(0))
    assert_equal([ "git diff --exit-code -- sig/", %(test -z "$(git ls-files --others --exclude-standard -- sig/)") ], commands.drop(1))
  end

  def test_gem_sig_ci_step_fails_on_a_deleted_source
    with_gem_repo do
      File.delete("repo/sig/foo.rbs")

      refute_predicate(run_gem_sig_checks, :success?)
    end
  end

  def test_gem_sig_ci_step_fails_on_a_generated_file_git_does_not_hold
    with_gem_repo do
      write("sig/new.rbs")

      refute_predicate(run_gem_sig_checks, :success?)
    end
  end

  def test_gem_sig_ci_step_passes_when_sig_matches_what_git_holds
    with_gem_repo do
      assert_predicate(run_gem_sig_checks, :success?)
    end
  end

  def test_gem_sig_ci_step_keeps_hand_written_manifest
    assert_match(/`sig\/manifest\.yaml`.*hand-written/, step_twelve)
    Dir.mktmpdir do |gem|
      FileUtils.mkdir_p(File.join(gem, "sig/foo"))
      %w[sig/manifest.yaml sig/stale.rbs sig/foo/stale.rbs].each { |path| File.write(File.join(gem, path), "") }

      system(gem_sig_clean_command, chdir: gem, exception: true)

      assert_equal([ "sig/manifest.yaml" ], Dir.glob("sig/**/*", base: gem).select { |path| File.file?(File.join(gem, path)) })
    end
  end

  def test_ruby_style_says_sig_is_generated_except_in_a_gem
    section = File.read(File.join(REPO_ROOT, RUBY_STYLE))[/^## Documentation comments\n(.*?)(?=^## )/m, 1]

    assert_match(/`sig\/`.*generated.*never committed.*except in a gem that publishes its types/, section)
  end

  private

  # A gem repository holding one committed sig/foo.rbs, with the gem's own !sig/ line.
  def with_gem_repo
    with_repo do
      File.write("repo/.gitignore", "!sig/\n")
      write("sig/foo.rbs")
      git("add", ".")
      git("-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false",
        "-c", "core.hooksPath=/dev/null", "commit", "-q", "-m", "Add signatures")
      yield
    end
  end

  # Runs the recipe's checks after its regenerate step: the commands that follow the first one.
  def run_gem_sig_checks
    commands = YAML.safe_load(step_twelve[/```yaml\n(.*?)```/m, 1]).map { |item| item.fetch("run") }.drop(1)
    environment = { "HOME" => @home, "GIT_CONFIG_GLOBAL" => GIT_CONFIG }
    _, status = Open3.capture2e(environment, "sh", "-c", commands.join(" && "), chdir: "repo")
    status
  end

  def gem_sig_clean_command
    YAML.safe_load(step_twelve[/```yaml\n(.*?)```/m, 1]).first.fetch("run").split(" && ").first
  end

  def step_twelve
    File.read(File.join(REPO_ROOT, NEW_REPO_SETUP))[/^12\. Types:.*?(?=^## )/m]
  end

  def with_repo
    copy = REPOSITORY.copy
    Dir.chdir(copy) do
      @home = File.join(copy, "home")
      yield
    end
  ensure
    FileUtils.rm_rf(copy) if copy
  end

  def write(path)
    full = File.join("repo", path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, "")
  end

  def assert_ignored(path)
    _, status = run_git("check-ignore", "-q", path)
    assert_predicate(status, :success?, "#{path} is not ignored")
  end

  def git(*arguments)
    output, status = run_git(*arguments)
    assert_predicate(status, :success?, output)
    output
  end

  def run_git(*arguments)
    environment = { "HOME" => @home, "GIT_CONFIG_GLOBAL" => GIT_CONFIG }
    Open3.capture2e(environment, "git", *arguments, chdir: "repo")
  end
end
