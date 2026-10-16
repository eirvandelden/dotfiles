#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require_relative "git_gem_fixture"

# Git exports GIT_DIR to hooks and lefthook passes it to every job. A gem installed from git can run
# git while Bundler loads its gemspec (mvpa-css does, for its version). With GIT_DIR set that call
# reads the project's repository, the version no longer matches Gemfile.lock, and RuboCop reports
# `Unable to find gem`. The fixture gem `house-style` does the same. Everything is real: git, the
# global hook shims, lefthook, Bundler and RuboCop. Nothing touches the network.
class LefthookRubocopGitGemTest < Minitest::Test
  include GitGemFixture

  RUBOCOP_YML = <<~YAML.freeze
    inherit_gem:
      house-style: config/default.yml
  YAML

  CLEAN_RUBY = "puts \"hello\"\n".freeze
  FIXABLE_RUBY = "puts 'hello'\n".freeze
  UNFIXABLE_RUBY = "def BadName\n  1\nend\n".freeze
  RUBY_PATH = "lib/example.rb".freeze

  def setup
    setup_git_gem_fixture(tools: %w[rubocop bundle])
  end

  def teardown
    teardown_git_gem_fixture
  end

  def test_committing_a_clean_ruby_file_passes_after_rubocop_inspects_it
    output, status = commit_ruby(CLEAN_RUBY)

    assert_predicate(status, :success?, "Expected the commit to pass:\n#{output}")
    assert_includes(git("show", "--name-only", "--format=", "HEAD").first, RUBY_PATH)
    assert_includes(output, "1 file inspected")
  end

  def test_committing_a_fixable_offense_commits_the_fixed_file_with_nothing_unstaged
    output, status = commit_ruby(FIXABLE_RUBY)

    assert_predicate(status, :success?, "Expected the commit to pass:\n#{output}")
    assert_equal(CLEAN_RUBY, git("show", "HEAD:#{RUBY_PATH}").first)
    assert_equal(CLEAN_RUBY, File.read(File.join(@worktree_dir, RUBY_PATH)))
    assert_empty(git("status", "--porcelain").first)
  end

  def test_pushing_a_clean_ruby_file_passes_after_rubocop_inspects_it
    commit_ruby(CLEAN_RUBY, hooks: false)
    output, status = push

    assert_predicate(status, :success?, "Expected the push to pass:\n#{output}")
    assert_equal(head, remote_feature)
    assert_includes(output, "1 file inspected")
  end

  def test_an_unfixable_offense_blocks_the_commit
    before = head
    output, status = commit_ruby(UNFIXABLE_RUBY)

    refute_predicate(status, :success?, "Expected the commit to be blocked:\n#{output}")
    assert_equal(before, head)
    assert_includes(output, "Naming/MethodName")
    refute_includes(output, "Unable to find gem")
  end

  def test_an_unfixable_offense_blocks_the_push
    commit_ruby(UNFIXABLE_RUBY, hooks: false)
    before = remote_feature
    output, status = push

    refute_predicate(status, :success?, "Expected the push to be blocked:\n#{output}")
    assert_equal(before, remote_feature)
    assert_includes(output, "Naming/MethodName")
    refute_includes(output, "Unable to find gem")
  end

  def test_the_fixture_reproduces_the_bug_when_git_dir_leaks
    write_ruby(CLEAN_RUBY)
    git_dir = git("rev-parse", "--absolute-git-dir").first.strip
    output, status = Open3.capture2e(hook_env("GIT_DIR" => git_dir), "rubocop", RUBY_PATH, chdir: @worktree_dir)

    refute_predicate(status, :success?, "RuboCop passed with GIT_DIR set, the fixture no longer reproduces the bug")
    assert_includes(output, "Unable to find gem house-style")
  end

  private

  def project_files
    super.merge(".rubocop.yml" => RUBOCOP_YML)
  end

  def write_ruby(content)
    write_files(@worktree_dir, RUBY_PATH => content)
  end

  def commit_ruby(content, hooks: true)
    write_ruby(content)
    git("add", RUBY_PATH, hooks: false)
    git("commit", "--quiet", "-m", "Add example", hooks: hooks)
  end

  def push
    git("push", "origin", "feature")
  end
end
