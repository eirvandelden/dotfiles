#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "yaml"
require "tmpdir"
require_relative "isolated_git"
require_relative "hook_scripts"
require_relative "lefthook_binary"

class BranchGuardTest < Minitest::Test
  NATIVE_LEFTHOOK = LefthookBinary.locate
  REPO_ROOT = File.expand_path("..", __dir__)
  GUARD_FILE = File.join(REPO_ROOT, "lefthook-branch-guard.yml")
  REFUSAL = /Direct commit to (main|master) is not allowed\. Create a feature branch; deliver opens the PR\./

  PUSH_REFUSAL = Regexp.union(
    /Pushing to (main|master) is not allowed\. Push a feature branch; deliver opens the PR\./,
    /Direct push to (main|master) is not allowed\. Create a feature branch; deliver opens the PR\./
  )

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK

    @tmpdir = Dir.mktmpdir
    @repo_dir = File.join(@tmpdir, "repo")
    @origin_dir = File.join(@tmpdir, "origin.git")
    @hooks_dir = HookScripts.directory
    @log_file = File.join(@tmpdir, "pre-push.log")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  # Each chain below runs the steps of several former single-behaviour tests in one repository, in an order
  # that keeps every step's starting state: a refused commit or push changes nothing, so the next step sees
  # what its former test saw.

  def test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work
    setup_extending_repo("main")
    # empty commit on a clean index: commit-msg refuses it
    assert_empty_commit_refused
    # amend that stages no change: commit-msg refuses it
    assert_amend_without_change_refused
    # a commit with a staged file: pre-commit refuses it
    stage_file("change.txt", "change\n")
    out, err, status = git("commit", "-m", "change")
    refute(status.success?, "Expected a commit on main to be refused")
    assert_match(REFUSAL, out + err)
    assert_amend_with_change_refused
    assert_push_refused("origin", "main")
    switch_to_feature
    assert_push_refused("origin", "feature:main")
    assert_push_refused("origin", "feature:master")
    assert_push_refused("origin", "HEAD:main")
    assert_push_refused("origin", "feature:feature", "HEAD:main")
    publish_branch("main")
    assert_push_refused("origin", "--delete", "main")
    # a feature branch commit and a same-name push go through; the extending repo's own pre-push runs once
    stage_file("change.txt", "change\n")
    _out, err, status = git("commit", "-m", "change")
    assert(status.success?, "Expected a feature branch commit to go through:\n#{err}")
    File.write(@log_file, "")
    assert_push_allowed("feature:feature")
    assert_equal("own-check\n", File.read(@log_file))
    _out, err, status = git("commit", "--allow-empty", "-m", "empty")
    assert(status.success?, "Expected an empty commit on a feature branch to go through:\n#{err}")
    assert_push_allowed("feature:main-fix")
    assert_push_allowed("feature:mainline")
    assert_tag_push_allowed
  end

  def test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes
    setup_extending_repo("master")
    # empty commit first, on a clean index, so commit-msg and not pre-commit refuses it
    assert_empty_commit_refused
    stage_file("change.txt", "change\n")
    out, err, status = git("commit", "-m", "change")
    refute(status.success?, "Expected a commit on master to be refused")
    assert_match(REFUSAL, out + err)
    assert_push_refused("origin", "master")
  end

  def test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash
    setup_extending_repo("main")
    # every merge scenario has its own diverged branch, so none is already up to date
    diverge("merge-a")
    assert_merge_allowed(@repo_dir, "merge-a", "--no-ff", "-m", "merge")
    diverge("merge-b")
    assert_merge_allowed(@repo_dir, "merge-b", "--no-ff", "-s", "ours", "-m", "merge")
    conflicting_branch("conflict")
    assert_conflicted_merge_concludes(@repo_dir, "conflict")
    # last, because the squash leaves staged changes behind
    assert_squash_commit_refused("squash")
  end

  def test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_in_a_linked_worktree
    setup_extending_repo("main")
    diverge("merge-a")
    diverge("merge-b")
    conflicting_branch("conflict")
    worktree = add_worktree
    assert_merge_allowed(worktree, "merge-a", "--no-ff", "-m", "merge")
    assert_merge_allowed(worktree, "merge-b", "--no-ff", "-s", "ours", "-m", "merge")
    assert_conflicted_merge_concludes(worktree, "conflict")
  end

  def test_no_verify_lets_an_empty_commit_and_a_no_change_amend_through_on_main_with_the_extending_guard
    setup_extending_repo("main")
    # amend first: git itself refuses to amend an empty commit into another empty one
    _out, err, status = git("commit", "--no-verify", "--amend", "-m", "reworded")
    assert(status.success?, "Expected --no-verify to let a no-change amend through:\n#{err}")
    _out, err, status = git("commit", "--no-verify", "--allow-empty", "-m", "empty")
    assert(status.success?, "Expected --no-verify to let an empty commit through:\n#{err}")
  end

  def test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes
    setup_fallback_repo("main")
    assert_empty_commit_refused
    assert_amend_with_change_refused
    switch_to_feature
    assert_push_refused("origin", "feature:main")
    assert_push_refused("origin", "feature:feature", "HEAD:main")
    publish_branch("main")
    assert_push_refused("origin", "--delete", "main")
    assert_push_allowed("feature:main-fix")
    assert_push_allowed("feature:mainline")
    assert_tag_push_allowed
  end

  def test_the_fallback_config_lets_merges_through_on_main
    setup_fallback_repo("main")
    diverge("merge-a")
    assert_merge_allowed(@repo_dir, "merge-a", "--no-ff", "-m", "merge")
    conflicting_branch("conflict")
    assert_conflicted_merge_concludes(@repo_dir, "conflict")
  end

  def test_a_change_to_the_guard_file_reaches_a_repo_that_extends_it
    setup_extending_repo("main")
    original = File.read(GUARD_FILE)
    guard_copy = File.join(@tmpdir, "guard.yml")
    File.write(guard_copy, original)
    File.write(File.join(@repo_dir, "lefthook-local.yml"), "extends:\n  - #{guard_copy}\n")
    stage_file("change.txt", "change\n")
    out, err, _status = git("commit", "-m", "change")
    assert_match(/Direct commit to main is not allowed/, out + err)
    File.write(guard_copy, original.gsub("is not allowed", "is changed"))
    out, err, _status = git("commit", "-m", "change")
    assert_match(/Direct commit to main is changed/, out + err)
  end

  def test_the_guard_file_defines_only_the_guard_commands
    config = YAML.safe_load_file(GUARD_FILE)
    assert_equal(%w[pre-commit commit-msg pre-push].sort, config.keys.sort)
    config.each_value { |hook| assert_equal(%w[no-push-to-main], hook["commands"].keys) }
  end

  def test_a_lefthook_local_extending_the_guard_lets_the_first_empty_commit_on_an_unborn_main_through
    setup_bare_repo("main")
    File.write(File.join(@repo_dir, "lefthook.yml"), stand_in_config)
    File.write(File.join(@repo_dir, "lefthook-local.yml"), "extends:\n  - #{GUARD_FILE}\n")
    _out, err, status = git("commit", "--allow-empty", "-m", "first")
    assert(status.success?, "Expected the first empty commit on an unborn main to go through:\n#{err}")
  end

  def test_the_fallback_config_duplicates_the_guard_commands_exactly
    fallback = YAML.safe_load_file(File.join(REPO_ROOT, "lefthook.yml"))
    guard = YAML.safe_load_file(GUARD_FILE)
    guard.each do |hook, section|
      assert_equal(section["commands"]["no-push-to-main"], fallback.dig(hook, "commands", "no-push-to-main"), hook)
    end
  end

  private

  def setup_fallback_repo(branch)
    dotfiles = File.join(@tmpdir, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles)
    FileUtils.cp(File.join(REPO_ROOT, "lefthook.yml"), dotfiles)
    stub = File.join(@tmpdir, ".config", "git", "worktree-tools", "review-report-fresh")
    FileUtils.mkdir_p(File.dirname(stub))
    File.write(stub, "#!/bin/sh\nexit 0\n")
    FileUtils.chmod("+x", stub)
    setup_repo(branch)
  end

  def assert_push_refused(*args)
    out, err, status = git("push", *args)
    refute(status.success?, "Expected `git push #{args.join(" ")}` to be refused")
    assert_match(PUSH_REFUSAL, out + err)
  end

  def assert_push_allowed(refspec)
    _out, err, status = git("push", "origin", refspec)
    assert(status.success?, "Expected `git push origin #{refspec}` to go through:\n#{err}")
  end

  def assert_tag_push_allowed
    run_git(@repo_dir, "tag", "v1")
    _out, err, status = git("push", "origin", "v1")
    assert(status.success?, "Expected a tag push to go through:\n#{err}")
  end

  def switch_to_feature
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
  end

  def assert_empty_commit_refused
    out, err, status = git("commit", "--allow-empty", "-m", "empty")
    refute(status.success?, "Expected an empty commit to be refused")
    assert_match(REFUSAL, out + err)
  end

  def assert_amend_with_change_refused
    stage_file("change.txt", "change\n")
    out, err, status = git("commit", "--amend", "--no-edit")
    refute(status.success?, "Expected an amend that stages a change to be refused")
    assert_match(REFUSAL, out + err)
  end

  def assert_amend_without_change_refused
    out, err, status = git("commit", "--amend", "-m", "reworded")
    refute(status.success?, "Expected an amend that stages no change to be refused")
    assert_match(REFUSAL, out + err)
  end

  def assert_squash_commit_refused(branch)
    diverge(branch)
    run_git(@repo_dir, "merge", "--squash", branch)
    out, err, status = git("commit", "-m", "squash")
    refute(status.success?, "Expected a squash commit to be refused")
    assert_match(REFUSAL, out + err)
  end

  def assert_merge_allowed(dir, branch, *options)
    _out, err, status = git("merge", *options, branch, dir: dir)
    assert(status.success?, "Expected a merge commit of #{branch} to go through:\n#{err}")
    assert_two_parents(dir)
  end

  def assert_two_parents(dir)
    assert_equal(2, run_git(dir, "rev-list", "--parents", "-n", "1", "HEAD").split.size - 1)
  end

  def assert_conflicted_merge_concludes(dir, branch)
    File.write(File.join(dir, "shared.txt"), "main\n")
    run_git(dir, "add", "shared.txt")
    run_git(dir, "commit", "-q", "-m", "main side", env: { "LEFTHOOK" => "0" })
    _out, _err, merged = git("merge", branch, dir: dir)
    refute(merged.success?, "Expected the merge to conflict")
    File.write(File.join(dir, "shared.txt"), "resolved\n")
    run_git(dir, "add", "shared.txt")
    _out, err, status = git("commit", "--no-edit", dir: dir)
    assert(status.success?, "Expected concluding the conflicted merge to go through:\n#{err}")
    assert_two_parents(dir)
  end

  def conflicting_branch(name)
    run_git(@repo_dir, "switch", "-q", "-c", name)
    File.write(File.join(@repo_dir, "shared.txt"), "#{name}\n")
    run_git(@repo_dir, "add", "shared.txt")
    run_git(@repo_dir, "commit", "-q", "-m", name, env: { "LEFTHOOK" => "0" })
    run_git(@repo_dir, "switch", "-q", "-")
  end

  def diverge(branch)
    default = run_git(@repo_dir, "rev-parse", "--abbrev-ref", "HEAD").strip
    run_git(@repo_dir, "switch", "-q", "-c", branch)
    commit_file_unguarded("#{branch}.txt", branch)
    run_git(@repo_dir, "switch", "-q", default)
    commit_file_unguarded("trunk-#{branch}.txt", "trunk")
  end

  def commit_file_unguarded(name, message)
    File.write(File.join(@repo_dir, name), "#{message}\n")
    run_git(@repo_dir, "add", name)
    run_git(@repo_dir, "commit", "-q", "-m", message, env: { "LEFTHOOK" => "0" })
  end

  def add_worktree(branch = "main")
    path = File.join(@tmpdir, "linked")
    run_git(@repo_dir, "switch", "-q", "--detach")
    run_git(@repo_dir, "worktree", "add", "-q", path, branch)
    path
  end

  def publish_branch(refspec)
    run_git(@repo_dir, "push", "-q", "origin", refspec, env: { "LEFTHOOK" => "0" })
  end

  def setup_bare_repo(branch)
    run_git(@tmpdir, "init", "--quiet", "--initial-branch=#{branch}", @repo_dir)
    run_git(@repo_dir, "config", "core.hooksPath", @hooks_dir)
    run_git(@repo_dir, "config", "user.name", "Test")
    run_git(@repo_dir, "config", "user.email", "test@example.com")
  end

  def setup_extending_repo(branch)
    setup_repo(branch)
    File.write(File.join(@repo_dir, "lefthook.yml"), stand_in_config)
    File.write(File.join(@repo_dir, "lefthook-local.yml"), "extends:\n  - #{GUARD_FILE}\n")
    commit_unguarded("lefthook.yml", "lefthook-local.yml")
  end

  def stand_in_config
    <<~YAML
      no_auto_install: true
      pre-push:
        commands:
          own-check:
            run: echo own-check >> #{@log_file}
    YAML
  end

  def setup_repo(branch)
    run_git(@tmpdir, "init", "--bare", "--quiet", @origin_dir)
    run_git(@tmpdir, "init", "--quiet", "--initial-branch=#{branch}", @repo_dir)
    run_git(@repo_dir, "config", "core.hooksPath", @hooks_dir)
    run_git(@repo_dir, "config", "user.name", "Test")
    run_git(@repo_dir, "config", "user.email", "test@example.com")
    run_git(@repo_dir, "remote", "add", "origin", @origin_dir)
    File.write(File.join(@repo_dir, "README.md"), "init\n")
    commit_unguarded("README.md")
  end

  def commit_unguarded(*paths)
    run_git(@repo_dir, "add", *paths)
    run_git(@repo_dir, "commit", "-q", "-m", "setup", env: { "LEFTHOOK" => "0" })
  end

  def stage_file(name, content)
    File.write(File.join(@repo_dir, name), content)
    run_git(@repo_dir, "add", name)
  end

  def repo_env
    {
      "HOME" => @tmpdir,
      "PATH" => "/usr/bin:/bin",
      "LEFTHOOK_BIN" => NATIVE_LEFTHOOK,
      "LEFTHOOK" => nil,
      "LEFTHOOK_CONFIG" => nil,
      "LEFTHOOK_EXCLUDE" => nil,
      "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "GIT_AUTHOR_NAME" => "Test",
      "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test",
      "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
  end

  def git(*args, dir: @repo_dir)
    Open3.capture3(repo_env, "git", *args, chdir: dir)
  end

  def run_git(dir, *args, env: {})
    stdout, stderr, status = Open3.capture3(repo_env.merge(env), "git", *args, chdir: dir)
    return stdout if status.success?

    flunk "git #{args.join(" ")} failed (exit #{status.exitstatus}):\n#{stdout}\n#{stderr}"
  end
end
