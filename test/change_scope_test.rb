#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# finish needs to know which of its two behaviours applies before doing
# anything else. change-scope answers that from the "origin" remote alone,
# reusing the same remote matching the consent guard already has (RemoteMatcher)
# so a repository only has to be taught the answer once.
class ChangeScopeTest < Minitest::Test
  SCRIPT = File.expand_path("../claude/.claude/skills/finish/scripts/change-scope", __dir__)

  def setup
    @repo = Dir.mktmpdir
    system("git", "-C", @repo, "init", "--quiet", "--initial-branch=main")
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

    assert_not(status.success?)
    assert_match(/unknown remote/i, stderr)
  end

  def test_no_remote_configured_is_refused
    _stdout, stderr, status = run_script

    assert_not(status.success?)
    assert_match(/unknown remote/i, stderr)
  end

  private

  def allow_remotes(*entries)
    File.write(File.join(@home, ".claude", "consent-guard-allowed-remotes.txt"), entries.join("\n"))
  end

  def add_remote(url)
    system("git", "-C", @repo, "remote", "add", "origin", url)
  end

  def run_script
    Open3.capture3({ "HOME" => @home }, SCRIPT, chdir: @repo)
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end
end
