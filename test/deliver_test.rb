#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "delivery_harness"

# `deliver` ends a change: once a review round leaves no open finding it removes the change folder
# in a commit of its own, pushes the branch and opens (or updates) a draft PR, then asks the herdr
# script for a gh-dash pane. `deliver --check` runs only the preconditions. gh, herdr and the pane
# script are stubs; see delivery_harness.rb for their formats.
#
# Interface these tests pin, beyond the plan: review-report-fresh is found through
# $WORKTREE_TOOLS_DIR; the pane script is $HERDR_SCRIPTS_DIR/open-pr-dash.sh, called as
# `open-pr-dash.sh <slug> <pr-url>`; refusals go to stderr with exit 1; the PR URL goes to stdout.
class DeliverTest < Minitest::Test
  include DeliveryHarness

  SLUG = "my-change".freeze
  OPEN_FINDING = "- [ ] Important: Widget leaks memory — `lib/widget.rb:1` →".freeze
  REMOVAL_SUBJECT = "Remove change artifacts for #{SLUG}".freeze

  def setup
    setup_harness
    @dash_scripts = Dir.mktmpdir
    install_dash_stub
    build_repo
  end

  def teardown
    FileUtils.rm_rf(@dash_scripts)
    teardown_harness
  end

  def test_a_closed_review_ends_in_a_draft_pr_without_the_change_folder
    commit_change_work(template: "## Summary\n\nPlaceholder\n")

    stdout, stderr, status = deliver(herdr: true)

    assert(status.success?, stderr)
    refute(File.exist?(File.join(@repo, "docs/changes", SLUG)))
    assert_equal(REMOVAL_SUBJECT, git("log", "-1", "--format=%s").strip)
    assert_equal(git("rev-parse", "HEAD").strip, git("rev-parse", "origin/#{SLUG}").strip)
    assert_includes(origin_branches, SLUG)
    assert_includes(gh_calls.grep(/\Apr create /).first, "--draft")
    assert_includes(captured("gh-pr-create.body"), "Widgets cannot ship today.")
    assert_includes(stdout, PR_URL)
    assert_equal([ "#{SLUG} #{PR_URL}" ], dash_calls)
  end

  def test_refuses_an_open_finding_and_lists_it
    commit_change_work(findings: [ OPEN_FINDING, "- [ ] Nit: Naming — `lib/widget.rb:1` → fixed (Rename widget)" ])

    assert_refused_and_untouched(/Widget leaks memory/)
  end

  def test_a_finding_closed_as_dismissed_is_not_open
    commit_change_work(findings: [ "- [ ] Important: Widget leaks memory — `lib/widget.rb:1` → dismissed: it is a test double" ])

    _, stderr, status = deliver

    assert(status.success?, stderr)
  end

  def test_refuses_a_stale_review
    commit_change_work
    commit_file("lib/widget.rb", "class Widget; def late; end; end\n", "Change widget after review")

    assert_refused_and_untouched(/review/i)
  end

  def test_refuses_a_missing_review_md
    commit_change_work(findings: nil)

    assert_refused_and_untouched(/review\.md/)
  end

  def test_refuses_a_review_md_with_no_round
    commit_change_work(findings: nil)
    commit_file("docs/changes/#{SLUG}/review.md", "# Review\n", "Empty review")

    assert_refused_and_untouched(/round/i)
  end

  def test_refuses_a_dirty_tree
    commit_change_work
    File.write(File.join(@repo, "scratch.txt"), "unsaved\n")

    assert_refused_and_untouched(/uncommitted|dirty|clean/i)
  end

  def test_refuses_an_unknown_scope
    commit_change_work
    git("remote", "set-url", "origin", "git@github.com:someone-else/dots.git")

    assert_refused_and_untouched(/unknown remote/i)
  end

  def test_check_mode_changes_nothing_and_exits_by_readiness
    commit_change_work
    head = git("rev-parse", "HEAD")

    _, stderr, status = deliver("--check", herdr: true)

    assert(status.success?, stderr)
    assert_equal(head, git("rev-parse", "HEAD"))
    assert(File.exist?(File.join(@repo, "docs/changes", SLUG, "intent.md")))
    assert_empty(origin_branches - [ "main" ])
    assert_empty(gh_calls.grep(/\Apr (create|edit)/))
    assert_empty(herdr_calls)
    assert_empty(dash_calls)
  end

  def test_check_mode_exits_one_with_the_reasons_when_a_finding_is_open
    commit_change_work(findings: [ OPEN_FINDING ])

    _, stderr, status = deliver("--check")

    assert_equal(1, status.exitstatus)
    assert_match(/Widget leaks memory/, stderr)
  end

  def test_stops_when_the_pr_lookup_fails_instead_of_creating_a_pr
    commit_change_work
    stub_response("gh pr list", { "exit" => 1, "stderr" => "gh: network down\n" })

    stdout, stderr, status = deliver

    refute(status.success?)
    assert_match(/network down/, stdout + stderr)
    assert_empty(gh_calls.grep(/\Apr create/))
  end

  def test_looks_the_pr_up_by_head_branch_among_open_prs
    commit_change_work

    deliver

    assert_match(/\Apr list .*--head #{SLUG}\b.*--state open.*--json number,url,isDraft/, gh_calls.grep(/\Apr list/).first)
  end

  def test_fills_the_body_from_the_repository_template
    commit_change_work(template: "## Summary\n\nPlaceholder text\n\n## Checklist\n\n- [ ] Done\n")

    deliver
    body = captured("gh-pr-create.body")

    assert_includes(body, "Widgets ship by themselves.")
    assert_includes(body, "## Checklist")
    refute_includes(body, "Placeholder text")
  end

  def test_fills_the_body_with_no_template
    commit_change_work

    deliver
    body = captured("gh-pr-create.body")

    assert_includes(body, "## Summary")
    assert_includes(body, "## Implementation")
    assert_includes(body, "## Proof")
  end

  def test_titles_the_pr_from_intent_md
    commit_change_work

    deliver

    assert_equal("Ship the widget", captured("gh-pr-create.title"))
  end

  def test_removes_the_folder_in_a_commit_of_its_own
    commit_change_work

    deliver
    files = git("show", "--name-only", "--format=", "HEAD").split

    assert_equal(REMOVAL_SUBJECT, git("log", "-1", "--format=%s").strip)
    assert_equal(%W[docs/changes/#{SLUG}/intent.md docs/changes/#{SLUG}/plan.md docs/changes/#{SLUG}/review.md], files.sort)
    assert_empty(git("status", "--porcelain").strip)
  end

  def test_removes_an_emptied_docs_changes
    commit_change_work

    deliver

    refute(File.exist?(File.join(@repo, "docs/changes")))
  end

  def test_keeps_docs_changes_when_another_change_lives_there
    commit_file("docs/changes/other/intent.md", "# Intent: Other\n", "Add other intent")
    commit_change_work

    deliver

    assert(File.exist?(File.join(@repo, "docs/changes/other/intent.md")))
  end

  def test_edits_the_body_of_an_existing_pr_instead_of_creating_one
    commit_change_work
    existing_pr

    stdout, stderr, status = deliver

    assert(status.success?, stderr)
    assert_empty(gh_calls.grep(/\Apr create/))
    assert_match(/\Apr edit .*--body-file/, gh_calls.grep(/\Apr edit/).first)
    assert_includes(captured("gh-pr-edit.body"), "Widgets cannot ship today.")
    assert_includes(stdout, PR_URL)
  end

  def test_closes_the_idle_and_done_stage_panes_this_change_opened
    commit_change_work
    record_stage_panes(panes_in_play)
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: panes_in_play }) })

    deliver(herdr: true)

    assert_includes(herdr_calls, "pane list --workspace w1")
    assert_equal(%w[w1:pIdle w1:pDone], closed_panes)
    refute(File.exist?(stage_panes_file))
  end

  def test_never_closes_its_own_pane_or_a_working_or_agentless_pane
    commit_change_work
    record_stage_panes(panes_in_play)
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: panes_in_play }) })

    deliver(herdr: true)

    %W[#{OWN_PANE} w1:pWorking w1:pShell].each { |pane| refute_includes(closed_panes, pane) }
  end

  def test_leaves_an_unrelated_idle_agent_in_the_worktree_open
    commit_change_work
    record_stage_panes([ pane("w1:pIdle", "claude", "idle") ])
    unrelated = pane("w1:pOther", "codex", "idle")
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: [ pane("w1:pIdle", "claude", "idle"), unrelated ] }) })

    deliver(herdr: true)

    assert_equal(%w[w1:pIdle], closed_panes)
  end

  def test_never_closes_the_intent_pane
    commit_change_work
    intent = pane("w1:pIntent", "claude", "idle")
    record_stage_panes([ intent, pane("w1:pIdle", "claude", "idle") ])
    record_intent_pane(intent)
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: [ intent, pane("w1:pIdle", "claude", "idle") ] }) })

    deliver(herdr: true)

    assert_equal(%w[w1:pIdle], closed_panes)
  end

  def test_leaves_a_recorded_pane_id_that_another_terminal_reuses
    commit_change_work
    record_stage_panes([ pane("w1:pIdle", "claude", "idle") ])
    reused = pane("w1:pIdle", "claude", "idle").merge(terminal_id: "term_later")
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: [ reused ] }) })

    deliver(herdr: true)

    assert_empty(closed_panes)
  end

  def test_a_failed_pane_list_after_the_pr_exists_only_warns
    commit_change_work
    record_stage_panes([ pane("w1:pIdle", "claude", "idle") ])
    stub_response("herdr pane list", { "exit" => 1, "stderr" => "herdr: server not responding\n" })

    stdout, stderr, status = deliver(herdr: true)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_match(/server not responding/, stderr)
    assert_empty(closed_panes)
  end

  def test_lists_panes_without_a_workspace_when_herdr_names_none
    commit_change_work
    record_stage_panes([ pane("w1:pIdle", "claude", "idle") ])
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: [ pane("w1:pIdle", "claude", "idle") ] }) })

    _, stderr, status = deliver(herdr: true, env: { "HERDR_WORKSPACE_ID" => nil })

    assert(status.success?, stderr)
    assert_includes(herdr_calls, "pane list")
    assert_equal(%w[w1:pIdle], closed_panes)
  end

  def test_resumes_after_a_failed_push_without_the_folder
    commit_change_work
    git("remote", "set-url", "--push", "origin", File.join(@origin, "does-not-exist"))

    _, _, first = deliver
    refute(first.success?)
    assert_empty(gh_calls.grep(/\Apr create/))
    assert(File.exist?(File.join(common_dir, "deliver", "#{SLUG}.body.md")))
    assert(File.exist?(File.join(common_dir, "deliver", "#{SLUG}.title")))

    git("remote", "set-url", "--push", "origin", @origin)
    _, stderr, second = deliver

    assert(second.success?, stderr)
    assert_equal(1, git("log", "--format=%s", "--grep", REMOVAL_SUBJECT).lines.size)
    assert_includes(origin_branches, SLUG)
    assert_includes(captured("gh-pr-create.body"), "Widgets cannot ship today.")
    assert_equal("Ship the widget", captured("gh-pr-create.title"))
  end

  def test_deletes_the_saved_body_once_the_pr_exists
    commit_change_work

    deliver

    assert_empty(Dir.glob(File.join(common_dir, "deliver", "#{SLUG}.{body.md,title}")))
  end

  def test_outside_herdr_prints_the_pr_url_and_opens_no_pane
    commit_change_work

    stdout, stderr, status = deliver(scripts: HERDR_SCRIPTS)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_equal(1, gh_calls.count { |call| call.start_with?("pr create ") })
    assert_empty(herdr_calls)
  end

  private

  def deliver(*arguments, herdr: false, scripts: @dash_scripts, env: {})
    run_script(DELIVER, *arguments, herdr: herdr, env: { "HERDR_SCRIPTS_DIR" => scripts, "DASH_LOG" => dash_log }.merge(env))
  end

  def assert_refused_and_untouched(reason)
    head = git("rev-parse", "HEAD")

    stdout, stderr, status = deliver

    assert_equal(1, status.exitstatus, stdout + stderr)
    assert_match(reason, stderr)
    assert_equal(head, git("rev-parse", "HEAD"))
    assert(File.exist?(File.join(@repo, "docs/changes", SLUG, "intent.md")))
    assert_empty(origin_branches - [ "main" ])
    assert_empty(gh_calls.grep(/\Apr (create|edit)/))
  end

  def panes_in_play
    [
      pane("w1:pIdle", "claude", "idle"), pane("w1:pDone", "claude", "done"),
      pane(OWN_PANE, "claude", "idle"), pane("w1:pWorking", "claude", "working"),
      pane("w1:pShell", nil, "unknown")
    ]
  end

  def pane(id, agent, status)
    { pane_id: id, terminal_id: "term_#{id}", workspace_id: "w1", cwd: toplevel, agent: agent, agent_status: status }
  end

  # What hand-off-plan.sh and start-review.sh record: one "<pane_id> <terminal_id>" line per pane.
  def record_stage_panes(panes)
    FileUtils.mkdir_p(File.dirname(stage_panes_file))
    File.write(stage_panes_file, panes.map { |entry| "#{entry[:pane_id]} #{entry[:terminal_id]}\n" }.join)
  end

  # What the intent skill records: the pane id, then the terminal id, one per line.
  def record_intent_pane(entry)
    File.write(File.join(common_dir, "herdr", "intent-pane-#{SLUG}"), "#{entry[:pane_id]}\n#{entry[:terminal_id]}\n")
  end

  def stage_panes_file
    File.join(common_dir, "herdr", "stage-panes-#{SLUG}")
  end

  def closed_panes
    herdr_calls.grep(/\Apane close/).map { |call| call.split.last }
  end

  def dash_log
    File.join(@state, "dash.log")
  end

  def dash_calls
    File.exist?(dash_log) ? File.readlines(dash_log, chomp: true) : []
  end

  def install_dash_stub
    path = File.join(@dash_scripts, "open-pr-dash.sh")
    File.write(path, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$DASH_LOG\"\n")
    FileUtils.chmod(0o755, path)
  end
end
