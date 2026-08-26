#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Two scripts spawn a Claude worker inside the running Herdr session: one hands a
# plan to a fresh worker in a new tab, one asks a reviewer to look at this branch
# in a pane beside the caller. A stub `herdr` records the commands they issue.
class HerdrWorkerScriptsTest < Minitest::Test
  SCRIPTS = File.expand_path("../herdr/.config/herdr/scripts", __dir__)
  HAND_OFF_PLAN = File.join(SCRIPTS, "hand-off-plan.sh")
  START_REVIEW = File.join(SCRIPTS, "start-review.sh")

  def setup
    @stub_bin = Dir.mktmpdir
    install_herdr_stub
    install_git_recorder
    @extra_dirs = []
    repo_on("main")
  end

  def teardown
    FileUtils.rm_rf([ @stub_bin, *@extra_dirs ])
  end

  def test_handing_off_outside_herdr_is_refused
    _, stderr, status = run_script(HAND_OFF_PLAN, plan_file, herdr_env: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/herdr/i, stderr)
  end

  def test_handing_off_a_plan_that_is_not_there_is_refused
    _, stderr, status = run_script(HAND_OFF_PLAN, File.join(@repo, "missing.md"))

    assert_equal(1, status.exitstatus)
    assert_match(/plan/i, stderr)
  end

  def test_handing_off_opens_a_tab_here_without_taking_the_screen
    run_script(HAND_OFF_PLAN, plan_file)

    assert_includes(herdr_calls,
                    "tab create --workspace w1 --cwd #{File.realpath(@repo)} --label handoff --no-focus")
  end

  def test_handing_off_starts_claude_on_sonnet_in_the_new_tab
    run_script(HAND_OFF_PLAN, plan_file)

    assert_includes(herdr_calls,
                    "agent start handoff-w1-pv --kind claude --pane w1:pV -- --model sonnet")
  end

  def test_the_worker_is_told_to_read_the_plan_and_work_in_its_own_worktree
    plan = plan_file

    run_script(HAND_OFF_PLAN, plan)

    assert_includes(handoff_prompt, plan)
    assert_match(/worktree/i, handoff_prompt)
  end

  def test_handing_off_reports_where_the_work_went_and_where_its_report_lands
    stdout, = run_script(HAND_OFF_PLAN, plan_file)

    assert_equal(1, stdout.lines.count, stdout)
    assert_match(/handoff-w1-pv/, stdout)
  end

  def test_reviewing_outside_herdr_is_refused
    _, stderr, status = run_script(START_REVIEW, herdr_env: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/herdr/i, stderr)
  end

  def test_reviewing_splits_the_caller_pane_to_the_right_without_taking_the_screen
    run_script(START_REVIEW)

    assert_includes(herdr_calls,
                    "pane split --current --direction right --cwd #{File.realpath(@repo)} --no-focus")
  end

  def test_reviewing_starts_claude_on_opus_in_the_new_pane
    run_script(START_REVIEW)

    assert_includes(herdr_calls,
                    "agent start review-w1-pw --kind claude --pane w1:pW -- --model opus")
  end

  def test_the_reviewer_is_told_to_read_the_branch_diff_and_the_uncommitted_changes
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "git diff main...HEAD")
    assert_match(/uncommitted/i, reviewer_prompt)
    assert_match(/report|findings/i, reviewer_prompt)
  end

  def test_a_repository_without_main_is_reviewed_against_master
    @repo = repo_on("master")

    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "git diff master...HEAD")
  end

  def test_a_repository_with_an_upstream_default_branch_is_reviewed_against_the_remote_branch
    track_origin_head_on("main")

    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "git diff origin/main...HEAD")
  end

  def test_a_tag_named_after_the_default_branch_is_not_taken_for_the_base_branch
    @repo = repo_on("feature")
    git("tag", "main")

    _, stderr, status = run_script(START_REVIEW)

    assert_equal(1, status.exitstatus)
    assert_match(/branch/i, stderr)
  end

  def test_reviewing_outside_a_repository_is_refused_before_a_pane_is_opened
    @repo = Dir.mktmpdir
    @extra_dirs << @repo

    _, stderr, status = run_script(START_REVIEW)

    assert_equal(1, status.exitstatus)
    assert_match(/repository/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_handing_off_from_a_worktree_sends_the_worker_to_the_main_checkout
    main_checkout = @repo
    @repo = linked_worktree

    run_script(HAND_OFF_PLAN, plan_file)

    assert_includes(herdr_calls,
                    "tab create --workspace w1 --cwd #{File.realpath(main_checkout)} " \
                    "--label handoff --no-focus")
  end

  def test_handing_off_outside_a_repository_is_refused_before_a_tab_is_opened
    @repo = Dir.mktmpdir
    @extra_dirs << @repo

    _, stderr, status = run_script(HAND_OFF_PLAN, plan_file)

    assert_equal(1, status.exitstatus)
    assert_match(/repository/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_reviewing_never_reaches_the_network_itself
    track_origin_head_on("main")

    run_script(START_REVIEW)

    assert_includes(git_calls, "symbolic-ref --short refs/remotes/origin/HEAD")
    assert_empty(git_calls.grep(/fetch|pull|ls-remote/))
    assert_match(/fetch/i, reviewer_prompt)
  end

  def test_the_reviewer_is_given_a_place_to_write_its_findings
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, report_path("review-w1-pw"))
    assert(File.directory?(File.dirname(report_path("review-w1-pw"))),
           "the reviewer cannot write a report into a directory that is not there")
  end

  def test_the_reviewer_is_told_to_ping_the_agent_that_asked_for_the_review
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "herdr agent prompt")
    assert_includes(reviewer_prompt, "pane w1:p1")
  end

  def test_reviewing_reports_where_the_findings_will_land
    stdout, = run_script(START_REVIEW)

    assert_includes(stdout, report_path("review-w1-pw"))
  end

  def test_the_worker_is_told_where_to_report_and_who_to_tell
    run_script(HAND_OFF_PLAN, plan_file)

    assert_includes(handoff_prompt, report_path("handoff-w1-pv"))
    assert_includes(handoff_prompt, "pane w1:p1")
    assert(File.directory?(File.dirname(report_path("handoff-w1-pv"))),
           "the worker cannot write a report into a directory that is not there")
  end

  def test_a_review_started_from_a_worktree_reports_where_the_worktree_sweep_cannot_delete_it
    main_checkout = @repo
    @repo = linked_worktree

    run_script(START_REVIEW)

    assert_includes(reviewer_prompt,
                    File.join(File.realpath(main_checkout), ".git", "herdr", "review-w1-pw.md"))
  end

  def test_reviewing_without_a_caller_to_report_to_is_refused_before_a_pane_is_opened
    _, stderr, status = run_script(START_REVIEW, caller_pane: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/herdr/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_handing_off_without_a_caller_to_report_to_is_refused_before_a_tab_is_opened
    _, stderr, status = run_script(HAND_OFF_PLAN, plan_file, caller_pane: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/herdr/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_the_reviewer_is_told_to_keep_trying_until_the_caller_accepts_the_ping
    run_script(START_REVIEW)

    assert_match(/again/i, reviewer_prompt)
    assert_match(/blocked/i, reviewer_prompt)
    assert_match(/give up|stop trying/i, reviewer_prompt)
  end

  def test_the_worker_is_told_to_keep_trying_until_the_initiator_accepts_the_ping
    run_script(HAND_OFF_PLAN, plan_file)

    assert_match(/again/i, handoff_prompt)
    assert_match(/give up|stop trying/i, handoff_prompt)
  end

  def test_an_awkward_repository_path_still_reaches_the_reviewer_intact
    @repo = repo_on("main", inside: "o'brien's work files")

    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, report_path("review-w1-pw"))
    assert_equal(0, reviewer_prompt.count("'") - report_path("review-w1-pw").count("'"),
                 "the prompt adds quotes of its own, which this path would break")
  end

  def test_a_report_left_by_an_earlier_session_is_cleared_before_the_reviewer_can_write
    stale = report_path("review-w1-pw")
    FileUtils.mkdir_p(File.dirname(stale))
    File.write(stale, "yesterday's findings\n")

    run_script(START_REVIEW)

    assert_includes(report_state_at_agent_start, "review-w1-pw empty")
  end

  def test_a_report_left_by_an_earlier_session_is_cleared_before_the_worker_can_write
    stale = report_path("handoff-w1-pv")
    FileUtils.mkdir_p(File.dirname(stale))
    File.write(stale, "an earlier worker's notes\n")

    run_script(HAND_OFF_PLAN, plan_file)

    assert_includes(report_state_at_agent_start, "handoff-w1-pv empty")
  end

  def test_a_report_directory_that_cannot_be_created_stops_the_review_before_anything_is_spawned
    git_directory = File.join(@repo, ".git")
    FileUtils.chmod(0o500, git_directory)

    _, stderr, status = run_script(START_REVIEW)

    assert_equal(1, status.exitstatus)
    assert_match(/report/i, stderr)
    assert_empty(herdr_calls)
  ensure
    FileUtils.chmod(0o700, git_directory)
  end

  def test_a_report_directory_that_cannot_be_created_stops_the_handoff_before_anything_is_spawned
    git_directory = File.join(@repo, ".git")
    FileUtils.chmod(0o500, git_directory)

    _, _, status = run_script(HAND_OFF_PLAN, plan_file)

    assert_equal(1, status.exitstatus)
    assert_empty(herdr_calls)
  ensure
    FileUtils.chmod(0o700, git_directory)
  end

  private

  def track_origin_head_on(branch)
    git("remote", "add", "origin", "git@example.com:someone/repo.git")
    git("update-ref", "refs/remotes/origin/#{branch}", "HEAD")
    git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/#{branch}")
  end

  def awkward_parent(name)
    parent = File.join(Dir.mktmpdir, name)
    @extra_dirs << parent
    FileUtils.mkdir_p(parent)
    parent
  end

  def linked_worktree
    worktree = File.join(Dir.mktmpdir, "worktree")
    @extra_dirs << File.dirname(worktree)
    git("worktree", "add", "--quiet", worktree, "-b", "handed-over")
    worktree
  end

  def repo_on(branch, inside: nil)
    @repo = inside ? Dir.mktmpdir(nil, awkward_parent(inside)) : Dir.mktmpdir
    @extra_dirs << @repo
    git("init", "--quiet", "--initial-branch=#{branch}")
    git("commit", "--quiet", "--allow-empty", "-m", "initial")
    @repo
  end

  def git(*arguments)
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null",
           "-c", "user.email=test@example.com", "-c", "user.name=Test",
           "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false",
           "-c", "tag.forceSignAnnotated=false", *arguments) ||
      raise("git #{arguments.join(' ')} failed")
  end

  def plan_file
    path = File.join(@repo, "plan.md")
    File.write(path, "# Plan\n\nDo the thing.\n")
    path
  end

  # Records what the scripts ask git to do, then hands the call to the real git.
  def install_git_recorder
    recorder = File.join(@stub_bin, "git")
    File.write(recorder, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> "$GIT_CALL_LOG"
      exec /usr/bin/git "$@"
    SH
    FileUtils.chmod(0o755, recorder)
  end

  def install_herdr_stub
    stub = File.join(@stub_bin, "herdr")
    File.write(stub, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> "$HERDR_CALL_LOG"
      case "$1 $2" in
        "tab create") echo '{"result":{"root_pane":{"pane_id":"w1:pV"}}}' ;;
        "pane split") echo '{"result":{"pane":{"pane_id":"w1:pW"}}}' ;;
        "agent start")
          if [ ! -e "$REPORT_DIR/$3.md" ]; then state=missing
          elif [ -s "$REPORT_DIR/$3.md" ]; then state=holds-something
          else state=empty
          fi
          printf '%s\\n' "$3 $state" >> "$REPORT_STATE_LOG"
          echo '{"result":{}}'
          ;;
        *) echo '{"result":{}}' ;;
      esac
    SH
    FileUtils.chmod(0o755, stub)
  end

  def run_script(script, *arguments, herdr_env: "1", caller_pane: "w1:p1")
    environment = {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "HERDR_CALL_LOG" => call_log,
      "GIT_CALL_LOG" => git_call_log,
      "REPORT_DIR" => File.join(@repo, ".git", "herdr"),
      "REPORT_STATE_LOG" => report_state_log,
      "HERDR_ENV" => herdr_env,
      "HERDR_WORKSPACE_ID" => "w1",
      "HERDR_PANE_ID" => caller_pane
    }
    Open3.capture3(environment, script, *arguments, chdir: @repo)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def handoff_prompt
    herdr_calls.find { |call| call.start_with?("agent prompt handoff-w1-pv ") }
  end

  def report_path(agent_name)
    File.join(File.realpath(@repo), ".git", "herdr", "#{agent_name}.md")
  end

  def reviewer_prompt
    herdr_calls.find { |call| call.start_with?("agent prompt review-w1-pw ") }
  end

  def report_state_log
    @report_state_log ||= File.join(@stub_bin, "report-state.log")
  end

  def report_state_at_agent_start
    File.exist?(report_state_log) ? File.readlines(report_state_log, chomp: true) : []
  end

  def git_call_log
    @git_call_log ||= File.join(@stub_bin, "git-calls.log")
  end

  def git_calls
    File.exist?(git_call_log) ? File.readlines(git_call_log, chomp: true) : []
  end

  def herdr_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
  end
end
