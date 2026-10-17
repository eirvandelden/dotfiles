#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"
require_relative "lefthook_binary"
require_relative "isolated_git"

# Real `git commit` and `git push` runs through the global pre-commit and pre-push hooks and the
# repository's lefthook.yml. The pre-push checks must scan only the files the branch itself changes
# against main, also after a rebase over a main that moved on. The marker words are built by
# concatenation, so this file passes the marker checks it tests.
class LefthookBranchFilesTest < Minitest::Test
  TRUNK = "trunk"
  BRANCH = "claims-status"
  FIX_WORD = "FIX" + "ME"
  COMMIT_WORD = "NO" + "COMMIT"
  NATIVE_LEFTHOOK = LefthookBinary.locate

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @home = Dir.mktmpdir
    @bin_dir = File.join(@home, "bin")
    @work = File.join(@home, "work")
    link_global_setup
    stub_commands
    create_repositories
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_a_rebased_branch_pushes_past_markers_that_only_main_added
    branch_pushed_before_main_moved
    main_adds("notes/main-only.txt", "# #{FIX_WORD} main wrote this\n")
    rebase_over_main

    stdout, stderr, status = push("--force-with-lease")

    assert(status.success?, stdout + stderr)
  end

  def test_a_marker_in_an_own_file_blocks_the_push_after_a_rebase
    branch_pushed_before_main_moved
    main_adds("notes/main-only.txt", "clean\n")
    commit_without_hooks("notes/own.txt", "# #{FIX_WORD} mine\n")
    rebase_over_main

    stdout, stderr, status = push("--force-with-lease")

    refute(status.success?)
    assert_match(/notes\/own\.txt:1:/, stdout + stderr)
  end

  def test_a_marker_in_an_own_file_blocks_the_commit
    git(@work, "checkout", "--quiet", "-b", BRANCH)

    stdout, stderr, status = commit_with_hooks("notes/own.txt", "# #{FIX_WORD} mine\n")

    refute(status.success?)
    assert_match(/notes\/own\.txt:1:/, stdout + stderr)
  end

  def test_after_a_rebase_shellcheck_and_yamllint_check_only_own_files
    branch_pushed_before_main_moved
    main_adds("scripts/main.sh", "echo main\n")
    main_adds("config/main.yml", "main: true\n")
    commit_without_hooks("scripts/own.sh", "echo own\n")
    commit_without_hooks("config/own.yml", "own: true\n")
    rebase_over_main

    stdout, stderr, status = push("--force-with-lease")

    assert(status.success?, stdout + stderr)
    assert_equal(%w[scripts/own.sh], logged("shellcheck"))
    assert_equal(%w[config/own.yml], logged("yamllint"))
  end

  def test_no_pre_push_command_uses_push_files
    pre_push = YAML.safe_load_file(File.join(@repo_root, "lefthook.yml")).fetch("pre-push")

    pre_push.fetch("commands").each do |name, command|
      refute_includes(command.fetch("run"), "{push_files}", "pre-push #{name} still reads {push_files}")
    end
  end

  def test_a_fresh_branch_checks_exactly_its_own_files
    git(@work, "checkout", "--quiet", "-b", BRANCH)
    commit_without_hooks("scripts/own.sh", "echo own\n")
    commit_without_hooks("config/own.yml", "own: true\n")

    stdout, stderr, status = push

    assert(status.success?, stdout + stderr)
    assert_equal(%w[scripts/own.sh], logged("shellcheck"))
    assert_equal(%w[config/own.yml], logged("yamllint"))
  end

  def test_a_repository_without_an_origin_default_branch_falls_back_to_the_push_target
    branch_pushed_before_main_moved
    git(@work, "remote", "set-head", "origin", "--delete")
    commit_without_hooks("notes/own.txt", "# #{FIX_WORD} mine\n")

    stdout, stderr, status = push

    refute(status.success?)
    assert_match(/notes\/own\.txt:1:/, stdout + stderr)
  end

  def test_a_marker_under_vendor_commits_and_pushes
    git(@work, "checkout", "--quiet", "-b", BRANCH)

    assert_commits_and_pushes("vendor/lib/notes.txt", "# #{FIX_WORD} upstream\n")
  end

  def test_a_nocommit_marker_in_a_listed_vendored_path_commits_and_pushes
    git(@work, "checkout", "--quiet", "-b", BRANCH)
    commit_without_hooks(".gitattributes", "third_party/** linguist-vendored\n")

    assert_commits_and_pushes("third_party/notes.txt", "upstream says #{COMMIT_WORD}\n")
  end

  def test_a_vendored_skill_file_with_a_marker_commits_and_pushes
    use_the_dotfiles_vendored_list
    skill_file = "agents/.agents/skills/37signals-style/references/development-philosophy.md"

    assert_commits_and_pushes(skill_file, "Mark a rough spot with #{FIX_WORD} in prose.\n")
  end

  def test_a_marker_in_a_non_vendored_skill_blocks_the_push
    use_the_dotfiles_vendored_list
    commit_without_hooks("agents/.agents/skills/intent/SKILL.md", "# #{FIX_WORD}\n")

    stdout, stderr, status = push

    refute(status.success?)
    assert_match(/agents\/\.agents\/skills\/intent\/SKILL\.md:1:/, stdout + stderr)
  end

  def test_a_vendored_shell_file_still_reaches_shellcheck
    use_the_dotfiles_vendored_list
    shell_file = "agents/.agents/skills/ruby/scripts/check.sh"
    commit_without_hooks(shell_file, "# #{FIX_WORD}\n")

    stdout, stderr, status = push

    assert(status.success?, stdout + stderr)
    assert_equal([ shell_file ], logged("shellcheck"))
  end

  def test_a_linked_worktree_without_own_changes_cannot_push_to_main
    worktree = File.join(@home, "linked")
    git(@work, "worktree", "add", "--quiet", "-b", BRANCH, worktree, "origin/#{TRUNK}")
    git(worktree, "commit", "--quiet", "--allow-empty", "-m", "empty")

    stdout, stderr, status = Open3.capture3(environment, "git", "-C", worktree, "push", "origin", "HEAD:main")

    refute(status.success?, stdout + stderr)
    assert_match(/Pushing to main is not allowed/, stdout + stderr)
  end

  private

  def assert_commits_and_pushes(relative_path, content)
    stdout, stderr, status = commit_with_hooks(relative_path, content)
    assert(status.success?, "commit: #{stdout}#{stderr}")

    stdout, stderr, status = push
    assert(status.success?, "push: #{stdout}#{stderr}")
  end

  # The repository's real .gitattributes, committed on the branch as the first commit.
  def use_the_dotfiles_vendored_list
    git(@work, "checkout", "--quiet", "-b", BRANCH)
    commit_without_hooks(".gitattributes", File.read(File.join(@repo_root, ".gitattributes")))
  end

  def commit_without_hooks(relative_path, content)
    commit(relative_path, content, "add #{relative_path}")
  end

  def commit_with_hooks(relative_path, content)
    path = File.join(@work, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    git(@work, "add", relative_path)
    Open3.capture3(environment, "git", "-C", @work, "commit", "--quiet", "-m", "add #{relative_path}")
  end

  # The file paths a stub linter received; its flags and their values are left out.
  def logged(name)
    path = File.join(@home, "#{name}.log")
    return [] unless File.exist?(path)

    File.read(path).split.reject { |argument| argument.start_with?("-") || argument == "warning" }
  end

  def branch_pushed_before_main_moved
    git(@work, "checkout", "--quiet", "-b", BRANCH)
    commit("app/claims.txt", "claims\n", "touch code")
    git(@work, "push", "--quiet", "-u", "origin", BRANCH)
  end

  def main_adds(relative_path, content)
    git(@work, "checkout", "--quiet", TRUNK)
    commit(relative_path, content, "main adds #{relative_path}")
    git(@work, "push", "--quiet", "origin", TRUNK)
    git(@work, "checkout", "--quiet", BRANCH)
  end

  def rebase_over_main
    git(@work, "fetch", "--quiet", "origin")
    git(@work, "rebase", "--quiet", "origin/#{TRUNK}")
  end

  def link_global_setup
    hooks = File.join(@home, ".config", "git", "hooks")
    FileUtils.mkdir_p(hooks)
    File.write(File.join(@home, ".gitconfig"), "[user]\n  name = Test\n  email = test@example.com\n")
    File.write(File.join(@home, ".config", "git", "config"), "[core]\n  hooksPath = ~/.config/git/hooks\n")
    %w[pre-commit pre-push].each do |hook|
      File.symlink(File.join(@repo_root, "git/.config/git/hooks", hook), File.join(hooks, hook))
    end
    link_worktree_tools
  end

  # The fallback config runs marker-check from the dotfiles checkout beside it, with no stow link;
  # review-report-fresh is the only script still reached through ~/.config.
  def link_worktree_tools
    tools = File.join(@repo_root, "git/.config/git/worktree-tools")
    FileUtils.mkdir_p(File.join(@home, ".config", "git", "worktree-tools"))
    File.symlink(File.join(tools, "review-report-fresh"), File.join(@home, ".config", "git", "worktree-tools", "review-report-fresh"))
    scripts = File.join(@home, "Developer", "dotfiles", "git", ".config", "git", "worktree-tools")
    FileUtils.mkdir_p(scripts)
    File.symlink(File.join(tools, "marker-check"), File.join(scripts, "marker-check"))
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(@home, "Developer", "dotfiles"))
  end

  # gh reports no open pull request; shellcheck and yamllint log their arguments to $HOME/<name>.log.
  def stub_commands
    FileUtils.mkdir_p(@bin_dir)
    write_stub("gh", "echo 0")
    %w[shellcheck yamllint].each do |name|
      write_stub(name, "echo \"$@\" >> \"#{File.join(@home, "#{name}.log")}\"")
    end
  end

  def write_stub(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    FileUtils.chmod("+x", path)
  end

  def create_repositories
    origin = File.join(@home, "origin.git")
    git(@home, "init", "--bare", "--quiet", origin)
    git(@home, "-C", origin, "symbolic-ref", "HEAD", "refs/heads/#{TRUNK}")
    git(@home, "clone", "--quiet", origin, @work)
    commit("README.md", "initial", "init")
    git(@work, "push", "--quiet", "origin", "HEAD:#{TRUNK}")
    git(@work, "remote", "set-head", "origin", TRUNK)
  end

  def commit(relative_path, content, message)
    path = File.join(@work, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    git(@work, "add", relative_path)
    git(@work, "commit", "--quiet", "-m", message)
  end

  # Runs without the hooks, to build state that the hooks would refuse.
  def git(directory, *arguments)
    _, stderr, status = Open3.capture3(environment.merge("LEFTHOOK" => "0"), "git", "-C", directory, *arguments)
    flunk("git #{arguments.join(' ')} failed: #{stderr}") unless status.success?
  end

  def push(*options)
    Open3.capture3(environment, "git", "-C", @work, "push", *options, "-u", "origin", BRANCH)
  end

  def environment
    ruby_bin = File.dirname(RbConfig.ruby)
    { "HOME" => @home, "PATH" => "#{@bin_dir}:#{ruby_bin}:/usr/bin:/bin", "GIT_CONFIG_GLOBAL" => nil,
      "GIT_CONFIG_SYSTEM" => "/dev/null", "XDG_CONFIG_HOME" => nil, "LEFTHOOK" => nil, "LEFTHOOK_CONFIG" => nil,
      "LEFTHOOK_VERBOSE" => nil, "LEFTHOOK_BIN" => NATIVE_LEFTHOOK.to_s }
  end
end
