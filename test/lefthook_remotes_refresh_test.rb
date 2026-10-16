#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# `lefthook-remotes-refresh` resets every lefthook remote cache under ~/Developer to origin's main.
# Real git, local bare repositories as origins, a fake HOME. Nothing touches the network.
class LefthookRemotesRefreshTest < Minitest::Test
  COMMAND = File.expand_path("../git/.local/bin/lefthook-remotes-refresh", __dir__)
  CACHE_PATH = ".git/info/lefthook-remotes/dotfiles".freeze

  def setup
    @tmpdir = File.realpath(Dir.mktmpdir)
    @home = File.join(@tmpdir, "home")
    FileUtils.mkdir_p(File.join(@home, "Developer"))
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_no_caches_exits_zero_with_no_output
    output, error, status = refresh

    assert_predicate(status, :success?, error)
    assert_empty(output)
  end

  def test_a_cache_behind_origin_is_updated_and_listed
    cache = build_cache("sticker-app")
    old = revision(cache)
    new = advance_origin("sticker-app")
    output, error, status = refresh

    assert_predicate(status, :success?, error)
    assert_equal("updated sticker-app: #{old[0, 7]} -> #{new[0, 7]}\n", output)
    assert_equal(new, revision(cache))
  end

  def test_a_current_cache_is_reported_current
    build_cache("sticker-app")
    output, error, status = refresh

    assert_predicate(status, :success?, error)
    assert_equal("current sticker-app\n", output)
  end

  def test_a_cache_with_local_changes_and_a_diverged_commit_ends_equal_to_origin_main
    cache = build_cache("caren")
    File.write(File.join(cache, "local.txt"), "local\n")
    git(cache, "add", "local.txt")
    git(cache, "commit", "--quiet", "-m", "Local commit")
    File.write(File.join(cache, "lefthook.yml"), "edited\n")
    File.write(File.join(cache, "untracked.txt"), "untracked\n")
    new = advance_origin("caren")
    _output, error, status = refresh

    assert_predicate(status, :success?, error)
    assert_equal(new, revision(cache))
    assert_empty(git(cache, "status", "--porcelain"))
  end

  def test_a_cache_on_another_branch_ends_on_main
    cache = build_cache("clocky")
    git(cache, "checkout", "--quiet", "-b", "wip")
    refresh

    assert_equal("main", git(cache, "rev-parse", "--abbrev-ref", "HEAD").strip)
    assert_equal(origin_revision("clocky"), revision(cache))
  end

  def test_an_unreachable_origin_is_named_and_the_other_caches_still_update
    build_cache("ambx")
    FileUtils.rm_rf(origin_dir("ambx"))
    build_cache("journal_administration")
    new = advance_origin("journal_administration")
    output, error, status = refresh

    assert_equal(1, status.exitstatus)
    assert_match(/^failed ambx: /, error)
    assert_includes(output, "updated journal_administration: ")
    assert_equal(new, revision(File.join(@home, "Developer", "journal_administration", CACHE_PATH)))
  end

  private

  def refresh
    Open3.capture3({ "HOME" => @home }, "ruby", COMMAND)
  end

  def origin_dir(repo)
    File.join(@tmpdir, "origins", "#{repo}.git")
  end

  def build_cache(repo)
    seed_origin(repo)
    cache = File.join(@home, "Developer", repo, CACHE_PATH)
    FileUtils.mkdir_p(File.dirname(cache))
    git(@tmpdir, "clone", "--quiet", "file://#{origin_dir(repo)}", cache)
    cache
  end

  def seed_origin(repo)
    git(@tmpdir, "init", "--quiet", "--bare", "--initial-branch=main", origin_dir(repo))
    seed = File.join(@tmpdir, "seeds", repo)
    git(@tmpdir, "clone", "--quiet", origin_dir(repo), seed)
    commit_in(seed, "lefthook.yml", "first\n")
  end

  def advance_origin(repo)
    seed = File.join(@tmpdir, "seeds", repo)
    commit_in(seed, "lefthook.yml", "second #{rand}\n")
    revision(seed)
  end

  def commit_in(dir, file, content)
    File.write(File.join(dir, file), content)
    git(dir, "add", file)
    git(dir, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", "Change")
    git(dir, "push", "--quiet", "origin", "HEAD:main")
  end

  def origin_revision(repo)
    git(@tmpdir, "--git-dir", origin_dir(repo), "rev-parse", "main").strip
  end

  def revision(dir)
    git(dir, "rev-parse", "HEAD").strip
  end

  def git(dir, *args)
    output, status = Open3.capture2e("git", *args, chdir: dir)
    flunk "git #{args.join(" ")} failed:\n#{output}" unless status.success?
    output
  end
end
