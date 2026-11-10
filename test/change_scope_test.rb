#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "isolated_git"
require_relative "../agents/.agents/skills/finish/scripts/change_scope"

# finish needs to know which of its two behaviours applies before doing
# anything else. change-scope answers that from the "origin" remote alone,
# reusing the same remote matching the consent guard already has (RemoteMatcher)
# so a repository only has to be taught the answer once.
class ChangeScopeTest < Minitest::Test
  SCRIPT = File.expand_path("../agents/.agents/skills/finish/scripts/change-scope", __dir__)

  REPOSITORY = GitFixture.new do |repo|
    system("git", "-C", repo, "init", "--quiet", "--initial-branch=main", exception: true)
  end

  def setup
    @repo = REPOSITORY.copy
    # A home of its own, so the script reads the allowlist this test wrote and
    # never the one installed on the machine running the suite.
    @home = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@home, ".claude"))
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@home)
  end

  def test_the_users_own_remote_is_personal
    add_remote("git@github.com:eirvandelden/dotfiles.git")

    stdout, stderr, status = run_script

    assert(status.success?, stderr)
    assert_equal("personal", stdout.strip)
  end

  def test_an_allowlisted_remote_is_work
    allow_remotes("employer/their-app")
    add_remote("git@github.com:employer/their-app.git")

    stdout, stderr, status = run_script

    assert(status.success?, stderr)
    assert_equal("work", stdout.strip)
  end

  def test_an_unrecognised_remote_is_refused
    add_remote("git@github.com:someone-else/dotfiles.git")

    _stdout, stderr, status = run_script

    refute(status.success?)
    assert_match(/unknown remote/i, stderr)
  end

  def test_no_remote_configured_is_refused
    _stdout, stderr, status = run_script

    refute(status.success?)
    assert_match(/unknown remote/i, stderr)
  end

  def test_current_answers_personal_for_the_own_account
    assert_equal("personal", ChangeScope.current("git@github.com:eirvandelden/dotfiles.git"))
  end

  def test_current_answers_work_for_an_allowlisted_origin
    allow_remotes("employer/their-app")

    assert_equal("work", with_home { ChangeScope.current("git@github.com:employer/their-app.git") })
  end

  def test_current_answers_nil_for_an_unknown_origin
    assert_nil(with_home { ChangeScope.current("git@github.com:someone-else/dotfiles.git") })
  end

  def test_work_is_false_for_an_unknown_origin
    add_remote("git@github.com:someone-else/dotfiles.git")

    refute(Dir.chdir(@repo) { with_home { ChangeScope.work? } })
  end

  def test_work_is_true_for_an_allowlisted_origin
    allow_remotes("employer/their-app")
    add_remote("git@github.com:employer/their-app.git")

    assert(Dir.chdir(@repo) { with_home { ChangeScope.work? } })
  end

  private

  def with_home
    previous = ENV["HOME"]
    ENV["HOME"] = @home
    yield
  ensure
    ENV["HOME"] = previous
  end

  def allow_remotes(*entries)
    File.write(File.join(@home, ".claude", "consent-guard-allowed-remotes.txt"), entries.join("\n"))
  end

  def add_remote(url)
    system("git", "-C", @repo, "remote", "add", "origin", url)
  end

  def run_script
    Open3.capture3({ "HOME" => @home }, SCRIPT, chdir: @repo)
  end
end
