#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "yaml"
require "tmpdir"
require_relative "lefthook_binary"

class BranchGuardTest < Minitest::Test
  NATIVE_LEFTHOOK = LefthookBinary.locate
  REPO_ROOT = File.expand_path("..", __dir__)
  GUARD_FILE = File.join(REPO_ROOT, "lefthook-branch-guard.yml")
  REFUSAL = /Direct commit to (main|master) is not allowed/

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK

    @tmpdir = Dir.mktmpdir
    @repo_dir = File.join(@tmpdir, "repo")
    @origin_dir = File.join(@tmpdir, "origin.git")
    @hooks_dir = File.join(@tmpdir, "hooks")
    @log_file = File.join(@tmpdir, "pre-push.log")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_commit_on_main
    setup_extending_repo("main")
    stage_file("change.txt", "change\n")
    out, err, status = git("commit", "-m", "change")
    refute(status.success?, "Expected a commit on main to be refused")
    assert_match(REFUSAL, out + err)
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_commit_on_master
    setup_extending_repo("master")
    stage_file("change.txt", "change\n")
    out, err, status = git("commit", "-m", "change")
    refute(status.success?, "Expected a commit on master to be refused")
    assert_match(REFUSAL, out + err)
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_on_main
    setup_extending_repo("main")
    assert_push_refused("origin", "main")
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_on_master
    setup_extending_repo("master")
    assert_push_refused("origin", "master")
  end

  def test_a_lefthook_local_extending_the_guard_allows_a_feature_branch_commit_and_push
    setup_extending_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    stage_file("change.txt", "change\n")
    _out, err, status = git("commit", "-m", "change")
    assert(status.success?, "Expected a feature branch commit to go through:\n#{err}")
    _out, err, status = git("push", "origin", "feature:feature")
    assert(status.success?, "Expected a same-name push to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_keeps_the_extending_repos_own_pre_push_commands
    setup_extending_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    git("push", "origin", "feature:feature")
    assert_equal("own-check\n", File.read(@log_file))
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

  def test_a_lefthook_local_extending_the_guard_refuses_an_empty_commit_on_main
    setup_extending_repo("main")
    assert_empty_commit_refused
  end

  def test_a_lefthook_local_extending_the_guard_refuses_an_empty_commit_on_master
    setup_extending_repo("master")
    assert_empty_commit_refused
  end

  def test_a_lefthook_local_extending_the_guard_allows_an_empty_commit_on_a_feature_branch
    setup_extending_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    _out, err, status = git("commit", "--allow-empty", "-m", "empty")
    assert(status.success?, "Expected an empty commit on a feature branch to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_lets_the_first_empty_commit_on_an_unborn_main_through
    setup_bare_repo("main")
    File.write(File.join(@repo_dir, "lefthook.yml"), stand_in_config)
    File.write(File.join(@repo_dir, "lefthook-local.yml"), "extends:\n  - #{GUARD_FILE}\n")
    _out, err, status = git("commit", "--allow-empty", "-m", "first")
    assert(status.success?, "Expected the first empty commit on an unborn main to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main
    setup_extending_repo("main")
    diverge
    _out, err, status = git("merge", "--no-ff", "-m", "merge", "feature")
    assert(status.success?, "Expected a merge commit on main to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_master
    setup_extending_repo("master")
    diverge
    _out, err, status = git("merge", "--no-ff", "-m", "merge", "feature")
    assert(status.success?, "Expected a merge commit on master to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main_that_changes_no_files
    setup_extending_repo("main")
    diverge
    _out, err, status = git("merge", "--no-ff", "-s", "ours", "-m", "merge", "feature")
    assert(status.success?, "Expected a no-change merge commit on main to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main_in_a_linked_worktree
    setup_extending_repo("main")
    diverge
    worktree = add_worktree
    _out, err, status = git("merge", "--no-ff", "-m", "merge", "feature", dir: worktree)
    assert(status.success?, "Expected a merge commit on main in a linked worktree to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main_in_a_linked_worktree_that_changes_no_files
    setup_extending_repo("main")
    diverge
    worktree = add_worktree
    _out, err, status = git("merge", "--no-ff", "-s", "ours", "-m", "merge", "feature", dir: worktree)
    assert(status.success?, "Expected a no-change merge commit in a linked worktree to go through:\n#{err}")
  end

  def test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_main
    setup_extending_repo("main")
    assert_conflicted_merge_concludes(:main_checkout)
  end

  def test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_master
    setup_extending_repo("master")
    assert_conflicted_merge_concludes(:main_checkout)
  end

  def test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_main_in_a_linked_worktree
    setup_extending_repo("main")
    assert_conflicted_merge_concludes(:linked)
  end

  def test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_master_in_a_linked_worktree
    setup_extending_repo("master")
    assert_conflicted_merge_concludes(:linked)
  end

  def test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_a_change_on_main
    setup_extending_repo("main")
    assert_amend_with_change_refused
  end

  def test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_a_change_on_master
    setup_extending_repo("master")
    assert_amend_with_change_refused
  end

  def test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_no_change_on_main
    setup_extending_repo("main")
    assert_amend_without_change_refused
  end

  def test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_no_change_on_master
    setup_extending_repo("master")
    assert_amend_without_change_refused
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_squash_merge_commit_on_main
    setup_extending_repo("main")
    assert_squash_commit_refused
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_squash_merge_commit_on_master
    setup_extending_repo("master")
    assert_squash_commit_refused
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_of_a_feature_branch_to_main
    setup_extending_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "feature:main")
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_of_a_feature_branch_to_master
    setup_extending_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "feature:master")
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_of_head_to_main
    setup_extending_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "HEAD:main")
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_deleting_main
    setup_extending_repo("main")
    publish_branch("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "--delete", "main")
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_deleting_master
    setup_extending_repo("main")
    publish_branch("main:master")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "--delete", "master")
  end

  def test_a_lefthook_local_extending_the_guard_refuses_a_push_that_updates_main_among_other_refs
    setup_extending_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "feature:feature", "HEAD:main")
  end

  def test_the_fallback_config_duplicates_the_guard_commands_exactly
    fallback = YAML.safe_load_file(File.join(REPO_ROOT, "lefthook.yml"))
    guard = YAML.safe_load_file(GUARD_FILE)
    guard.each do |hook, section|
      assert_equal(section["commands"]["no-push-to-main"], fallback.dig(hook, "commands", "no-push-to-main"), hook)
    end
  end

  def test_the_fallback_config_refuses_an_empty_commit_on_main
    setup_fallback_repo("main")
    assert_empty_commit_refused
  end

  def test_the_fallback_config_refuses_an_empty_commit_on_master
    setup_fallback_repo("master")
    assert_empty_commit_refused
  end

  def test_the_fallback_config_allows_a_merge_commit_on_main
    setup_fallback_repo("main")
    diverge
    _out, err, status = git("merge", "--no-ff", "-m", "merge", "feature")
    assert(status.success?, "Expected a merge commit on main to go through:\n#{err}")
  end

  def test_the_fallback_config_allows_concluding_a_conflicted_merge_on_main
    setup_fallback_repo("main")
    assert_conflicted_merge_concludes(:main_checkout)
  end

  def test_the_fallback_config_refuses_an_amend_that_stages_a_change_on_main
    setup_fallback_repo("main")
    assert_amend_with_change_refused
  end

  def test_the_fallback_config_refuses_a_push_of_a_feature_branch_to_main
    setup_fallback_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "feature:main")
  end

  def test_the_fallback_config_refuses_a_push_of_a_feature_branch_to_master
    setup_fallback_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "feature:master")
  end

  def test_the_fallback_config_refuses_a_push_deleting_main
    setup_fallback_repo("main")
    publish_branch("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "--delete", "main")
  end

  def test_the_fallback_config_refuses_a_push_deleting_master
    setup_fallback_repo("main")
    publish_branch("main:master")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "--delete", "master")
  end

  def test_the_fallback_config_refuses_a_push_that_updates_main_among_other_refs
    setup_fallback_repo("main")
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    assert_push_refused("origin", "feature:feature", "HEAD:main")
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
    assert_match(/Pushing to (main|master) is not allowed|Direct push to (main|master) is not allowed/, out + err)
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

  def assert_squash_commit_refused
    diverge
    run_git(@repo_dir, "merge", "--squash", "feature")
    out, err, status = git("commit", "-m", "squash")
    refute(status.success?, "Expected a squash commit to be refused")
    assert_match(REFUSAL, out + err)
  end

  def assert_conflicted_merge_concludes(where)
    default = run_git(@repo_dir, "rev-parse", "--abbrev-ref", "HEAD").strip
    conflicting_branch("feature")
    dir = where == :linked ? add_worktree(default) : @repo_dir
    File.write(File.join(dir, "shared.txt"), "main\n")
    run_git(dir, "add", "shared.txt")
    run_git(dir, "commit", "-q", "-m", "main side", env: { "LEFTHOOK" => "0" })
    _out, _err, merged = git("merge", "feature", dir: dir)
    refute(merged.success?, "Expected the merge to conflict")
    File.write(File.join(dir, "shared.txt"), "resolved\n")
    run_git(dir, "add", "shared.txt")
    _out, err, status = git("commit", "--no-edit", dir: dir)
    assert(status.success?, "Expected concluding the conflicted merge to go through:\n#{err}")
    assert_equal(2, run_git(dir, "rev-list", "--parents", "-n", "1", "HEAD").split.size - 1)
  end

  def conflicting_branch(name)
    run_git(@repo_dir, "switch", "-q", "-c", name)
    File.write(File.join(@repo_dir, "shared.txt"), "#{name}\n")
    run_git(@repo_dir, "add", "shared.txt")
    run_git(@repo_dir, "commit", "-q", "-m", name, env: { "LEFTHOOK" => "0" })
    run_git(@repo_dir, "switch", "-q", "-")
  end

  def diverge
    default = run_git(@repo_dir, "rev-parse", "--abbrev-ref", "HEAD").strip
    run_git(@repo_dir, "switch", "-q", "-c", "feature")
    File.write(File.join(@repo_dir, "feature.txt"), "feature\n")
    run_git(@repo_dir, "add", "feature.txt")
    run_git(@repo_dir, "commit", "-q", "-m", "feature", env: { "LEFTHOOK" => "0" })
    run_git(@repo_dir, "switch", "-q", default)
    File.write(File.join(@repo_dir, "trunk.txt"), "trunk\n")
    run_git(@repo_dir, "add", "trunk.txt")
    run_git(@repo_dir, "commit", "-q", "-m", "trunk", env: { "LEFTHOOK" => "0" })
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
    FileUtils.cp_r(File.join(REPO_ROOT, "git/.config/git/hooks"), @hooks_dir)
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
    FileUtils.cp_r(File.join(REPO_ROOT, "git/.config/git/hooks"), @hooks_dir)
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
