#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"
require_relative "delivery_harness"

# `restore` brings back a change folder that `deliver` removed, for a change request on an open pull
# request: it fetches, fast-forwards, drops the removal commit with a rebase and prints the
# force-with-lease push for the caller to run. gh is a stub; fetch and push reach the bare origin.
class RestoreTest < Minitest::Test
  include DeliveryHarness

  SLUG = "my-change".freeze
  RESTORE = File.join(DeliveryHarness::REPO_ROOT, "agents/.agents/skills/deliver/scripts/restore")
  REMOVAL_SUBJECT = "Remove change artifacts for #{SLUG}".freeze
  FOLDER = "docs/changes/#{SLUG}".freeze
  PUSH = "git push --force-with-lease -u origin HEAD".freeze

  def setup
    setup_harness
    build_repo
    git("config", "url.#{@origin}.insteadOf", PERSONAL_URL)
    commit_change_work
    existing_pr
  end

  def teardown
    teardown_harness
  end

  def test_a_change_request_gets_the_deleted_documents_back
    deliver_by_hand

    _, stderr, status = run_script(RESTORE)

    assert(status.success?, stderr)
    %w[intent.md plan.md review.md].each { |name| assert(File.exist?(File.join(@repo, FOLDER, name)), name) }
    refute_includes(git("log", "--format=%s").lines.map(&:strip), REMOVAL_SUBJECT)
  end

  def test_restore_prints_a_force_with_lease_push
    deliver_by_hand

    stdout, stderr, status = run_script(RESTORE)

    assert(status.success?, stderr)
    assert_includes(stdout, PUSH)
  end

  def test_pulls_the_remote_branch_before_rebasing
    deliver_by_hand
    push_from_another_clone("remote.txt")

    _, stderr, status = run_script(RESTORE)

    assert(status.success?, stderr)
    assert(File.exist?(File.join(@repo, "remote.txt")))
  end

  def test_refuses_a_diverged_branch
    deliver_by_hand
    push_from_another_clone("remote.txt")
    commit_file("local.txt", "x\n", "Local only")

    assert_refused(/diverge|fast-forward/i)
  end

  def test_refuses_a_dirty_tree
    deliver_by_hand
    File.write(File.join(@repo, "scratch.txt"), "x\n")

    assert_refused(/uncommitted/)
  end

  def test_refuses_a_branch_without_a_removal_commit
    git("push", "--quiet", "origin", @branch)

    assert_refused(/removal commit|#{REMOVAL_SUBJECT}/)
  end

  def test_refuses_a_removal_commit_that_touches_other_paths
    git("rm", "--quiet", "-r", FOLDER, "README.md")
    git("commit", "--quiet", "-m", REMOVAL_SUBJECT)
    git("push", "--quiet", "origin", @branch)

    assert_refused(/other paths|only/)
  end

  def test_refuses_a_removal_commit_that_deletes_only_part_of_the_folder
    git("rm", "--quiet", "#{FOLDER}/intent.md", "#{FOLDER}/plan.md")
    git("commit", "--quiet", "-m", REMOVAL_SUBJECT)
    git("push", "--quiet", "origin", @branch)

    assert_refused(/whole folder|still/)
  end

  def test_refuses_a_branch_without_an_open_pull_request
    deliver_by_hand
    stub_response("gh pr list", { "stdout" => "[]" })

    assert_refused(/open pull request/)
  end

  def test_refuses_when_gh_cannot_tell
    deliver_by_hand
    stub_response("gh pr list", { "stderr" => "boom", "exit" => 1 })

    assert_refused(/boom|pull request/)
  end

  def test_a_fetch_failure_is_not_reported_as_divergence
    git("rm", "--quiet", "-r", FOLDER)
    git("commit", "--quiet", "-m", REMOVAL_SUBJECT)

    _, stderr, status = run_script(RESTORE)

    assert_equal(1, status.exitstatus, stderr)
    assert_match(/fetch/, stderr)
    refute_match(/diverge/, stderr)
  end

  def test_refuses_when_no_base_branch_resolves
    deliver_by_hand
    git("branch", "--move", "main", "trunk")

    assert_refused(/base branch/)
  end

  def test_keeps_commits_made_after_delivery
    deliver_by_hand
    commit_file("after.txt", "x\n", "After delivery")
    git("push", "--quiet", "origin", @branch)

    _, stderr, status = run_script(RESTORE)

    assert(status.success?, stderr)
    assert_equal("After delivery", git("log", "-1", "--format=%s").strip)
    assert(File.exist?(File.join(@repo, FOLDER, "review.md")))
  end

  def test_aborts_a_conflicting_rebase
    deliver_by_hand
    commit_file("#{FOLDER}/review.md", "something else\n", "Recreate review")
    git("push", "--quiet", "origin", @branch)
    head = git("rev-parse", "HEAD")

    assert_refused(/conflict/i)
    assert_equal(head, git("rev-parse", "HEAD"))
    assert_equal("", git("status", "--porcelain"))
  end

  private

  def deliver_by_hand
    git("rm", "--quiet", "-r", FOLDER)
    git("commit", "--quiet", "-m", REMOVAL_SUBJECT)
    git("push", "--quiet", "origin", @branch)
  end

  def assert_refused(message)
    head = git("rev-parse", "HEAD")
    _, stderr, status = run_script(RESTORE)

    assert_equal(1, status.exitstatus, stderr)
    assert_match(message, stderr)
    assert_equal(head, git("rev-parse", "HEAD"))
  end

  def push_from_another_clone(file)
    Dir.mktmpdir do |clone|
      system("git", "clone", "--quiet", "--branch", @branch, @origin, clone) || raise("clone failed")
      File.write(File.join(clone, file), "x\n")
      [ %w[add .], %w[-c user.name=T -c user.email=t@example.com -c commit.gpgsign=false commit --quiet -m Remote],
        %w[push --quiet origin HEAD] ].each { |args| system("git", "-C", clone, *args) || raise("#{args} failed") }
    end
  end
end
