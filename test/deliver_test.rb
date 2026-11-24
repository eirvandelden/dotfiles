#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "delivery_harness"
require_relative "rex_harness_compat"
require_relative "herdr_app_harness"
require_relative "isolated_git"

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
  include HerdrAppHarness

  SLUG = "my-change".freeze
  OPEN_FINDING = "- [ ] Important: Widget leaks memory — `lib/widget.rb:1` →".freeze
  REMOVAL_SUBJECT = "Remove change artifacts for #{SLUG}".freeze

  def setup
    setup_harness
    @dash_scripts = Dir.mktmpdir
    install_dash_stub
    install_dispatchers
    build_repo
  end

  def teardown
    FileUtils.rm_rf(@dash_scripts)
    herdr_app_teardown
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

  def test_a_finding_without_a_valid_close_marker_is_open
    markers = [ "still investigating", "fixed", "fixed in abc1234: rename", "fixed ()", "dismissed:", "dismissed" ]
    commit_change_work(findings: markers.map { |marker| "- [ ] Nit: Case #{marker.inspect} — `lib/widget.rb:1` → #{marker}" })

    _, stderr, status = deliver("--check")

    assert_equal(1, status.exitstatus)
    markers.each { |marker| assert_includes(stderr, "Case #{marker.inspect}") }
  end

  def test_on_a_work_repository_a_closed_review_ends_in_a_draft_pr_without_artefact_commits
    work_change

    stdout, stderr, status = deliver

    assert(status.success?, stderr)
    assert_empty(git("log", "--format=%H", "--", "docs/changes").strip)
    assert(File.exist?(File.join(@repo, "docs/changes", SLUG, "review.md")))
    assert_equal("Add widget", git("log", "-1", "--format=%s").strip)
    assert_includes(origin_branches, SLUG)
    assert_includes(gh_calls.grep(/\Apr create /).first, "--draft")
    assert_includes(captured("gh-pr-create.body"), "Widgets cannot ship today.")
    assert_includes(stdout, PR_URL)
  end

  def test_on_a_work_repository_refuses_a_change_folder_that_is_not_excluded
    work_change(exclude: false)

    _, stderr, status = deliver

    assert_equal(1, status.exitstatus)
    assert_match(%r{docs/changes is not in \.git/info/exclude}, stderr)
    assert_empty(gh_calls.grep(/\Apr (create|edit)/))
  end

  def test_on_a_work_repository_an_unexcluded_folder_is_not_called_an_uncommitted_change
    work_change(exclude: false)

    _, stderr, = deliver

    refute_match(/uncommitted changes; commit/, stderr)
  end

  def test_on_a_work_repository_refuses_a_review_older_than_head
    work_change
    commit_file("lib/widget.rb", "class Widget; def late; end; end\n", "Change widget after review")

    _, stderr, status = deliver
    _, check_stderr, check_status = deliver("--check")

    assert_equal(1, status.exitstatus)
    assert_match(/The review is not fresh/, stderr)
    assert_equal(1, check_status.exitstatus)
    assert_match(/The review is not fresh/, check_stderr)
    assert_empty(gh_calls.grep(/\Apr (create|edit)/))
  end

  def test_on_a_work_repository_refuses_an_open_finding
    work_change(findings: [ OPEN_FINDING ])

    _, stderr, status = deliver

    assert_equal(1, status.exitstatus)
    assert_match(/Open finding/, stderr)
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
    assert(File.exist?(File.join(@repo, "docs/changes", SLUG, "plan.md")))
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
    refute_includes(body, "## Proof")
    refute_includes(body, "test_widgets_ship")
  end

  def test_keeps_the_designs_diagram_and_drops_its_internals_from_the_body
    commit_change_work(plan: plan_with_design)

    deliver
    body = captured("gh-pr-create.body")

    assert_includes(body, "```mermaid")
    refute_includes(body, "Signatures")
    refute_includes(body, "## Proof")
  end

  def test_titles_the_pr_from_plan_md
    commit_change_work

    deliver

    assert_equal("Ship the widget", captured("gh-pr-create.title"))
  end

  def test_removes_the_folder_in_a_commit_of_its_own
    commit_change_work

    deliver
    files = git("show", "--name-only", "--format=", "HEAD").split

    assert_equal(REMOVAL_SUBJECT, git("log", "-1", "--format=%s").strip)
    assert_equal(%W[docs/changes/#{SLUG}/plan.md docs/changes/#{SLUG}/review.md], files.sort)
    assert_empty(git("status", "--porcelain").strip)
  end

  def test_removes_an_emptied_docs_changes
    commit_change_work

    deliver

    refute(File.exist?(File.join(@repo, "docs/changes")))
  end

  def test_keeps_docs_changes_when_another_change_lives_there
    commit_file("docs/changes/other/plan.md", "# Plan: Other\n", "Add other plan")
    commit_change_work

    deliver

    assert(File.exist?(File.join(@repo, "docs/changes/other/plan.md")))
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

  def test_never_closes_the_plan_pane
    commit_change_work
    plan_pane = pane("w1:pPlan", "claude", "idle")
    record_stage_panes([ plan_pane, pane("w1:pIdle", "claude", "idle") ])
    record_plan_pane(plan_pane)
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: [ plan_pane, pane("w1:pIdle", "claude", "idle") ] }) })

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

  def test_deliver_closes_idle_rex_stage_blocks
    commit_change_work
    record_rex_row(%w[blkIdle blkDone blkWorking blkShell])
    answer_rex_blocks(blkIdle: "idle", blkDone: "done", blkWorking: "working", blkShell: nil, OWN_BLOCK.to_sym => "idle")

    deliver(rex: true)

    assert_equal(%w[blkIdle blkDone], closed_blocks)
    refute(File.exist?(File.join(common_dir, "rex", "stage-panes-#{SLUG}")))
    assert_empty(herdr_calls)
  end

  def test_deliver_keeps_the_calling_and_plan_rex_blocks
    commit_change_work
    record_rex_row([ "blkPlan", "blkIdle", OWN_BLOCK ])
    File.write(File.join(common_dir, "rex", "plan-pane-#{SLUG}"), "blkPlan\n")
    answer_rex_blocks(blkPlan: "idle", blkIdle: "idle", OWN_BLOCK.to_sym => "idle")

    deliver(rex: true)

    assert_equal(%w[blkIdle], closed_blocks)
  end

  def test_deliver_closes_a_rex_block_only_when_every_record_is_idle_or_done
    commit_change_work
    record_rex_row(%w[blkMixed blkIdle])
    answer_rex_blocks(blkMixed: [ { state: "idle", app: "zsh" }, { state: "working", app: "claude-code" } ],
                      blkIdle: "idle")

    deliver(rex: true)

    assert_equal(%w[blkIdle], closed_blocks)
  end

  def test_deliver_leaves_a_recorded_block_that_rex_no_longer_lists
    commit_change_work
    record_rex_row(%w[blkGone blkIdle])
    answer_rex_blocks(blkIdle: "idle", listed: %w[blkIdle])

    deliver(rex: true)

    assert_equal(%w[blkIdle], closed_blocks)
  end

  def test_a_failed_rex_block_list_after_the_pr_exists_only_warns
    commit_change_work
    record_rex_row(%w[blkIdle])
    stub_response("rex block ls", { "exit" => 1, "stderr" => "rex: server not responding\n" })

    stdout, stderr, status = deliver(rex: true)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_match(/server not responding/, stderr)
    assert_empty(closed_blocks)
  end

  def test_a_rex_block_with_a_malformed_program_record_stays_open
    commit_change_work
    record_rex_row(%w[blkOdd])
    answer_rex_blocks(blkOdd: [ "idle" ])

    stdout, stderr, status = deliver(rex: true)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_empty(closed_blocks)
  end

  def test_deliver_uses_the_herdr_panes_when_both_are_set
    commit_change_work
    record_stage_panes(panes_in_play)
    stub_response("herdr pane list", { "stdout" => JSON.generate(result: { panes: panes_in_play }) })
    record_rex_row(%w[blkIdle])
    answer_rex_blocks(blkIdle: "idle")

    deliver(herdr: true, rex: true)

    assert_equal(%w[w1:pIdle w1:pDone], closed_panes)
    assert_empty(closed_blocks)
  end

  def test_deliver_runs_close_idle_in_herdr_app
    commit_change_work
    herdr_app_setup(HerdrAppHarness::Fixtures.default_world(cwd: toplevel))
    env = herdr_app_env.merge("PATH" => "#{@herdr_app_bin}:#{@stub_bin}:#{ENV.fetch('PATH')}",
                              "HERDR_APP_SCRIPTS_DIR" => @dash_scripts)

    stdout, stderr, status = deliver(env: env)

    assert(status.success?, stderr)
    assert_includes(stdout, PR_URL)
    assert_equal([ [ "close-idle", SLUG ] ], herdr_app_pane_cli_calls)
    assert_empty(herdr_calls)
    assert_empty(rex_calls)
  end

  def test_deliver_opens_the_dash_through_the_dispatcher_in_a_rex_block
    commit_change_work

    deliver(rex: true, env: { "REX_SCRIPTS_DIR" => @dash_scripts })

    assert_equal([ "#{SLUG} #{PR_URL}" ], dash_calls)
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

  def test_an_autonomous_plan_with_no_evidence_is_refused_and_nothing_is_removed
    commit_autonomous_change

    assert_refused_and_untouched(/required kind tests has no fresh passing entry/)
  end

  def test_an_autonomous_plan_with_stale_evidence_is_refused
    commit_autonomous_change
    record_evidence
    commit_file("lib/widget.rb", "class Widget; def late; end; end\n", "Change widget after evidence")
    commit_review(SLUG, [])

    assert_refused_and_untouched(/stale/)
  end

  def test_check_mode_reports_missing_evidence_for_an_autonomous_plan
    commit_autonomous_change

    _, stderr, status = deliver("--check")

    assert_equal(1, status.exitstatus)
    assert_match(/required kind lint has no fresh passing entry/, stderr)
  end

  def test_an_autonomous_plan_with_fresh_evidence_builds_the_body_from_the_handover
    commit_autonomous_change
    record_evidence
    stub_pr_view_from_the_draft

    _, stderr, status = deliver

    assert(status.success?, stderr)
    body = captured("gh-pr-create.body")
    assert_includes(body, "Widgets now ship by themselves, verified.")
    assert_includes(body, "true")
    refute_includes(body, "test_widgets_ship")
    refute(File.exist?(File.join(@repo, "docs/changes", SLUG)))
  end

  def test_a_pr_that_does_not_match_the_handover_exits_one_after_the_pr_exists
    commit_autonomous_change
    record_evidence
    stub_response("gh pr view", { "stdout" => JSON.generate(headRefOid: "0" * 40, body: "## Summary\n\nNothing\n") })

    _, stderr, status = deliver

    assert_equal(1, status.exitstatus)
    assert_match(/does not match the handover/, stderr)
    assert_equal(1, gh_calls.count { |call| call.start_with?("pr create ") })
    assert_equal(REMOVAL_SUBJECT, git("log", "-1", "--format=%s").strip)
  end

  def test_a_matching_pr_passes_the_check
    commit_autonomous_change
    record_evidence
    stub_pr_view_from_the_draft

    _, stderr, status = deliver

    assert(status.success?, stderr)
    assert_includes(gh_calls, "pr view --json body,headRefOid")
  end

  def test_a_step_by_step_plan_never_calls_delivery_evidence
    commit_change_work
    log = File.join(@state, "evidence.log")
    spy = File.join(@state, "spy")
    File.write(spy, "#!/bin/sh\necho \"$*\" >> #{log}\nexit 1\n")
    FileUtils.chmod(0o755, spy)

    _, stderr, status = deliver(env: { "DELIVERY_EVIDENCE" => spy })

    assert(status.success?, stderr)
    refute(File.exist?(log))
    assert_empty(gh_calls.grep(/\Apr view/))
  end

  def test_audit_is_required_when_the_lockfile_names_brakeman
    commit_file("Gemfile.lock", "GEM\n  specs:\n    brakeman (7.0.0)\n", "Add lockfile")
    commit_autonomous_change
    record_evidence

    _, stderr, status = deliver("--check")

    assert_equal(1, status.exitstatus)
    assert_match(/required kind audit has no fresh passing entry/, stderr)
  end

  def test_audit_is_not_required_without_a_scanner_in_the_lockfile
    commit_file("Gemfile.lock", "GEM\n  specs:\n    rake (13.0.0)\n", "Add lockfile")
    commit_autonomous_change
    record_evidence

    _, stderr, status = deliver("--check")

    assert(status.success?, stderr)
  end

  private

  def plan_with_design
    <<~MD
      # Plan: Ship the widget

      ## Design

      ### Diagrams

      ```mermaid
      classDiagram
        Widget --> Ship
      ```

      ### Signatures

      `Widget#ship`

      ## Proof

      - Widgets ship → `test/widget_test.rb` `test_widgets_ship`
    MD
  end

  # A work repository: the artefacts are untracked files and docs/changes is excluded.
  def work_change(exclude: true, findings: [ "- [ ] Nit: Naming — `lib/widget.rb:1` → fixed (Rename widget)" ])
    build_repo(origin_url: WORK_URL)
    allow_work_remote
    exclude_change_folders if exclude
    folder = File.join(@repo, "docs/changes", SLUG)
    FileUtils.mkdir_p(folder)
    File.write(File.join(folder, "plan.md"), plan_text)
    commit_file("lib/widget.rb", "class Widget; end\n", "Add widget")
    round = "## Round 1 — 2026-10-13T10:00:00Z — #{git('rev-parse', '--short', 'HEAD').strip}\n\n#{findings.join("\n")}\n"
    File.write(File.join(folder, "review.md"), "# Review\n\n#{round}")
  end

  # deliver finds the dispatchers under the home folder, where the agents package links them.
  def install_dispatchers
    FileUtils.mkdir_p(File.join(@home, ".agents"))
    File.symlink(File.join(REPO_ROOT, "agents/.agents/bin"), File.join(@home, ".agents", "bin"))
  end

  # What hand-off-plan.sh and start-review.sh record in Rex: one block id per line.
  def record_rex_row(ids)
    FileUtils.mkdir_p(File.join(common_dir, "rex"))
    File.write(File.join(common_dir, "rex", "stage-panes-#{SLUG}"), ids.map { |id| "#{id}\n" }.join)
  end

  # states: block id => program_status state, an array of records, or nil for a block with no records. `listed`
  # names the blocks `rex block ls` lists; by default every block of states.
  def answer_rex_blocks(listed: nil, **states)
    ids = listed || states.keys.map(&:to_s)
    stub_response("rex block ls", { "stdout" => JSON.generate(blocks: ids.map { |id| { block_id: id, label: "shell", flavor: "shell" } }) })
    states.each do |id, state|
      records = state.is_a?(Array) ? state : (state ? [ { state: state, app: "claude-code" } ] : [])
      stub_response("rex program_status #{id}", { "stdout" => JSON.generate(records: records) })
    end
  end

  def closed_blocks
    rex_calls.grep(/\Ablock close\b/).flat_map do |call|
      call.split.drop(2).reject { |word| word.start_with?("-") || word == SESSION }
    end
  end

  def commit_autonomous_change
    commit_change_work
    accepted = plan_text.sub("Type: feature.", "Type: feature. Delivery: autonomous.")
    commit_file("docs/changes/#{SLUG}/plan.md", accepted, "Make the plan autonomous")
    commit_review(SLUG, [])
  end

  def record_evidence
    %w[tests lint].each { |kind| evidence("run", "--kind", kind, "--name", kind, "--", "true") }
    evidence("note", "--delivered", "Widgets now ship by themselves, verified.")
  end

  def evidence(*arguments)
    script = File.join(REPO_ROOT, "agents/.agents/skills/finish/scripts/delivery-evidence")
    _, stderr, status = Open3.capture3(script_environment(false), script, *arguments, chdir: @repo)
    raise("delivery-evidence #{arguments.join(' ')}: #{stderr}") unless status.success?
  end

  # A gh that answers `pr view` as a real PR would after the push: the local HEAD, and a body
  # holding the handover's Verification section. Every other call goes to the stub.
  def stub_pr_view_from_the_draft
    handover = File.join(common_dir, "herdr", "deliver-#{SLUG}-handover.md")
    real = File.join(@stub_bin, "gh")
    wrapper = File.join(@state, "wrapper")
    FileUtils.mkdir_p(wrapper)
    File.write(File.join(wrapper, "gh"), <<~SH)
      #!/bin/sh
      if [ "$1 $2" = "pr view" ]; then
        echo "$*" >> "$STUB_STATE/gh.log"
        ruby -rjson -e 'text = File.read(ARGV[1]); body = text[/^## Verification\n\n(.*?)(?=\n## |\z)/m, 1]
          puts JSON.generate(headRefOid: `git rev-parse HEAD`.strip, body: body)' -- "$(git rev-parse HEAD)" #{handover}
      else
        exec #{real} "$@"
      fi
    SH
    FileUtils.chmod(0o755, File.join(wrapper, "gh"))
    @extra_path = wrapper
  end

  def deliver(*arguments, herdr: false, rex: false, scripts: @dash_scripts, env: {})
    env = { "HERDR_SCRIPTS_DIR" => scripts, "DASH_LOG" => dash_log }.merge(env)
    env["PATH"] = "#{@extra_path}:#{@stub_bin}:#{ENV.fetch('PATH')}" if @extra_path
    run_script(DELIVER, *arguments, herdr: herdr, rex: rex, env: env)
  end

  def assert_refused_and_untouched(reason)
    head = git("rev-parse", "HEAD")

    stdout, stderr, status = deliver

    assert_equal(1, status.exitstatus, stdout + stderr)
    assert_match(reason, stderr)
    assert_equal(head, git("rev-parse", "HEAD"))
    assert(File.exist?(File.join(@repo, "docs/changes", SLUG, "plan.md")))
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

  # What the plan skill records: the pane id, then the terminal id, one per line.
  def record_plan_pane(entry)
    File.write(File.join(common_dir, "herdr", "plan-pane-#{SLUG}"), "#{entry[:pane_id]}\n#{entry[:terminal_id]}\n")
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
