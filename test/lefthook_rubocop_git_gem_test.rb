#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "lefthook_binary"
require_relative "isolated_git"

# Git exports GIT_DIR to hooks and lefthook passes it to every job. A gem installed from git can run
# git while Bundler loads its gemspec (mvpa-css does, for its version). With GIT_DIR set that call
# reads the project's repository, the version no longer matches Gemfile.lock, and RuboCop reports
# `Unable to find gem`. The fixture gem `house-style` does the same. Everything is real: git, the
# global hook shims, lefthook, Bundler and RuboCop. Nothing touches the network.
class LefthookRubocopGitGemTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  NATIVE_LEFTHOOK = LefthookBinary.locate
  MISSING_TOOL_MESSAGE = "rubocop or bundle not found on PATH, so the git gem hook cannot be checked".freeze
  UNSET_VARIABLES = %w[
    GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE LEFTHOOK LEFTHOOK_EXCLUDE LEFTHOOK_CONFIG BUNDLE_GEMFILE RUBYOPT
  ].freeze

  GEM_VERSION_RB = <<~'RUBY'.freeze
    module HouseStyle
      VERSION = "0.1.0.pre.git.#{`git -C #{__dir__} rev-parse --short HEAD`.strip}".freeze
    end
  RUBY

  GEMSPEC = <<~'RUBY'.freeze
    require_relative "lib/house_style/version"

    Gem::Specification.new do |spec|
      spec.name = "house-style"
      spec.version = HouseStyle::VERSION
      spec.authors = ["Test"]
      spec.summary = "Shared RuboCop config"
      spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: File::NULL, &:read).split("\x0")
    end
  RUBY

  GEM_CONFIG = <<~YAML.freeze
    AllCops:
      DisabledByDefault: true
      SuggestExtensions: false

    Style/StringLiterals:
      Enabled: true
      EnforcedStyle: double_quotes

    Naming/MethodName:
      Enabled: true
  YAML

  RUBOCOP_YML = <<~YAML.freeze
    inherit_gem:
      house-style: config/default.yml
  YAML

  CLEAN_RUBY = "puts \"hello\"\n".freeze
  FIXABLE_RUBY = "puts 'hello'\n".freeze
  UNFIXABLE_RUBY = "def BadName\n  1\nend\n".freeze
  RUBY_PATH = "lib/example.rb".freeze

  # The gem repository and the bundle are built once per run, because `bundle install` is slow.
  class << self
    attr_accessor :shared_built

    def shared_root
      @shared_root ||= File.realpath(Dir.mktmpdir).tap { |dir| Minitest.after_run { FileUtils.rm_rf(dir) } }
    end
  end

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK
    skip_unless_ci(MISSING_TOOL_MESSAGE) unless executable_on_path?("rubocop") && executable_on_path?("bundle")

    @tmpdir = File.realpath(Dir.mktmpdir)
    @gem_dir = File.join(self.class.shared_root, "house-style")
    build_shared_fixture
    build_home
    build_project
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
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

  def executable_on_path?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
  end

  def skip_unless_ci(message)
    ENV["CI"] ? flunk(message) : skip(message)
  end

  def build_home
    @home = File.join(@tmpdir, "home")
    dotfiles = File.join(@home, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles)
    FileUtils.cp(File.join(REPO_ROOT, "lefthook.yml"), dotfiles)
    FileUtils.cp_r(File.join(REPO_ROOT, "git/.config/git/hooks"), File.join(@tmpdir, "hooks"))
    stub_review_report_check
    write_global_gitconfig
  end

  def stub_review_report_check
    %w[review-report-fresh marker-check].each do |name|
      stub = File.join(@home, ".config", "git", "worktree-tools", name)
      FileUtils.mkdir_p(File.dirname(stub))
      File.write(stub, "#!/bin/sh\nexit 0\n")
      FileUtils.chmod("+x", stub)
    end
  end

  def write_global_gitconfig
    File.write(File.join(@tmpdir, "gitconfig"), <<~INI)
      [core]
        hooksPath = #{File.join(@tmpdir, "hooks")}
      [user]
        name = Test
        email = test@example.com
    INI
  end

  def build_shared_fixture
    return if self.class.shared_built

    write_files(
      @gem_dir,
      "house-style.gemspec" => GEMSPEC,
      "lib/house_style/version.rb" => GEM_VERSION_RB,
      "config/default.yml" => GEM_CONFIG
    )
    init_and_commit(@gem_dir, "Add house-style")
    install_gem_bundle
    self.class.shared_built = true
  end

  def install_gem_bundle
    seed_dir = File.join(self.class.shared_root, "seed")
    write_files(seed_dir, "Gemfile" => gemfile)
    run!("bundle", "install", chdir: seed_dir)
    FileUtils.cp(File.join(seed_dir, "Gemfile.lock"), File.join(self.class.shared_root, "Gemfile.lock"))
    restore_dynamic_gemspec
  end

  # `bundle install` replaces a git gem's gemspec with a static copy, so the gem's own git call never
  # runs again. `rv ci`, which Etienne's repositories use, leaves the gemspec as it is. Put the
  # original back to get the same checkout.
  def restore_dynamic_gemspec
    checkout = Dir.glob(File.join(bundle_path, "ruby", "*", "bundler", "gems", "house-style-*")).first
    File.write(File.join(checkout, "house-style.gemspec"), GEMSPEC)
  end

  def gemfile
    "gem \"house-style\", git: #{@gem_dir.inspect}\n"
  end

  def bundle_path
    File.join(self.class.shared_root, "bundle")
  end

  def build_project
    @project_dir = File.join(@tmpdir, "project")
    @worktree_dir = File.join(@tmpdir, "worktree")
    write_files(@project_dir, "Gemfile" => gemfile, ".rubocop.yml" => RUBOCOP_YML)
    FileUtils.cp(File.join(self.class.shared_root, "Gemfile.lock"), @project_dir)
    init_and_commit(@project_dir, "Add project")
    publish_feature_branch
  end

  def publish_feature_branch
    origin_dir = File.join(@tmpdir, "origin.git")
    run!("git", "init", "--quiet", "--bare", origin_dir)
    run!("git", "remote", "add", "origin", origin_dir, chdir: @project_dir)
    run!("git", "worktree", "add", "--quiet", "-b", "feature", @worktree_dir, chdir: @project_dir)
    run!("git", "push", "--quiet", "--set-upstream", "origin", "feature", chdir: @worktree_dir)
  end

  def write_files(dir, files)
    files.each do |name, content|
      path = File.join(dir, name)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  def init_and_commit(dir, message)
    run!("git", "init", "--quiet", "--initial-branch=main", chdir: dir)
    run!("git", "add", ".", chdir: dir)
    run!("git", "commit", "--quiet", "-m", message, chdir: dir)
  end

  def hook_env(extra = {})
    {
      "HOME" => @home,
      "GIT_CONFIG_GLOBAL" => File.join(@tmpdir, "gitconfig"),
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "BUNDLE_PATH" => bundle_path,
      "LEFTHOOK_BIN" => NATIVE_LEFTHOOK,
      "GIT_AUTHOR_NAME" => "Test",
      "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test",
      "GIT_COMMITTER_EMAIL" => "test@example.com"
    }.merge(UNSET_VARIABLES.to_h { |name| [ name, nil ] }).merge(extra)
  end

  def run!(*command, chdir: @tmpdir)
    output, status = Open3.capture2e(hook_env("LEFTHOOK" => "0"), *command, chdir: chdir)
    flunk "#{command.join(" ")} failed (exit #{status.exitstatus}):\n#{output}" unless status.success?
    output
  end

  def git(*args, hooks: true)
    env = hooks ? hook_env : hook_env("LEFTHOOK" => "0")
    Open3.capture2e(env, "git", *args, chdir: @worktree_dir)
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

  def head
    git("rev-parse", "HEAD").first.strip
  end

  def remote_feature
    git("ls-remote", "origin", "feature").first.split.first
  end
end
