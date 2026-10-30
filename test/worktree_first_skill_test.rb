#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "isolated_git"

# The worktree-first skill is prose plus a shell snippet. Step 1's snippet decides whether to
# reuse the current worktree or call worktree-create. These tests run that snippet in fixture
# repositories, with worktree-create wrapped so each call is logged, and read where the shell ends.
class WorktreeFirstSkillTest < Minitest::Test
  SKILL = File.expand_path("../agents/.agents/skills/worktree-first/SKILL.md", __dir__)
  CREATE = File.expand_path("../git/.config/git/worktree-tools/worktree-create", __dir__)
  WITHOUT_GLOBAL_GIT_CONFIG = { "GIT_CONFIG_GLOBAL" => "/dev/null" }.freeze

  # <root>/origin.git (bare, main), <root>/seed (clone that pushed the first commit) and <root>/repo (clone
  # of the origin with .worktrees excluded).
  ORIGIN_AND_CLONE = GitFixture.new do |root|
    origin = File.join(root, "origin.git")
    git = lambda do |directory, *arguments|
      system("git", "-C", directory, "-c", "core.hooksPath=/dev/null", "-c", "user.email=test@example.com",
             "-c", "user.name=Test", *arguments, err: File::NULL, exception: true)
    end
    git.call(root, "init", "--quiet", "--bare", "--initial-branch=main", origin)
    git.call(root, "clone", "--quiet", origin, File.join(root, "seed"))
    File.write(File.join(root, "seed", "file-initial.txt"), "initial")
    git.call(File.join(root, "seed"), "add", "-A")
    git.call(File.join(root, "seed"), "commit", "--quiet", "-m", "initial")
    git.call(File.join(root, "seed"), "push", "--quiet", "origin", "main")
    git.call(root, "clone", "--quiet", origin, File.join(root, "repo"))
    File.write(File.join(root, "repo", ".git", "info", "exclude"), ".worktrees\n")
  end

  def setup
    @enclosing = ORIGIN_AND_CLONE.copy
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
    { "HOME" => @home, "PATH" => [ gh_stub_dir, ENV.fetch("PATH") ].join(File::PATH_SEPARATOR),
      "HERDR_ENV" => nil, "GIT_CONFIG_GLOBAL" => "/dev/null", "CREATE_CALL_LOG" => create_call_log }
  end

  # A failing `gh` first on PATH. Dropping every PATH dir that holds `gh` also drops `bash` on CI,
  # where both live in /usr/bin.
  def gh_stub_dir
    dir = File.join(@enclosing, "bin")
    stub = File.join(dir, "gh")
    return dir if File.exist?(stub)

    FileUtils.mkdir_p(dir)
    File.write(stub, "#!/bin/sh\nexit 1\n")
    FileUtils.chmod(0o755, stub)
    dir
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
    [ File.join(@enclosing, "origin.git"), File.join(@enclosing, "repo") ]
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
    output, status = Open3.capture2(WITHOUT_GLOBAL_GIT_CONFIG, "git", "-C", dir, "-c", "core.hooksPath=/dev/null",
                                    "-c", "user.email=test@example.com", "-c", "user.name=Test",
                                    "-c", "protocol.file.allow=always", *arguments)
    raise("git #{arguments.join(' ')} failed: #{output}") unless status.success?

    output
  end
end
