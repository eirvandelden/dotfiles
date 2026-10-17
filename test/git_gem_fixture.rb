require "fileutils"
require "open3"
require "tmpdir"
require_relative "lefthook_binary"
require_relative "isolated_git"

# A project with a gem installed from git whose version comes from a git call, as mvpa-css does.
# The project has a linked worktree and a bare origin. HOME holds lefthook.yml and the global hook
# shims. Everything is real: git, lefthook and Bundler. Nothing touches the network.
#
# The including test calls `setup_git_gem_fixture` from `setup` and `teardown_git_gem_fixture` from
# `teardown`, and may override `project_files` to add files to the first project commit.
module GitGemFixture
  REPO_ROOT = File.expand_path("..", __dir__)
  NATIVE_LEFTHOOK = LefthookBinary.locate
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

  # The gem repository and the bundle are built once per run, because `bundle install` is slow.
  class << self
    attr_accessor :built

    def shared_root
      @shared_root ||= File.realpath(Dir.mktmpdir).tap { |dir| Minitest.after_run { FileUtils.rm_rf(dir) } }
    end
  end

  def setup_git_gem_fixture(tools: %w[bundle])
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK
    missing = tools.reject { |tool| executable_on_path?(tool) }
    skip_unless_ci("#{missing.join(", ")} not found on PATH, so the git gem hook cannot be checked") if missing.any?

    @tmpdir = File.realpath(Dir.mktmpdir)
    @gem_dir = File.join(GitGemFixture.shared_root, "house-style")
    build_shared_fixture
    build_home
    build_project
  end

  def teardown_git_gem_fixture
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  private

  # Files for the first project commit, as { relative path => content }. Override to add more.
  def project_files
    { "Gemfile" => gemfile }
  end

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
    stub = File.join(@home, ".config", "git", "worktree-tools", "review-report-fresh")
    FileUtils.mkdir_p(File.dirname(stub))
    File.write(stub, "#!/bin/sh\nexit 0\n")
    FileUtils.chmod("+x", stub)
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
    return if GitGemFixture.built

    write_files(
      @gem_dir,
      "house-style.gemspec" => GEMSPEC,
      "lib/house_style/version.rb" => GEM_VERSION_RB,
      "config/default.yml" => GEM_CONFIG
    )
    init_and_commit(@gem_dir, "Add house-style")
    install_gem_bundle
    GitGemFixture.built = true
  end

  def install_gem_bundle
    seed_dir = File.join(GitGemFixture.shared_root, "seed")
    write_files(seed_dir, "Gemfile" => gemfile)
    run!("bundle", "install", chdir: seed_dir)
    FileUtils.cp(File.join(seed_dir, "Gemfile.lock"), File.join(GitGemFixture.shared_root, "Gemfile.lock"))
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
    File.join(GitGemFixture.shared_root, "bundle")
  end

  def build_project
    @project_dir = File.join(@tmpdir, "project")
    @worktree_dir = File.join(@tmpdir, "worktree")
    write_files(@project_dir, project_files)
    FileUtils.cp(File.join(GitGemFixture.shared_root, "Gemfile.lock"), @project_dir)
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
      FileUtils.chmod("+x", path) if name.start_with?("bin/")
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

  def git(*args, hooks: true, chdir: @worktree_dir)
    env = hooks ? hook_env : hook_env("LEFTHOOK" => "0")
    Open3.capture2e(env, "git", *args, chdir: chdir)
  end

  def head
    git("rev-parse", "HEAD").first.strip
  end

  def remote_feature
    git("ls-remote", "origin", "feature").first.split.first
  end
end
