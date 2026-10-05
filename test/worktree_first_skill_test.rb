#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# The worktree-first skill is prose plus a shell snippet. Step 1's snippet decides whether to
# reuse the current worktree or call worktree-create. These tests run that snippet in fixture
# repositories, with worktree-create wrapped so each call is logged, and read where the shell ends.
class WorktreeFirstSkillTest < Minitest::Test
  SKILL = File.expand_path("../claude/.claude/skills/worktree-first/SKILL.md", __dir__)
  CREATE = File.expand_path("../git/.config/git/worktree-tools/worktree-create", __dir__)

  def setup
    @enclosing = Dir.mktmpdir
    @home = File.join(@enclosing, "home")
    @origin, @repo = origin_and_clone
    install_create_wrapper
  end

  def teardown
    FileUtils.rm_rf(@enclosing)
  end

  def test_skip_when_no_longer_skips_in_any_linked_worktree
    skip_section = File.read(SKILL)[/^## Skip when\n(.*?)^## /m, 1]

    refute_match(/already inside a linked worktree/i, skip_section)
    refute_match(/git-common-dir/, skip_section)
  end

  def test_inside_the_tasks_own_worktree_it_reuses_it_without_calling_worktree_create
    own = add_worktree(@repo, "bar")

    ended_in = run_snippet("bar", chdir: own)

    assert_equal(File.realpath(own), ended_in)
    assert_empty(create_calls, "worktree-create was called")
  end

  def test_from_inside_another_dot_worktrees_worktree_it_creates_the_new_one_under_the_main_checkout
    foo = add_worktree(@repo, "foo")

    ended_in = run_snippet("new-task", chdir: foo)

    assert_equal(File.join(File.realpath(@repo), ".worktrees", "new-task"), ended_in)
    assert_equal([ "new-task" ], create_calls)
  end

  def test_from_inside_a_claude_worktree_it_creates_the_new_one_under_the_main_checkout
    claude_worktree = File.join(@repo, ".claude", "worktrees", "foo")
    git(@repo, "worktree", "add", "--quiet", claude_worktree, "-b", "foo", "origin/main")

    ended_in = run_snippet("new-task", chdir: claude_worktree)

    assert_equal(File.join(File.realpath(@repo), ".worktrees", "new-task"), ended_in)
    assert_equal([ "new-task" ], create_calls)
  end

  def test_inside_a_worktree_nested_in_another_linked_worktree_it_does_not_skip
    foo = add_worktree(@repo, "foo")
    nested = add_worktree(foo, "bar")

    ended_in = run_snippet("new-task", chdir: nested)

    assert_equal(File.join(File.realpath(@repo), ".worktrees", "new-task"), ended_in)
    assert_equal([ "new-task" ], create_calls)
  end

  def test_inside_a_submodules_own_worktree_for_the_task_it_reuses_it
    submodule = add_submodule("child")
    own = add_worktree(submodule, "task")

    ended_in = run_snippet("task", chdir: own)

    assert_equal(File.realpath(own), ended_in)
    assert_empty(create_calls, "worktree-create was called")
  end

  private

  # The Step 1 block that runs worktree-create, not the branch-naming block, which would
  # overwrite `branch`.
  def snippet
    File.read(SKILL).scan(/^```bash\n(.*?)^```/m).flatten.find { |block| block.include?("worktree-create") } ||
      flunk("SKILL.md has no bash block that runs worktree-create")
  end

  # Runs the snippet with `branch` set and returns the directory the shell ends in. The EXIT trap
  # reports it even when the snippet leaves through `exit`.
  def run_snippet(branch, chdir:)
    ended_in_file = File.join(@enclosing, "ended-in.txt")
    script = "trap 'pwd -P > #{ended_in_file}' EXIT\nbranch=#{branch}\n#{snippet}"
    _, stderr, status = Open3.capture3(environment, "bash", "-c", script, chdir: chdir)
    assert(status.success?, stderr)
    File.read(ended_in_file).strip
  end

  def environment
    path = ENV.fetch("PATH").split(File::PATH_SEPARATOR)
    { "HOME" => @home, "PATH" => path.reject { |dir| File.executable?(File.join(dir, "gh")) }.join(":"),
      "HERDR_ENV" => nil, "CREATE_CALL_LOG" => create_call_log }
  end

  def install_create_wrapper
    wrapper = File.join(@home, ".config", "git", "worktree-tools", "worktree-create")
    FileUtils.mkdir_p(File.dirname(wrapper))
    File.write(wrapper, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> "$CREATE_CALL_LOG"
      exec ruby #{CREATE} "$@"
    SH
    FileUtils.chmod(0o755, wrapper)
  end

  def create_call_log
    File.join(@enclosing, "create-calls.log")
  end

  def create_calls
    File.exist?(create_call_log) ? File.readlines(create_call_log, chomp: true) : []
  end

  def origin_and_clone
    origin = File.join(@enclosing, "origin.git")
    FileUtils.mkdir_p(origin)
    git(origin, "init", "--quiet", "--bare", "--initial-branch=main")

    seed = File.join(@enclosing, "seed")
    git(@enclosing, "clone", "--quiet", origin, seed)
    commit(seed, "initial")
    git(seed, "push", "--quiet", "origin", "main")

    repo = File.join(@enclosing, "repo")
    git(@enclosing, "clone", "--quiet", origin, repo)
    File.write(File.join(repo, ".git", "info", "exclude"), ".worktrees\n")
    [ origin, repo ]
  end

  def add_worktree(parent, name)
    git(parent, "worktree", "add", "--quiet", File.join(".worktrees", name), "-b", name, "origin/main")
    File.join(parent, ".worktrees", name)
  end

  def add_submodule(name)
    child_origin = File.join(@enclosing, "#{name}.git")
    FileUtils.mkdir_p(child_origin)
    git(child_origin, "init", "--quiet", "--bare", "--initial-branch=main")

    child_seed = File.join(@enclosing, "#{name}-seed")
    git(@enclosing, "clone", "--quiet", child_origin, child_seed)
    commit(child_seed, "#{name} initial")
    git(child_seed, "push", "--quiet", "origin", "main")

    git(@repo, "submodule", "add", "--quiet", child_origin, name)
    commit(@repo, "add #{name} submodule")

    submodule = File.join(@repo, name)
    File.write(File.join(git(submodule, "rev-parse", "--absolute-git-dir").strip, "info", "exclude"), ".worktrees\n")
    submodule
  end

  def commit(dir, message)
    File.write(File.join(dir, "file-#{message.tr(' ', '-')}.txt"), message)
    git(dir, "add", "-A")
    git(dir, "commit", "--quiet", "-m", message)
  end

  def git(dir, *arguments)
    output, status = Open3.capture2("git", "-C", dir, "-c", "core.hooksPath=/dev/null",
                                    "-c", "user.email=test@example.com", "-c", "user.name=Test",
                                    "-c", "protocol.file.allow=always", *arguments)
    raise("git #{arguments.join(' ')} failed: #{output}") unless status.success?

    output
  end
end
