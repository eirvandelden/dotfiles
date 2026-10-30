#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "git_fixture"
require_relative "isolated_git"

# A GitFixture builds the repositories of a test file once and gives each test its own copy.
class GitFixtureTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @builds = 0
    @fixture = GitFixture.new do |root|
      @builds += 1
      build_origin_and_repo(root)
    end
  end

  def test_copy_builds_nothing_until_the_first_copy
    assert_equal(0, @builds)

    @fixture.copy

    assert_equal(1, @builds)
  end

  def test_copy_returns_a_new_real_path_directory_each_time
    first = @fixture.copy
    second = @fixture.copy

    refute_equal(first, second)
    [ first, second ].each do |copy|
      assert_path_exists(copy)
      assert_equal(File.realpath(copy), copy)
    end
  end

  def test_copy_gives_a_repository_with_the_originals_commits
    copy = @fixture.copy

    assert_equal([ "initial" ], git(File.join(copy, "repo"), "log", "--format=%s").split)
  end

  def test_the_build_runs_once_for_several_copies
    3.times { @fixture.copy }

    assert_equal(1, @builds)
  end

  def test_a_failed_build_leaves_no_copy_and_builds_again_on_the_next_call
    attempts = 0
    fixture = GitFixture.new do |root|
      attempts += 1
      if attempts == 1
        File.write(File.join(root, "partial"), "x")
        raise "build failed"
      end

      build_origin_and_repo(root)
    end

    assert_raises(RuntimeError) { fixture.copy }
    copy = fixture.copy

    assert_equal(2, attempts)
    refute_path_exists(File.join(copy, "partial"))
    assert_path_exists(File.join(copy, "repo"))
  end

  def test_a_commit_in_one_copy_is_absent_from_the_next_copy
    first = File.join(@fixture.copy, "repo")
    File.write(File.join(first, "extra.txt"), "x")
    git(first, "add", "extra.txt")
    git(first, "commit", "--quiet", "-m", "extra")

    second = File.join(@fixture.copy, "repo")

    assert_equal([ "initial" ], git(second, "log", "--format=%s").split)
    refute_path_exists(File.join(second, "extra.txt"))
  end

  def test_a_push_from_a_copy_lands_in_that_copys_origin
    first = @fixture.copy
    second = @fixture.copy

    git(File.join(first, "repo"), "push", "--quiet", "origin", "HEAD:refs/heads/pushed")

    assert_includes(branches(File.join(first, "origin")), "pushed")
    refute_includes(branches(File.join(second, "origin")), "pushed")
  end

  def test_a_linked_worktree_in_the_original_works_in_the_copy
    fixture = GitFixture.new do |root|
      build_origin_and_repo(root)
      git(File.join(root, "repo"), "worktree", "add", "--quiet", "-b", "feature", File.join(root, "feature"))
    end
    copy = fixture.copy

    assert_equal("feature", git(File.join(copy, "feature"), "branch", "--show-current").strip)
    assert_includes(git(File.join(copy, "repo"), "worktree", "list", "--porcelain"), "worktree #{File.join(copy, 'feature')}")
    assert_equal(File.join(copy, "repo", ".git"), File.realpath(git(File.join(copy, "feature"), "rev-parse",
                                                                    "--path-format=absolute", "--git-common-dir").strip))
  end

  def test_refuses_an_original_with_a_gitmodules_file
    fixture = GitFixture.new { |root| File.write(File.join(root, ".gitmodules"), "") }

    error = assert_raises(RuntimeError) { fixture.copy }

    assert_match(/submodule/, error.message)
  end

  def test_refuses_an_original_with_an_initialized_submodule
    fixture = GitFixture.new do |root|
      build_origin_and_repo(root)
      FileUtils.mkdir_p(File.join(root, "repo", ".git", "modules", "lib"))
    end

    error = assert_raises(RuntimeError) { fixture.copy }

    assert_match(/submodule/, error.message)
  end

  def test_a_sibling_path_that_starts_with_the_originals_path_is_left_alone
    fixture = GitFixture.new do |root|
      build_origin_and_repo(root)
      repo = File.join(root, "repo")
      git(repo, "config", "test.inside", "#{root}/deeper")
      git(repo, "config", "test.exact", root)
      git(repo, "config", "test.sibling", "#{root}2/deeper")
    end
    copy = fixture.copy
    repo = File.join(copy, "repo")

    assert_equal("#{copy}/deeper", git(repo, "config", "test.inside").strip)
    assert_equal(copy, git(repo, "config", "test.exact").strip)
    assert_match(%r{/git-fixture[^/]+/original2/deeper\z}, git(repo, "config", "test.sibling").strip)
  end

  def test_the_original_and_its_copies_are_gone_when_the_test_process_ends
    record = File.join(@fixture.copy, "record")
    child = write_child("ends", <<~RUBY)
      FIXTURE = GitFixture.new { |root| File.write(File.join(root, "built"), "x") }
      def test_copy = File.write(ENV.fetch("RECORD"), [ FIXTURE.copy, File.dirname(FIXTURE.copy) ].join("\\n"))
    RUBY
    dir = Dir.mktmpdir

    output, status = run_child(child, "RECORD" => record, "TMPDIR" => dir)

    assert(status.success?, output)
    copy, fixture = File.read(record).split("\n")
    refute_path_exists(copy)
    refute_path_exists(fixture)
    assert_empty(Dir.children(dir))
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_two_tests_that_share_a_fixture_pass_in_either_order
    [ %w[test_a_commit test_b_clean], %w[test_a_clean test_b_commit] ].each do |names|
      child = write_child("order", child_order_tests(*names))

      output, status = run_child(child)

      assert(status.success?, output)
      assert_match(/2 runs, 3 assertions, 0 failures, 0 errors, 0 skips/, output)
    end
  end

  def test_hooks_config_stash_and_worktrees_changed_in_one_copy_stay_out_of_the_next
    first = File.join(@fixture.copy, "repo")
    File.write(File.join(first, "README.md"), "changed\n")
    git(first, "config", "core.hooksPath", "/tmp/hooks")
    git(first, "config", "user.name", "Someone Else")
    git(first, "stash", "--quiet")
    git(first, "worktree", "add", "--quiet", "-b", "side", "#{first}-side")

    second = File.join(@fixture.copy, "repo")

    assert_equal("", git(second, "config", "--local", "--get-all", "core.hooksPath"))
    assert_equal("Test", git(second, "config", "user.name").strip)
    assert_equal("", git(second, "stash", "list"))
    assert_equal("", git(second, "branch", "--list", "side"))
    assert_equal(1, git(second, "worktree", "list").lines.size)
  end

  private

  def build_origin_and_repo(root)
    origin = File.join(root, "origin")
    repo = File.join(root, "repo")
    system("git", "init", "--quiet", "--bare", "--initial-branch=main", origin, exception: true)
    system("git", "init", "--quiet", "--initial-branch=main", repo, exception: true)
    { "user.email" => "test@example.com", "user.name" => "Test", "commit.gpgsign" => "false" }.each do |key, value|
      git(repo, "config", key, value)
    end
    git(repo, "remote", "add", "origin", origin)
    File.write(File.join(repo, "README.md"), "readme\n")
    git(repo, "add", "README.md")
    git(repo, "commit", "--quiet", "-m", "initial")
    git(repo, "push", "--quiet", "origin", "main")
  end

  def git(directory, *arguments)
    output, error, status = Open3.capture3("git", "-C", directory, *arguments)
    return output if status.success? || arguments.first == "config"

    raise("git #{arguments.join(' ')} failed: #{error}")
  end

  def branches(origin)
    Open3.capture2("git", "--git-dir", origin, "for-each-ref", "--format=%(refname:short)", "refs/heads/").first.split
  end

  def write_child(name, body)
    path = File.join(@child_dir ||= Dir.mktmpdir, "#{name}_test.rb")
    File.write(path, <<~RUBY)
      require "minitest/autorun"
      require #{File.join(ROOT, 'test', 'git_fixture').inspect}
      class #{name.capitalize}ChildTest < Minitest::Test
        def self.test_order = :alpha
      #{body.lines.map { |line| "  #{line}" }.join}
      end
    RUBY
    path
  end

  def child_order_tests(first, second)
    commit = <<~RUBY
      def %<name>s
        repo = File.join(FIXTURE.copy, "repo")
        File.write(File.join(repo, "extra.txt"), "x")
        system("git", "-C", repo, "add", "extra.txt", exception: true)
        system("git", "-C", repo, "commit", "--quiet", "-m", "extra", exception: true)
        assert_equal(2, `git -C \#{repo} rev-list --count HEAD`.to_i)
      end
    RUBY
    clean = <<~RUBY
      def %<name>s
        repo = File.join(FIXTURE.copy, "repo")
        assert_equal(1, `git -C \#{repo} rev-list --count HEAD`.to_i)
        assert_equal("", `git -C \#{repo} status --porcelain`)
      end
    RUBY
    build = <<~RUBY
      FIXTURE = GitFixture.new do |root|
        repo = File.join(root, "repo")
        system("git", "init", "--quiet", "--initial-branch=main", repo, exception: true)
        system("git", "-C", repo, "config", "user.email", "t@example.com", exception: true)
        system("git", "-C", repo, "config", "user.name", "T", exception: true)
        system("git", "-C", repo, "config", "commit.gpgsign", "false", exception: true)
        File.write(File.join(repo, "a"), "a")
        system("git", "-C", repo, "add", "a", exception: true)
        system("git", "-C", repo, "commit", "--quiet", "-m", "first", exception: true)
      end
    RUBY
    [ build, *[ first, second ].map { |name| format(name.include?("commit") ? commit : clean, name: name) } ].join("\n")
  end

  def run_child(path, env = {})
    Open3.capture2e(env, RbConfig.ruby, "-Itest", path, chdir: ROOT)
  end

  def teardown
    FileUtils.rm_rf(@child_dir) if @child_dir
  end
end
