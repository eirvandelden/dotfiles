#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# The herdr-app stage scripts hand-off-plan.sh and start-review.sh open a Claude worker beside the
# coordinator through the real herdr-app-pane CLI, which talks to stub herdr-app and hc executables. The
# worker starts as `claude --model <model> <prompt>` in a pane.split argv: the prompt is its last word.
# The coordinator is t10 in pane p10; HC_TERMINAL_ID is set in the child environment only.
#
# Interface these tests pin, beyond the plan: the report files and the row record live in
# <git-common-dir>/herdr-app/; a report is named <stage>-<six mktemp characters>.md.
class HerdrAppWorkerScriptsTest < Minitest::Test
  include HerdrAppHarness
  include HerdrAppHarness::Fixtures

  HAND_OFF_PLAN = File.join(SCRIPTS, "hand-off-plan.sh")
  START_REVIEW = File.join(SCRIPTS, "start-review.sh")
  DISPATCHERS = File.join(REPO_ROOT, "agents/.agents/bin")
  SKILLS_DIR = File.join(REPO_ROOT, "agents/.agents/skills")
  WORKTREE_TOOLS_DIR = File.join(REPO_ROOT, "git/.config/git/worktree-tools")
  SLUG = "some-change".freeze

  # Git runs with no hooks, a fixed identity and no signing.
  #: (String directory, *String arguments) -> bool
  def self.run_git(directory, *arguments)
    system("git", "-C", directory, "-c", "core.hooksPath=/dev/null", "-c", "user.email=test@example.com",
           "-c", "user.name=Test", "-c", "commit.gpgsign=false", *arguments) || raise("git #{arguments.join(' ')} failed")
  end

  # A repository on main at <copy>/repo whose bare origin at <copy>/origin holds main, and whose
  # .worktrees directory is excluded, so a worktree can be created from it.
  WITH_ORIGIN = GitFixture.new do |root|
    repo = File.join(root, "repo")
    origin = File.join(root, "origin")
    system("git", "init", "--quiet", "--initial-branch=main", repo, exception: true)
    run_git(repo, "commit", "--quiet", "--allow-empty", "-m", "initial")
    system("git", "init", "--quiet", "--bare", "--initial-branch=main", origin, exception: true)
    run_git(repo, "remote", "add", "origin", origin)
    run_git(repo, "push", "--quiet", "origin", "main")
    File.write(File.join(repo, ".git", "info", "exclude"), ".worktrees\n")
  end
  private_constant :WITH_ORIGIN

  def setup
    @copy = WITH_ORIGIN.copy
    @repo = File.realpath(File.join(@copy, "repo"))
    herdr_app_setup(default_world(cwd: @repo))
    herdr_app_install("gh", "#!/bin/sh\nexit 1\n")
  end

  def teardown
    herdr_app_teardown
    FileUtils.rm_rf(@copy)
  end

  def test_refuses_auto_for_intent
    _, stderr, status = hand_off("intent", SLUG, "--auto")

    assert_equal(1, status.exitstatus)
    assert_match(/auto/i, stderr)
    assert_empty(herdr_app_calls)
  end

  def test_refuses_a_slug_that_looks_like_an_option
    _, stderr, status = hand_off("plan", "--auto")

    assert_equal(1, status.exitstatus)
    assert_match(/slug/i, stderr)
    assert_empty(herdr_app_calls)
  end

  def test_exits_1_when_the_pane_does_not_start
    herdr_app_world_change { |world| world["new_terminal"] = [ terminal("new", cwd: @repo) ] }

    _, stderr, status = hand_off("plan", SLUG)

    assert_equal(1, status.exitstatus)
    refute_empty(stderr)
    assert_equal([ { "pane" => "p61" } ], herdr_app_actions("pane.close"))
    assert_empty(row_record(SLUG))
  end

  def test_implement_handoff_opens_a_stage_pane_beside_the_coordinator_and_reports_back
    stdout, stderr, status = dispatch("hand-off-plan", "implement", SLUG)

    assert(status.success?, stderr)
    split = herdr_app_only_split
    assert_equal(%w[p10 right], split.values_at("pane", "direction"))
    assert_includes(split["argv"], worktree_path(SLUG))
    assert_equal("sonnet", model_of(split))
    assert_equal(%w[t61], row_record(SLUG))
    report = report_in(prompt_of(split), "implement")
    assert_includes(stdout, report)
    assert_match(/hc send t10\b/, prompt_of(split))
    assert_includes(prompt_of(split), "Handoff done:")
    # The real round trip, a worker's hc send reaching the coordinator, rests on the sandbox live check (plan Proof).
  end

  def test_intent_splits_down
    _, stderr, status = hand_off("intent", SLUG)

    assert(status.success?, stderr)
    assert_equal([ %w[p10 down] ], herdr_app_splits.map { |request| request.values_at("pane", "direction") })
    assert_equal("opus", model_of(herdr_app_splits.first))
  end

  def test_plan_and_implement_split_right_with_their_models
    hand_off("plan", SLUG)
    hand_off("implement", SLUG)

    assert_equal(%w[right right], herdr_app_splits.map { |request| request["direction"] })
    assert_equal(%w[opus sonnet], herdr_app_splits.map { |request| model_of(request) })
    assert_equal(%w[p10 p61], herdr_app_splits.map { |request| request["pane"] })
  end

  def test_auto_changes_the_prompt_as_in_rex
    hand_off("plan", SLUG, "--auto")
    hand_off("implement", SLUG, "--auto")
    plan, implement = herdr_app_splits.map { |request| prompt_of(request) }

    [ plan, implement ].each { |prompt| assert_match(/with the auto argument/, prompt) }
    refute_includes(plan, "literal word")
    assert_match(/do not wait for .*accepted/i, plan)
    assert_includes(plan, "Do not start the next stage")
    assert_includes(implement, "Decision needed:")
  end

  def test_the_prompt_names_hc_send_to_the_coordinator_and_the_absolute_herdr_app_pane_close
    _, stderr, status = hand_off("plan", SLUG, env: { "HERDR_APP_PANE" => nil })

    assert(status.success?, stderr)
    prompt = prompt_of(herdr_app_only_split)
    assert_match(/hc send t10\b/, prompt)
    assert_includes(prompt, "Plan ready:")
    assert_includes(prompt, "at most twelve times")
    assert_includes(prompt, "#{PANE_CLI} close")
    assert_includes(prompt, "COORDINATOR=t10")
    refute_match(/\brex (send|block)\b/, prompt)
  end

  def test_two_handoffs_get_two_empty_report_files
    hand_off("plan", SLUG)
    hand_off("plan", SLUG)

    reports = herdr_app_splits.map { |request| report_in(prompt_of(request), "plan") }

    assert_equal(2, reports.uniq.size, reports.inspect)
    reports.each { |report| assert(File.zero?(report), "#{report} is not an empty file") }
  end

  def test_start_review_opens_a_review_pane_in_the_row
    worktree = linked_worktree("handed-over")
    add_row_pane("t20", "p20", cwd: worktree)
    record_row("handed-over", "t20")

    _, stderr, status = dispatch("start-review", chdir: worktree)

    assert(status.success?, stderr)
    split = herdr_app_only_split
    assert_equal(%w[p20 right], split.values_at("pane", "direction"))
    assert_includes(split["argv"], worktree)
    assert_equal("opus", model_of(split))
    assert_includes(prompt_of(split), "review.md")
    assert_equal(%w[t20 t61], row_record("handed-over"))
  end

  def test_opens_claude_model_opus_in_the_row
    self.class.run_git(@repo, "checkout", "--quiet", "-b", "feature")

    _, stderr, status = review

    assert(status.success?, stderr)
    split = herdr_app_only_split
    assert_equal(%w[p10 right], split.values_at("pane", "direction"))
    assert_equal("opus", model_of(split))
    assert_match(/hc send t10\b/, prompt_of(split))
    assert_equal(%w[t61], row_record("feature"))
  end

  def test_opens_unrecorded_without_a_change_folder
    _, stderr, status = review

    assert(status.success?, stderr)
    assert_equal(1, herdr_app_splits.size)
    assert_empty(Dir.glob(File.join(report_directory, "stage-panes-*")))
  end

  def test_refuses_without_a_base_branch
    self.class.run_git(@repo, "remote", "remove", "origin")
    self.class.run_git(@repo, "branch", "-m", "main", "feature")

    _, stderr, status = review

    assert_equal(1, status.exitstatus)
    assert_match(/branch/i, stderr)
    assert_empty(herdr_app_calls)
  end

  private

  def environment(env)
    herdr_app_env(pane_cli: PANE_CLI).merge(
      "WORKTREE_TOOLS_DIR" => WORKTREE_TOOLS_DIR, "CLAUDE_SKILLS_DIR" => SKILLS_DIR, "HERDR_APP_SCRIPTS_DIR" => SCRIPTS
    ).merge(env)
  end

  def hand_off(*arguments, env: {})
    Open3.capture3(environment(env), HAND_OFF_PLAN, *arguments, chdir: @repo)
  end

  def review(chdir: @repo)
    Open3.capture3(environment({}), START_REVIEW, chdir: chdir)
  end

  def dispatch(name, *arguments, chdir: @repo)
    Open3.capture3(environment({}), File.join(DISPATCHERS, name), *arguments, chdir: chdir)
  end

  def prompt_of(request)
    request["argv"].last
  end

  def model_of(request)
    argv = request["argv"]
    argv[argv.index("--model") + 1]
  end

  def report_in(prompt, stage)
    report = prompt[%r{/[^\s'"]*/herdr-app/#{stage}-[A-Za-z0-9]{6}\.md}]
    refute_nil(report, "the prompt names no #{stage} report file")
    assert_equal(report_directory, File.dirname(report))
    report
  end

  def worktree_path(slug)
    File.realpath(File.join(@repo, ".worktrees", slug))
  end

  def linked_worktree(branch)
    path = File.join(@copy, branch)
    self.class.run_git(@repo, "worktree", "add", "--quiet", "-b", branch, path)
    File.realpath(path)
  end

  def add_row_pane(address, pane, cwd:)
    herdr_app_world_change do |world|
      add_terminal(world, agent_row(address, pane, "idle"), terminal(address, cwd: cwd, status: agent))
    end
  end

  def report_directory
    File.join(@repo, ".git", "herdr-app")
  end

  def record_row(slug, *lines)
    FileUtils.mkdir_p(report_directory)
    File.write(File.join(report_directory, "stage-panes-#{slug}"), lines.map { |line| "#{line}\n" }.join)
  end

  def row_record(slug)
    path = File.join(report_directory, "stage-panes-#{slug}")
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end
end
