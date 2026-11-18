#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# worktree-pane checks its arguments inside a herdr-app terminal (HC_TERMINAL_ID set) and hands over to
# herdr-app-pane; see worktree_pane_herdr_app_test.rb for what it runs. The stub herdr-app-pane logs its arguments.
class WorktreePaneTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-pane", __dir__)

  # A repository at <root>/dotfiles with one empty commit and a linked worktree on feature at <root>/worktree.
  REPOSITORY = GitFixture.new do |root|
    repo = File.join(root, "dotfiles")
    git = [ "git", "-C", repo, "-c", "core.hooksPath=/dev/null", "-c", "user.email=test@example.com",
            "-c", "user.name=Test" ]
    system("git", "init", "--quiet", "--initial-branch=main", repo, exception: true)
    system(*git, "commit", "--quiet", "--allow-empty", "-m", "initial", exception: true)
    system(*git, "worktree", "add", "--quiet", "-b", "feature", File.join(root, "worktree"), exception: true)
  end

  def setup
    @stub_bin = Dir.mktmpdir
    @extra_dirs = [ @stub_bin ]
    install_pane_stub
    @worktree = repo_worktree
  end

  def teardown
    FileUtils.rm_rf(@extra_dirs)
  end

  def test_open_outside_a_herdr_app_terminal_does_nothing_and_exits_zero
    _, _, status = run_script("open", @worktree, hc_terminal_id: nil)

    assert_equal(0, status.exitstatus)
    assert_empty(pane_calls)
  end

  def test_open_without_a_path_prints_usage_and_exits_one
    _, stderr, status = run_script("open", nil)

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
    assert_match(/Usage: worktree-pane/, stderr)
  end

  def test_open_on_a_missing_path_prints_one_line_and_exits_one
    _, stderr, status = run_script("open", "/no/such/path")

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
  end

  def test_open_outside_any_git_repository_prints_one_line_and_exits_one
    outside = Dir.mktmpdir
    @extra_dirs << outside

    _, stderr, status = run_script("open", outside)

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
  end

  def test_an_unknown_command_prints_usage_before_any_path_or_git_check
    outside = Dir.mktmpdir
    @extra_dirs << outside

    _, stderr, status = run_script("bogus", outside)

    assert_equal(1, status.exitstatus)
    assert_match(/Usage: worktree-pane/, stderr)
  end

  def test_the_shebang_does_not_depend_on_rv_being_on_path
    assert_equal("#!/usr/bin/env ruby\n", File.readlines(SCRIPT).first)
  end

  private

  def repo_worktree
    enclosing = REPOSITORY.copy
    @extra_dirs << enclosing
    File.join(enclosing, "worktree")
  end

  def install_pane_stub
    stub = File.join(@stub_bin, "herdr-app-pane")
    File.write(stub, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$PANE_CALL_LOG\"\n")
    FileUtils.chmod(0o755, stub)
  end

  def run_script(command, path, hc_terminal_id: "t10")
    environment = HerdrAppHarness::CLEARED_ENV.merge(
      "HC_TERMINAL_ID" => hc_terminal_id, "HERDR_APP_PANE" => File.join(@stub_bin, "herdr-app-pane"),
      "PANE_CALL_LOG" => call_log
    )
    Open3.capture3(environment, "ruby", SCRIPT, *[ command, path ].compact)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def pane_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
  end
end
