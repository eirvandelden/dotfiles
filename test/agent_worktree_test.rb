#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../git/.config/git/worktree-tools/lib", __dir__))
require "agent_worktree"

# AgentWorktree remembers, per herdr pane, the worktree its agent created or reused last.
class AgentWorktreeTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    @state_home = File.join(@root, "state")
    @previous_state_home = ENV["XDG_STATE_HOME"]
    ENV["XDG_STATE_HOME"] = @state_home
    @main = create_repository("main")
    @worktree = add_worktree(@main, "feature")
    @records = WorktreeTools::AgentWorktree.new
  end

  def teardown
    ENV["XDG_STATE_HOME"] = @previous_state_home
    FileUtils.rm_rf(@root)
  end

  def test_usable_for_returns_nil_without_a_record
    assert_nil(@records.usable_for("w1:pA", "term_A", beside: @main))
  end

  def test_usable_for_ignores_a_record_that_is_not_an_object
    [ "[]", %("text"), "null", %({"terminal_id": "term_A"}), %({"terminal_id": "term_A", "path": 7}) ].each do |content|
      FileUtils.mkdir_p(File.dirname(record_file("w1_pA")))
      File.write(record_file("w1_pA"), content)

      assert_nil(@records.usable_for("w1:pA", "term_A", beside: @main), content)
    end
  end

  def test_usable_for_ignores_a_record_path_that_cannot_be_read
    FileUtils.mkdir_p(record_file("w1_pA"))

    assert_nil(@records.usable_for("w1:pA", "term_A", beside: @main))
  end

  def test_usable_for_refuses_a_record_from_another_terminal
    @records.record("w1:pA", "term_old", @worktree)

    assert_nil(@records.usable_for("w1:pA", "term_new", beside: @main))
  end

  def test_usable_for_refuses_a_missing_folder
    @records.record("w1:pA", "term_A", @worktree)
    system("git", "-C", @main, "worktree", "remove", "--force", @worktree, exception: true)

    assert_nil(@records.usable_for("w1:pA", "term_A", beside: @main))
  end

  def test_usable_for_refuses_another_repository
    other_worktree = add_worktree(create_repository("other"), "feature")
    @records.record("w1:pA", "term_A", other_worktree)

    assert_nil(@records.usable_for("w1:pA", "term_A", beside: @main))
  end

  def test_usable_for_returns_the_recorded_path_within_the_same_repository
    @records.record("w1:pA", "term_A", @worktree)

    assert_equal(@worktree, @records.usable_for("w1:pA", "term_A", beside: @main))
  end

  def test_record_replaces_an_earlier_path
    second = add_worktree(@main, "second")
    @records.record("w1:pA", "term_A", @worktree)
    @records.record("w1:pA", "term_A", second)

    assert_equal(second, @records.usable_for("w1:pA", "term_A", beside: @main))
  end

  def test_record_writes_the_path_for_the_pane
    @records.record("w1:pA", "term_A", @worktree)

    stored = JSON.parse(File.read(record_file("w1_pA")))
    assert_equal({ "terminal_id" => "term_A", "path" => @worktree }, stored)
  end

  def test_a_pane_id_with_a_colon_maps_to_a_safe_file_name
    @records.record("w1:p2", "term_A", @worktree)

    assert_equal([ "w1_p2" ], Dir.children(File.join(@state_home, "worktree-tools", "agent-worktrees")))
  end

  private

  def record_file(name)
    File.join(@state_home, "worktree-tools", "agent-worktrees", name)
  end

  def create_repository(name)
    path = File.join(@root, name)
    FileUtils.mkdir_p(path)
    git(path, "init", "--quiet", "--initial-branch=main")
    git(path, "commit", "--quiet", "--allow-empty", "-m", "initial")
    File.realpath(path)
  end

  def add_worktree(repository, name)
    path = File.join(repository, ".worktrees", name)
    git(repository, "worktree", "add", "--quiet", path, "-b", name)
    File.realpath(path)
  end

  def git(dir, *arguments)
    system("git", "-C", dir, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test",
           "-c", "user.email=test@example.com", *arguments, exception: true)
  end
end
