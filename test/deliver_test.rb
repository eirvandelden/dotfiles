#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "delivery_harness"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# `deliver` ends a change: once a review round leaves no open finding it removes the change folder
# in a commit of its own, pushes the branch and opens (or updates) a draft PR, then asks the herdr-app
# script for a gh-dash pane. `deliver --check` runs only the preconditions. gh, herdr-app-pane and the pane
# script are stubs; see delivery_harness.rb for their formats.
#
# Interface these tests pin, beyond the plan: review-report-fresh is found through
# $WORKTREE_TOOLS_DIR; the pane script is $HERDR_APP_SCRIPTS_DIR/open-pr-dash.sh, called as
# `open-pr-dash.sh <slug> <pr-url>`; refusals go to stderr with exit 1; the PR URL goes to stdout.
class DeliverTest < Minitest::Test
  include DeliveryHarness
  include HerdrAppHarness

  SLUG = "my-change".freeze
  HC_ENV = { "HC_TERMINAL_ID" => "t10", "HERDR_APP_COORDINATOR" => nil }.freeze
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

    stdout, stderr, status = deliver(env: HC_ENV)

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

    _, stderr, status = deliver("--check")

    assert(status.success?, stderr)
    assert_equal(head, git("rev-parse", "HEAD"))
    assert(File.exist?(File.join(@repo, "docs/changes", SLUG, "intent.md")))
    assert_empty(origin_branches - [ "main" ])
    assert_empty(gh_calls.grep(/\Apr (create|edit)/))
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

  def test_deliver_closes_idle_stage_terminals_and_keeps_the_intent_terminal
    commit_change_work
    world = HerdrAppHarness::Fixtures.default_world(cwd: toplevel)
    herdr_app_setup(world)
    herdr_app_world_change do |changed|
      [ %w[t20 p20], %w[t21 p21] ].each do |address, pane|
        HerdrAppHarness::Fixtures.add_terminal(changed, HerdrAppHarness::Fixtures.agent_row(address, pane, "idle"),
                                               HerdrAppHarness::Fixtures.terminal(address, cwd: toplevel, status: HerdrAppHarness::Fixtures.agent("idle")))
      end
    end
    record_row_and_intent_terminals
    env = herdr_app_env(pane_cli: HerdrAppHarness::PANE_CLI).merge("HERDR_APP_SCRIPTS_DIR" => @dash_scripts,
                                                                      "PATH" => "#{@herdr_app_bin}:#{@stub_bin}:#{ENV.fetch('PATH')}")

    _, stderr, status = deliver(env: env)

    assert(status.success?, stderr)
    assert_equal(%w[p20], herdr_app_actions("pane.close").map { |request| request["pane"] })
    assert_includes(herdr_app_listed_panes, "p21")
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

  def test_outside_a_herdr_app_terminal_prints_the_pr_url_and_opens_no_pane
    commit_change_work
    herdr_app_setup(HerdrAppHarness::Fixtures.default_world(cwd: toplevel))
    env = herdr_app_env.merge("HC_TERMINAL_ID" => nil, "PATH" => "#{@herdr_app_bin}:#{@stub_bin}:#{ENV.fetch('PATH')}")

    stdout, stderr, status = deliver(env: env)

    assert(status.success?, stderr)
    refute_match(/stage panes stay open/, stderr)
    assert_includes(stdout, PR_URL)
    assert_equal(1, gh_calls.count { |call| call.start_with?("pr create ") })
    assert_empty(herdr_app_calls)
    assert_empty(dash_calls)
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
    File.write(File.join(folder, "intent.md"), intent_text)
    File.write(File.join(folder, "plan.md"), plan_text)
    commit_file("lib/widget.rb", "class Widget; end\n", "Add widget")
    round = "## Round 1 — 2026-10-13T10:00:00Z — #{git('rev-parse', '--short', 'HEAD').strip}\n\n#{findings.join("\n")}\n"
    File.write(File.join(folder, "review.md"), "# Review\n\n#{round}")
  end

  def deliver(*arguments, scripts: @dash_scripts, env: {})
    run_script(DELIVER, *arguments, env: { "HERDR_APP_SCRIPTS_DIR" => scripts, "DASH_LOG" => dash_log }.merge(env))
  end

  # deliver finds the dispatchers under the home folder, where the agents package links them.
  def install_dispatchers
    FileUtils.mkdir_p(File.join(@home, ".agents"))
    File.symlink(File.join(REPO_ROOT, "agents/.agents/bin"), File.join(@home, ".agents", "bin"))
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

  # What hand-off-plan.sh records in the row, and what the intent skill records: terminal addresses, one per line.
  def record_row_and_intent_terminals
    directory = File.join(common_dir, "herdr-app")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "stage-panes-#{SLUG}"), "t20\nt21\n")
    File.write(File.join(directory, "intent-pane-#{SLUG}"), "t21\n")
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
