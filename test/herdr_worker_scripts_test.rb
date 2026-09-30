#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Two scripts spawn a Claude worker inside the running Herdr session: one starts a stage
# (spec, plan, or implement) in a fresh worker in a new pane, one asks a reviewer to look at
# this branch in a pane beside the caller. A stub `herdr` records the commands they issue.
class HerdrWorkerScriptsTest < Minitest::Test
  SCRIPTS = File.expand_path("../herdr/.config/herdr/scripts", __dir__)
  HAND_OFF_PLAN = File.join(SCRIPTS, "hand-off-plan.sh")
  START_REVIEW = File.join(SCRIPTS, "start-review.sh")
  SKILLS_DIR = File.expand_path("../claude/.claude/skills", __dir__)

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
    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change", herdr_env: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/herdr/i, stderr)
  end

  def test_an_unrecognized_stage_name_is_refused
    _, stderr, status = run_script(HAND_OFF_PLAN, "bogus-stage", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/stage/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_refuses_a_missing_change_slug
    _, stderr, status = run_script(HAND_OFF_PLAN, "spec")

    assert_equal(1, status.exitstatus)
    assert_match(/slug|change/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_handing_off_takes_a_stage_and_a_change_slug
    worktree_creatable!

    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert(status.success?, stderr)
    assert_not_empty(herdr_calls)
  end

  def test_handing_off_an_intent_stage_splits_a_pane_below_here
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")

    assert_includes(herdr_calls,
                    "pane split --current --direction down --cwd " \
                    "#{worktree_path('some-change')} --no-focus")
  end

  def test_handing_off_a_spec_stage_splits_a_pane_to_the_right
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_includes(herdr_calls,
                    "pane split --current --direction right --cwd " \
                    "#{worktree_path('some-change')} --no-focus")
  end

  def test_handing_off_a_plan_stage_splits_a_pane_below_here
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(herdr_calls,
                    "pane split --current --direction down --cwd " \
                    "#{worktree_path('some-change')} --no-focus")
  end

  def test_handing_off_an_implement_stage_splits_a_pane_below_here
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert_includes(herdr_calls,
                    "pane split --current --direction down --cwd " \
                    "#{worktree_path('some-change')} --no-focus")
  end

  def test_the_intent_stage_starts_claude_on_opus
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")

    assert_includes(herdr_calls, "agent start intent-w1-pv --kind claude --pane w1:pV -- --model opus")
  end

  def test_the_spec_stage_starts_claude_on_sonnet_to_the_right
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_includes(herdr_calls, "agent start spec-w1-pw --kind claude --pane w1:pW -- --model sonnet")
  end

  def test_the_plan_stage_no_longer_starts_in_plan_mode
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(herdr_calls, "agent start plan-w1-pv --kind claude --pane w1:pV -- --model opus")
    assert_empty(herdr_calls.grep(/permission-mode/))
  end

  def test_the_implement_stage_starts_claude_on_sonnet
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert_includes(herdr_calls, "agent start implement-w1-pv --kind claude --pane w1:pV -- --model sonnet")
  end

  def test_names_the_worker_stage_dash_pane
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert(herdr_calls.any? { |call| call.start_with?("agent prompt implement-w1-pv ") },
           "expected a prompt sent to a worker named implement-w1-pv")
    assert_includes(herdr_calls, "agent start implement-w1-pv --kind claude --pane w1:pV -- --model sonnet")
  end

  def test_the_intent_worker_is_told_to_push_after_acceptance
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")
    prompt = worker_prompt("intent")

    assert_includes(prompt, "intent skill")
    assert_told_accepted_then_committed_then_pushed(prompt)
    assert_includes(prompt, "git push -u origin HEAD")
  end

  def test_the_intent_worker_is_told_to_invoke_the_intent_skill_with_no_upstream_artifact
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")

    assert_includes(worker_prompt("intent"), "no upstream artifact")
  end

  def test_the_plan_worker_is_told_to_write_plan_md_and_touch_nothing_else
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(worker_prompt("plan"), "touch nothing else")
  end

  def test_the_spec_worker_is_told_to_push_after_acceptance
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")
    prompt = worker_prompt("spec")

    assert_includes(prompt, "spec skill's here backend")
    assert_includes(prompt, "docs/changes/some-change/intent.md")
    assert_told_accepted_then_committed_then_pushed(prompt)
    assert_includes(prompt, "git push -u origin HEAD")
  end

  def test_the_plan_worker_is_told_to_push_after_acceptance
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")
    prompt = worker_prompt("plan")

    assert_includes(prompt, "plan skill's Write role, here backend")
    assert_includes(prompt, "docs/changes/some-change/intent.md")
    assert_includes(prompt, "docs/changes/some-change/spec.md")
    assert_told_accepted_then_committed_then_pushed(prompt)
    assert_includes(prompt, "git push -u origin HEAD")
  end

  def test_the_implement_worker_is_told_not_to_push
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")
    prompt = worker_prompt("implement")

    assert_includes(prompt, "implement skill's here backend")
    assert_includes(prompt, "docs/changes/some-change/plan.md")
    assert_no_match(/push/i, prompt)
  end

  def test_the_spec_and_plan_workers_report_what_was_decided_and_deferred
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")
    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(worker_prompt("spec"), "what spec.md decided and anything Etienne deferred")
    assert_includes(worker_prompt("plan"), "what plan.md decided and anything Etienne deferred")
  end

  def test_the_implement_worker_keeps_the_what_you_did_wording
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert_includes(worker_prompt("implement"), "what you did, and anything you could not finish")
  end

  def test_done_means_wording_is_only_in_the_implement_stage
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")
    run_script(HAND_OFF_PLAN, "plan", "some-change")
    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert_no_match(/done means/i, worker_prompt("spec"))
    assert_no_match(/done means/i, worker_prompt("plan"))
    assert_match(/done means/i, worker_prompt("implement"))
  end

  def test_the_intent_worker_is_given_the_coordinator_pane_id
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")

    prompt = worker_prompt("intent")

    assert_no_match(/hand-off-plan\.sh/, prompt)
    assert_includes(prompt, "Your coordinator's pane id is w1:p1")
    assert_includes(prompt, "HERDR_PANE_ID set to that id")
  end

  def test_the_spec_worker_is_given_the_coordinator_pane_id
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    prompt = worker_prompt("spec")

    assert_no_match(/hand-off-plan\.sh/, prompt)
    assert_includes(prompt, "Your coordinator's pane id is w1:p1")
    assert_includes(prompt, "HERDR_PANE_ID set to that id")
  end

  def test_the_plan_worker_is_given_the_coordinator_pane_id
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    prompt = worker_prompt("plan")

    assert_no_match(/hand-off-plan\.sh/, prompt)
    assert_includes(prompt, "Your coordinator's pane id is w1:p1")
    assert_includes(prompt, "HERDR_PANE_ID set to that id")
  end

  def test_the_implement_worker_is_not_told_to_start_a_next_stage
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    prompt = worker_prompt("implement")

    assert_no_match(/hand-off-plan\.sh/, prompt)
    assert_no_match(/coordinator's pane id/, prompt)
  end

  def test_the_spec_worker_is_told_to_note_a_failed_chain_call_in_its_report
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")
    prompt = worker_prompt("spec")

    assert_match(/if starting the next stage fails/i, prompt)
    assert_includes(prompt, "your own report file")
  end

  def test_the_worker_writes_its_report_after_acceptance_not_before
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")
    prompt = worker_prompt("spec")

    assert_operator(prompt.index("\"accepted\""), :<, prompt.index("write what spec.md decided"))
  end

  def test_each_accepting_skill_chains_once_to_its_next_stage_with_the_coordinator_id
    { "intent" => "spec", "spec" => "plan", "plan" => "implement" }.each do |stage, next_stage|
      skill = File.read(File.join(SKILLS_DIR, stage, "SKILL.md"))
      chain = "HERDR_PANE_ID=<coordinator> ~/.config/herdr/scripts/hand-off-plan.sh #{next_stage} '<slug>'"

      assert_equal(1, skill.scan(chain).size, "#{stage}/SKILL.md must chain to #{next_stage} with the coordinator id")
      assert_equal(1, skill.scan("hand-off-plan.sh #{next_stage}").size, "#{stage}/SKILL.md must chain to #{next_stage} exactly once")
    end
  end

  def test_the_worker_is_told_to_close_its_own_pane_after_reporting
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")
    prompt = worker_prompt("spec")

    assert_includes(prompt, "herdr pane close $HERDR_PANE_ID")
    assert_includes(prompt, "not the coordinator's id above")
  end

  def test_the_worker_is_told_where_to_report_and_who_to_tell
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_includes(worker_prompt("spec"), report_path("spec-w1-pw"))
    assert_includes(worker_prompt("spec"), "pane w1:p1")
    assert(File.directory?(File.dirname(report_path("spec-w1-pw"))),
           "the worker cannot write a report into a directory that is not there")
  end

  def test_each_stage_worker_retries_a_busy_coordinator_but_gives_up_eventually
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")
    prompt = worker_prompt("spec")

    assert_includes(prompt, "at most twelve times")
    assert_includes(prompt, "coordinator")
    assert_no_match(/initiator/i, prompt)
  end

  def test_still_resolves_the_caller_to_the_main_checkout_from_a_linked_worktree
    worktree_creatable!
    main_checkout = @repo
    @repo = linked_worktree

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_includes(herdr_calls,
                    "pane split --current --direction right --cwd " \
                    "#{worktree_path('some-change', checkout: main_checkout)} --no-focus")
  end

  def test_still_resolves_the_caller_to_the_submodule_checkout
    worktree_creatable!
    submodule = add_submodule("child")
    @repo = submodule

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_includes(herdr_calls,
                    "pane split --current --direction right --cwd " \
                    "#{worktree_path('some-change', checkout: submodule)} --no-focus")
  end

  def test_still_resolves_the_caller_to_the_submodules_linked_worktree_checkout
    worktree_creatable!
    submodule = add_submodule("child")
    linked = File.join(submodule, ".worktrees", "one")
    system("git", "-C", submodule, "worktree", "add", "--quiet", File.join(".worktrees", "one"), "-b", "one",
           "origin/main") || raise("git worktree add failed")
    @repo = linked

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_includes(herdr_calls,
                    "pane split --current --direction right --cwd " \
                    "#{worktree_path('some-change', checkout: submodule)} --no-focus")
  end

  def test_survives_an_awkward_repository_path_intact
    @repo = repo_on("main", inside: "o'brien's work files")
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_path_survived(worker_prompt("spec"), report_path("spec-w1-pw"))
  end

  def test_clears_a_stale_report_left_by_an_earlier_session
    worktree_creatable!
    stale = report_path("spec-w1-pw")
    FileUtils.mkdir_p(File.dirname(stale))
    File.write(stale, "an earlier worker's notes\n")

    run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_includes(report_state_at_agent_start, "spec-w1-pw empty")
  end

  def test_stops_before_spawning_anything_when_the_report_directory_cant_be_created
    worktree_creatable!
    git_directory = File.join(@repo, ".git")
    FileUtils.chmod(0o500, git_directory)

    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/report/i, stderr)
    assert_empty(herdr_calls)
  ensure
    FileUtils.chmod(0o700, git_directory)
  end

  def test_handing_off_outside_a_repository_is_refused_before_a_pane_is_opened
    @repo = Dir.mktmpdir
    @extra_dirs << @repo

    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/repository/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_handing_off_without_a_caller_to_report_to_is_refused_before_a_pane_is_opened
    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change", caller_pane: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/herdr/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_handing_off_reuses_an_existing_worktree_on_the_matching_branch
    worktree_creatable!
    worktree = File.join(@repo, ".worktrees", "some-change")
    git("worktree", "add", "--quiet", worktree, "-b", "some-change", "origin/main")

    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert(status.success?, stderr)
    assert(File.directory?(worktree))
    assert_includes(herdr_calls,
                    "pane split --current --direction right --cwd " \
                    "#{File.realpath(worktree)} --no-focus")
  end

  def test_handing_off_refuses_when_the_worktree_exists_on_a_different_branch
    worktree_creatable!
    worktree = File.join(@repo, ".worktrees", "some-change")
    git("worktree", "add", "--quiet", worktree, "-b", "unrelated-branch", "origin/main")

    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/some-change/, stderr)
    assert_empty(herdr_calls)
  end

  def test_handing_off_reports_where_the_work_went_and_where_its_report_lands
    worktree_creatable!

    stdout, = run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_equal(1, stdout.lines.count, stdout)
    assert_match(/spec-w1-pw/, stdout)
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

  def test_reviewing_never_reaches_the_network_itself
    track_origin_head_on("main")

    run_script(START_REVIEW)

    assert_includes(git_calls, "symbolic-ref --short refs/remotes/origin/HEAD")
    assert_empty(git_calls.grep(/fetch|pull|ls-remote/))
    assert_match(/fetch/i, reviewer_prompt)
  end

  def test_the_reviewer_derives_its_own_change_folder_and_report_location
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "change-folder")
    assert_includes(reviewer_prompt, "REVIEW.md")
    assert_includes(reviewer_prompt, "review.md")
  end

  def test_the_reviewer_is_told_to_ping_the_agent_that_asked_for_the_review
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "herdr agent prompt")
    assert_includes(reviewer_prompt, "pane w1:p1")
  end

  def test_reviewing_reports_where_the_findings_will_land
    stdout, = run_script(START_REVIEW)

    assert_includes(stdout, "docs/changes")
    assert_includes(stdout, "review.md")
  end

  def test_reviewing_from_a_worktree_still_reviews_that_branch
    @repo = linked_worktree

    run_script(START_REVIEW)

    assert_includes(herdr_calls,
                    "pane split --current --direction right --cwd #{File.realpath(@repo)} --no-focus")
  end

  def test_reviewing_without_a_caller_to_report_to_is_refused_before_a_pane_is_opened
    _, stderr, status = run_script(START_REVIEW, caller_pane: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/herdr/i, stderr)
    assert_empty(herdr_calls)
  end

  def test_the_reviewer_retries_a_busy_caller_but_gives_up_eventually
    run_script(START_REVIEW)

    assert_match(/blocked/i, reviewer_prompt)
    assert_includes(reviewer_prompt, "at most twelve times")
  end

  private

  def track_origin_head_on(branch)
    git("remote", "add", "origin", "git@example.com:someone/repo.git")
    git("update-ref", "refs/remotes/origin/#{branch}", "HEAD")
    git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/#{branch}")
  end

  def worktree_creatable!
    origin = Dir.mktmpdir
    @extra_dirs << origin
    system("git", "init", "--quiet", "--bare", "--initial-branch=main", origin) ||
      raise("git init --bare failed")
    git("remote", "add", "origin", origin)
    git("push", "--quiet", "origin", "main")
    File.write(File.join(@repo, ".git", "info", "exclude"), ".worktrees\n")
  end

  def awkward_parent(name)
    enclosing = Dir.mktmpdir
    @extra_dirs << enclosing
    parent = File.join(enclosing, name)
    FileUtils.mkdir_p(parent)
    parent
  end

  def linked_worktree
    worktree = File.join(Dir.mktmpdir, "worktree")
    @extra_dirs << File.dirname(worktree)
    git("worktree", "add", "--quiet", worktree, "-b", "handed-over")
    worktree
  end

  def add_submodule(name)
    child_origin = Dir.mktmpdir
    @extra_dirs << child_origin
    system("git", "init", "--quiet", "--bare", "--initial-branch=main", child_origin) ||
      raise("git init --bare failed")

    child_seed = Dir.mktmpdir
    @extra_dirs << child_seed
    system("git", "clone", "--quiet", child_origin, child_seed) || raise("git clone failed")
    system("git", "-C", child_seed, "-c", "core.hooksPath=/dev/null",
           "-c", "user.email=test@example.com", "-c", "user.name=Test",
           "commit", "--quiet", "--allow-empty", "-m", "child initial") || raise("git commit failed")
    system("git", "-C", child_seed, "push", "--quiet", "origin", "main") || raise("git push failed")

    git("-c", "protocol.file.allow=always", "submodule", "add", "--quiet", child_origin, name)
    git("commit", "--quiet", "-m", "add #{name} submodule")

    submodule = File.join(@repo, name)
    git_dir, = Open3.capture2("git", "-C", submodule, "rev-parse", "--absolute-git-dir")
    File.write(File.join(git_dir.strip, "info", "exclude"), ".worktrees\n")
    submodule
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
        "pane split")
          case "$*" in
            *"--direction down"*) echo '{"result":{"pane":{"pane_id":"w1:pV"}}}' ;;
            *) echo '{"result":{"pane":{"pane_id":"w1:pW"}}}' ;;
          esac
          ;;
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

  WORKTREE_TOOLS_DIR = File.expand_path("../git/.config/git/worktree-tools", __dir__)

  def run_script(script, *arguments, herdr_env: "1", caller_pane: "w1:p1")
    environment = {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "HERDR_CALL_LOG" => call_log,
      "GIT_CALL_LOG" => git_call_log,
      "REPORT_DIR" => report_directory,
      "REPORT_STATE_LOG" => report_state_log,
      "HERDR_ENV" => herdr_env,
      "HERDR_WORKSPACE_ID" => "w1",
      "HERDR_PANE_ID" => caller_pane,
      "WORKTREE_TOOLS_DIR" => WORKTREE_TOOLS_DIR
    }
    Open3.capture3(environment, script, *arguments, chdir: @repo)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  # intent, plan and implement split their pane downward, sharing one stubbed pane id (w1:pV);
  # spec splits to the right and gets a different one (w1:pW) from the same stub.
  RIGHT_SPLIT_STAGES = %w[spec].freeze

  def worker_name(stage)
    pane = RIGHT_SPLIT_STAGES.include?(stage) ? "w1-pw" : "w1-pv"
    "#{stage}-#{pane}"
  end

  def worker_prompt(stage)
    herdr_calls.find { |call| call.start_with?("agent prompt #{worker_name(stage)} ") }
  end

  def worktree_path(slug, checkout: @repo)
    path = File.join(checkout, ".worktrees", slug)
    File.directory?(path) ? File.realpath(path) : path
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end

  def assert_not_empty(collection, message = nil)
    assert_not(collection.empty?, message || "expected #{collection.inspect} not to be empty")
  end

  def assert_no_match(pattern, value, message = nil)
    assert_not(pattern.match?(value), message || "expected #{value.inspect} not to match #{pattern.inspect}")
  end

  def assert_told_accepted_then_committed_then_pushed(prompt)
    accepted_at = prompt =~ /accepted/i
    committed_at = prompt =~ /commit/i
    pushed_at = prompt =~ /push/i

    assert(accepted_at && committed_at && pushed_at,
           "expected \"accepted\", \"commit\" and \"push\" all in #{prompt.inspect}")
    assert(accepted_at < committed_at && committed_at < pushed_at,
           "expected accepted, then commit, then push, in that order, in #{prompt.inspect}")
  end

  def assert_path_survived(prompt, path)
    assert_includes(prompt, path)
    quoted = [ "'#{path}", "#{path}'" ].select { |form| prompt.include?(form) }
    assert_empty(quoted,
                 "the prompt wraps the path in quotes of its own, which this path would break")
  end

  # 5: asking git keeps this right for a linked worktree, where .git is a file rather than a
  # directory and the reports live in the main checkout.
  def report_directory
    shared_git_directory, = Open3.capture2("git", "-C", @repo, "rev-parse",
                                           "--path-format=absolute", "--git-common-dir")
    File.join(shared_git_directory.strip, "herdr")
  end

  def report_path(agent_name)
    File.join(report_directory, "#{agent_name}.md")
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
