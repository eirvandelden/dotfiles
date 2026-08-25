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

    prompt = herdr_calls.find { |call| call.start_with?("agent prompt handoff-w1-pv ") }
    assert_includes(prompt, plan)
    assert_match(/worktree/i, prompt)
  end

  def test_handing_off_reports_only_where_the_work_went
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
    git("tag", "-m", "release", "main")

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
    @repo = linked_worktree_of(main_checkout)

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

  private

  def track_origin_head_on(branch)
    git("remote", "add", "origin", "git@example.com:someone/repo.git")
    git("update-ref", "refs/remotes/origin/#{branch}", "HEAD")
    git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/#{branch}")
  end

  def linked_worktree_of(repository)
    worktree = File.join(Dir.mktmpdir, "worktree")
    @extra_dirs << File.dirname(worktree)
    git("worktree", "add", "--quiet", worktree, "-b", "handed-over")
    worktree
  end

  def repo_on(branch)
    @repo = Dir.mktmpdir
    @extra_dirs << @repo
    git("init", "--quiet", "--initial-branch=#{branch}")
    git("commit", "--quiet", "--allow-empty", "-m", "initial")
    @repo
  end

  def git(*arguments)
    system("git", "-C", @repo, "-c", "core.hooksPath=/dev/null",
           "-c", "user.email=test@example.com", "-c", "user.name=Test", *arguments) ||
      raise("git #{arguments.join(' ')} failed")
  end

  def plan_file
    path = File.join(@repo, "plan.md")
    File.write(path, "# Plan\n\nDo the thing.\n")
    path
  end

  def install_herdr_stub
    stub = File.join(@stub_bin, "herdr")
    File.write(stub, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> "$HERDR_CALL_LOG"
      case "$1 $2" in
        "tab create") echo '{"result":{"root_pane":{"pane_id":"w1:pV"}}}' ;;
        "pane split") echo '{"result":{"pane":{"pane_id":"w1:pW"}}}' ;;
        *) echo '{"result":{}}' ;;
      esac
    SH
    FileUtils.chmod(0o755, stub)
  end

  def run_script(script, *arguments, herdr_env: "1")
    environment = {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "HERDR_CALL_LOG" => call_log,
      "HERDR_ENV" => herdr_env,
      "HERDR_WORKSPACE_ID" => "w1",
      "HERDR_PANE_ID" => "w1:p1"
    }
    Open3.capture3(environment, script, *arguments, chdir: @repo)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def reviewer_prompt
    herdr_calls.find { |call| call.start_with?("agent prompt review-w1-pw ") }
  end

  def herdr_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
  end
end
