#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "delivery_harness"
require_relative "isolated_git"

# `ship` is the second half of delivery: mark the draft PR ready, wait for CI, and (without
# --no-merge) merge it with a merge commit and delete the remote branch. gh is a stub; see
# delivery_harness.rb for its response format.
#
# Interface these tests pin, beyond the plan: SHIP_POLL_INTERVAL (seconds, default 10) is the wait
# between retries of "no checks reported" and between polls of the merged state; messages may go to
# stdout or stderr; with SHIP_MERGE_WAIT=0 ship still reads the PR state once before giving up.
class ShipTest < Minitest::Test
  include DeliveryHarness

  FAILING_CHECKS = [
    { name: "lint", bucket: "pass", link: "https://ci.example/run/1" },
    { name: "rspec", bucket: "fail", link: "https://ci.example/run/9" },
    { name: "deploy-preview", bucket: "cancel", link: "https://ci.example/run/10" }
  ].freeze
  PASSING_CHECKS = [ { name: "lint", bucket: "pass", link: "https://ci.example/run/1" } ].freeze
  PENDING_CHECKS = [ { name: "build", bucket: "pending", link: "https://ci.example/run/4" } ].freeze

  def setup
    setup_harness
    build_repo
    git("push", "--quiet", "origin", @branch)
    existing_pr
    stub_response("gh pr checks watch", { "stdout" => "All checks were successful\n" })
    stub_response("gh pr checks json", { "stdout" => JSON.generate(PASSING_CHECKS) })
    stub_response("gh pr view", { "stdout" => '{"state":"MERGED"}' })
  end

  def teardown
    teardown_harness
  end

  def test_refuses_a_branch_without_a_pr
    stub_response("gh pr list", { "stdout" => "[]" })

    stdout, stderr, status = ship

    assert_equal(1, status.exitstatus)
    assert_includes(stdout + stderr, "No pull request for this branch: the delivery step has not run.")
    assert_empty(gh_calls.grep(/\Apr (ready|merge|checks)/))
  end

  def test_stops_when_the_pr_lookup_fails
    stub_response("gh pr list", { "exit" => 1, "stderr" => "gh: network down\n" })

    stdout, stderr, status = ship

    refute(status.success?)
    assert_match(/network down/, stdout + stderr)
    assert_empty(gh_calls.grep(/\Apr (ready|merge|checks|create)/))
  end

  def test_looks_the_pr_up_by_head_branch_among_open_prs
    ship

    assert_match(/\Apr list .*--head #{@branch}\b.*--state open.*--json number,url,isDraft/, gh_calls.grep(/\Apr list/).first)
  end

  def test_marks_a_draft_ready
    ship

    assert_includes(gh_calls, "pr ready 7")
  end

  def test_leaves_a_ready_pr_alone
    existing_pr(draft: false)

    ship

    assert_empty(gh_calls.grep(/\Apr ready/))
  end

  def test_ships_a_green_pr_with_a_merge_commit_and_deletes_the_remote_branch
    stdout, stderr, status = ship

    assert(status.success?, stdout + stderr)
    assert_equal(%w[ready watch checks merge view], call_order)
    assert_includes(gh_calls, "pr merge 7 --merge")
    assert_includes(gh_calls, "pr checks 7 --watch --fail-fast")
    assert_includes(gh_calls, "pr checks 7 --json name,bucket,link")
    assert_empty(gh_calls.grep(/delete-branch/))
    refute_includes(origin_branches, @branch)
  end

  def test_a_failed_check_stops_unmerged_and_names_the_check_and_link
    stub_response("gh pr checks watch", { "exit" => 1, "stdout" => "Some checks were not successful\n" })
    stub_response("gh pr checks json", { "stdout" => JSON.generate(FAILING_CHECKS) })

    stdout, stderr, status = ship
    output = stdout + stderr

    assert_equal(1, status.exitstatus)
    assert_includes(output, "rspec: https://ci.example/run/9")
    assert_includes(output, "deploy-preview: https://ci.example/run/10")
    refute_includes(output, "lint:")
    assert_empty(gh_calls.grep(/\Apr merge/))
    assert_includes(origin_branches, @branch)
  end

  def test_a_failed_check_beside_a_pending_one_reports_the_failure_first
    stub_response("gh pr checks watch", { "exit" => 1, "stdout" => "rspec\tfail\nbuild\tpending\n" })
    stub_response("gh pr checks json", { "stdout" => JSON.generate(FAILING_CHECKS + PENDING_CHECKS) })

    stdout, stderr, status = ship("--no-merge")
    lines = (stdout + stderr).lines.map(&:strip)

    assert_equal(1, status.exitstatus)
    assert_match(/fail/i, lines.first)
    refute(lines.any? { |line| line.include?("not finished") }, lines.join("\n"))
    assert_operator(lines.index("rspec: https://ci.example/run/9"), :<, lines.index("build: https://ci.example/run/4"))
    assert_operator(lines.index("deploy-preview: https://ci.example/run/10"), :<, lines.index("build: https://ci.example/run/4"))
    pending_note = lines.index { |line| line.match?(/pending/i) && !line.include?("\t") }
    assert_operator(pending_note, :<, lines.index("build: https://ci.example/run/4"))
  end

  def test_no_merge_marks_ready_waits_for_green_and_leaves_the_pr_open
    stdout, stderr, status = ship("--no-merge")

    assert(status.success?, stdout + stderr)
    assert_includes(stdout, "CI green; PR left unmerged.")
    assert_equal(%w[ready watch checks], call_order)
    assert_empty(gh_calls.grep(/\Apr merge/))
    assert_includes(origin_branches, @branch)
  end

  def test_a_failed_watch_with_pending_checks_stops_unmerged
    stub_response("gh pr checks watch", { "exit" => 1, "stderr" => "HTTP 502: Bad Gateway\n" })
    stub_response("gh pr checks json", { "stdout" => JSON.generate(PASSING_CHECKS + PENDING_CHECKS) })

    stdout, stderr, status = ship
    output = stdout + stderr

    assert_equal(1, status.exitstatus)
    assert_includes(output, "build: https://ci.example/run/4")
    assert_includes(output, "HTTP 502: Bad Gateway")
    assert_empty(gh_calls.grep(/\Apr merge/))
    assert_includes(origin_branches, @branch)
  end

  def test_no_merge_does_not_report_green_while_checks_are_pending
    stub_response("gh pr checks watch", { "exit" => 1, "stderr" => "HTTP 401: Bad credentials\n" })
    stub_response("gh pr checks json", { "stdout" => JSON.generate(PENDING_CHECKS) })

    stdout, stderr, status = ship("--no-merge")

    assert_equal(1, status.exitstatus)
    refute_includes(stdout, "CI green")
    assert_includes(stdout + stderr, "build: https://ci.example/run/4")
  end

  def test_a_failed_watch_stops_unmerged_when_the_checks_cannot_be_read
    stub_response("gh pr checks watch", { "exit" => 1, "stderr" => "HTTP 502: Bad Gateway\n" })
    stub_response("gh pr checks json", { "exit" => 1, "stderr" => "error connecting to api.github.com\n" })

    stdout, stderr, status = ship
    output = stdout + stderr

    assert_equal(1, status.exitstatus)
    assert_includes(output, "error connecting to api.github.com")
    assert_includes(output, "PR left unmerged")
    assert_empty(gh_calls.grep(/\Apr merge/))
  end

  def test_skipped_checks_count_as_green
    skipped = [ { name: "deploy", bucket: "skipping", link: "https://ci.example/run/5" } ]
    stub_response("gh pr checks json", { "stdout" => JSON.generate(PASSING_CHECKS + skipped) })

    stdout, stderr, status = ship

    assert(status.success?, stdout + stderr)
    assert_includes(gh_calls, "pr merge 7 --merge")
  end

  def test_retries_while_no_checks_are_reported
    no_checks = { "exit" => 1, "stderr" => "no checks reported on the '#{@branch}' branch\n" }
    stub_response("gh pr checks watch", no_checks, no_checks, { "stdout" => "All checks were successful\n" })

    stdout, stderr, status = ship(env: { "SHIP_CHECKS_GRACE" => "60" })

    assert(status.success?, stdout + stderr)
    assert_equal(3, gh_calls.count { |call| call.include?("--watch") })
    assert_includes(gh_calls, "pr merge 7 --merge")
  end

  def test_stops_unmerged_when_no_checks_appear_in_the_grace_period
    stub_response("gh pr checks watch", { "exit" => 1, "stderr" => "no checks reported on the '#{@branch}' branch\n" })

    stdout, stderr, status = ship(env: { "SHIP_CHECKS_GRACE" => "0" })

    assert_equal(1, status.exitstatus)
    assert_includes(stdout + stderr, "no CI checks reported; merge by hand if that is expected.")
    assert_empty(gh_calls.grep(/\Apr merge/))
    assert_includes(origin_branches, @branch)
  end

  def test_trusts_the_merged_state_over_the_merge_exit_code
    stub_response("gh pr merge", { "exit" => 1, "stderr" => "failed to run git: 'main' is already used by worktree\n" })

    stdout, stderr, status = ship

    assert(status.success?, stdout + stderr)
    refute_includes(origin_branches, @branch)
  end

  def test_a_refused_merge_stops_at_once_with_the_reason_from_gh
    stub_response("gh pr merge", { "exit" => 1, "stderr" => "Pull request is not mergeable: the base branch policy prohibits the merge\n" })
    stub_response("gh pr view", { "stdout" => '{"state":"OPEN","autoMergeRequest":null}' })

    stdout, stderr, status = ship(env: { "SHIP_MERGE_WAIT" => "60" })

    assert_equal(1, status.exitstatus)
    assert_includes(stdout + stderr, "the base branch policy prohibits the merge")
    assert_equal(1, gh_calls.count { |call| call.start_with?("pr view") })
    assert_includes(origin_branches, @branch)
  end

  def test_a_failed_merge_call_still_waits_for_a_queued_merge
    stub_response("gh pr merge", { "exit" => 1, "stderr" => "merge queue: request timed out\n" })
    queued = { "stdout" => '{"state":"OPEN","autoMergeRequest":{"mergeMethod":"MERGE"}}' }
    stub_response("gh pr view", queued, queued, { "stdout" => '{"state":"MERGED","autoMergeRequest":null}' })

    stdout, stderr, status = ship(env: { "SHIP_MERGE_WAIT" => "60" })

    assert(status.success?, stdout + stderr)
    assert_equal(3, gh_calls.count { |call| call.start_with?("pr view") })
    refute_includes(origin_branches, @branch)
  end

  def test_waits_for_a_queued_merge_before_deleting_the_branch
    stub_response("gh pr view", { "stdout" => '{"state":"OPEN"}' }, { "stdout" => '{"state":"OPEN"}' },
                  { "stdout" => '{"state":"MERGED"}' })

    stdout, stderr, status = ship(env: { "SHIP_MERGE_WAIT" => "60" })

    assert(status.success?, stdout + stderr)
    assert_equal(3, gh_calls.count { |call| call.start_with?("pr view") })
    refute_includes(origin_branches, @branch)
  end

  def test_keeps_the_branch_when_the_merge_does_not_land_in_time
    stub_response("gh pr view", { "stdout" => '{"state":"OPEN"}' })

    stdout, stderr, status = ship(env: { "SHIP_MERGE_WAIT" => "0" })

    assert_equal(1, status.exitstatus)
    assert_includes(stdout + stderr, "OPEN")
    assert_includes(origin_branches, @branch)
  end

  def test_ignores_a_remote_branch_already_deleted
    system("git", "--git-dir", @origin, "branch", "--quiet", "-D", @branch) || raise("branch delete failed")

    stdout, stderr, status = ship

    assert(status.success?, stdout + stderr)
  end

  private

  def ship(*arguments, env: {})
    run_script(SHIP, *arguments, env: { "SHIP_CHECKS_GRACE" => "0", "SHIP_MERGE_WAIT" => "0", "SHIP_POLL_INTERVAL" => "0" }.merge(env))
  end

  def call_order
    gh_calls.filter_map do |call|
      case call
      when /\Apr ready/ then "ready"
      when /\Apr checks .*--watch/ then "watch"
      when /\Apr checks .*--json/ then "checks"
      when /\Apr merge/ then "merge"
      when /\Apr view/ then "view"
      end
    end.chunk_while { |first, second| first == second }.map(&:first)
  end
end
