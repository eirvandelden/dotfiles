#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "isolated_git"

# Two scripts spawn a Claude worker inside the running Rex session: hand-off-plan.sh starts a stage
# (intent, plan, or implement) in a fresh block, start-review.sh asks a reviewer to look at this branch in
# a block beside the caller. A worker starts as the split command `claude --model <model>`; the script
# waits for the block's program_status to show `idle`, sends the prompt with `rex send -b <worker>`, then
# `rex send-key -b <worker> enter`. A stub `rex` records every command as one JSON line.
#
# Interface these tests pin, beyond the plan: REX_READY_TIMEOUT and REX_READY_POLL (seconds, default 60
# and 1) bound the readiness wait, so a test does not wait a minute; the row record, the report files and
# the intent record live in <git-common-dir>/rex/; ids of Rex blocks here carry no colon.
class RexWorkerScriptsTest < Minitest::Test
  SCRIPTS = File.expand_path("../rex/.config/rex/scripts", __dir__)
  HAND_OFF_PLAN = File.join(SCRIPTS, "hand-off-plan.sh")
  START_REVIEW = File.join(SCRIPTS, "start-review.sh")
  SKILLS_DIR = File.expand_path("../agents/.agents/skills", __dir__)
  WORKTREE_TOOLS_DIR = File.expand_path("../git/.config/git/worktree-tools", __dir__)
  CALLER = "blk1".freeze

  # Git runs with no hooks, a fixed identity and no signing, in any directory.
  #: (String directory, *String arguments) -> bool
  def self.run_git(directory, *arguments)
    system("git", "-C", directory, "-c", "core.hooksPath=/dev/null",
           "-c", "user.email=test@example.com", "-c", "user.name=Test",
           "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false",
           "-c", "tag.forceSignAnnotated=false", *arguments) ||
      raise("git #{arguments.join(' ')} failed")
  end

  #: (String directory, String branch) -> void
  def self.init_repository(directory, branch)
    run_git(directory, "init", "--quiet", "--initial-branch=#{branch}")
    run_git(directory, "commit", "--quiet", "--allow-empty", "-m", "initial")
  end

  # One repository per branch, with an empty commit, at the root of each copy.
  REPOSITORIES = Hash.new do |fixtures, branch|
    fixtures[branch] = GitFixture.new { |root| init_repository(root, branch) }
  end
  private_constant :REPOSITORIES

  # A repository on main at <copy>/repo whose bare origin at <copy>/origin holds main, and whose
  # .worktrees directory is excluded, so a worktree can be created from it.
  WITH_ORIGIN = GitFixture.new do |root|
    repo = File.join(root, "repo")
    origin = File.join(root, "origin")
    FileUtils.mkdir(repo)
    init_repository(repo, "main")
    system("git", "init", "--quiet", "--bare", "--initial-branch=main", origin, exception: true)
    run_git(repo, "remote", "add", "origin", origin)
    run_git(repo, "push", "--quiet", "origin", "main")
    File.write(File.join(repo, ".git", "info", "exclude"), ".worktrees\n")
  end
  private_constant :WITH_ORIGIN

  def setup
    @stub_bin = Dir.mktmpdir
    install_rex_stub
    install_git_recorder
    @extra_dirs = []
    repo_on("main")
  end

  def teardown
    FileUtils.rm_rf([ @stub_bin, *@extra_dirs ])
  end

  def test_stage_scripts_refuse_outside_rex
    [ [ HAND_OFF_PLAN, "plan", "some-change" ], [ START_REVIEW ] ].each do |script, *arguments|
      _, stderr, status = run_script(script, *arguments, rex_env: nil)

      assert_equal(1, status.exitstatus, script)
      assert_match(/rex/i, stderr, script)
      assert_empty(rex_calls, script)
    end
  end

  def test_a_hand_off_without_a_caller_block_is_refused_before_a_block_is_opened
    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change", caller_block: nil)

    assert_equal(1, status.exitstatus)
    assert_match(/rex/i, stderr)
    assert_empty(rex_calls)
  end

  def test_an_unrecognized_stage_name_is_refused
    _, stderr, status = run_script(HAND_OFF_PLAN, "bogus-stage", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/stage/i, stderr)
    assert_empty(rex_calls)
  end

  def test_the_usage_message_lists_intent_plan_and_implement
    _, stderr, = run_script(HAND_OFF_PLAN, "bogus-stage", "some-change")

    assert_match(/intent, plan, implement/, stderr)
    refute_match(/\bspec\b/i, stderr)
  end

  def test_refuses_a_missing_change_slug
    _, stderr, status = run_script(HAND_OFF_PLAN, "plan")

    assert_equal(1, status.exitstatus)
    assert_match(/slug|change/i, stderr)
    assert_empty(rex_calls)
  end

  def test_refuses_a_slug_that_looks_like_an_option
    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "--auto")

    assert_equal(1, status.exitstatus)
    assert_match(/slug/i, stderr)
    assert_empty(rex_calls)
  end

  def test_refuses_auto_for_the_intent_stage
    _, stderr, status = run_script(HAND_OFF_PLAN, "intent", "some-change", "--auto")

    assert_equal(1, status.exitstatus)
    assert_match(/auto/i, stderr)
    assert_empty(rex_calls)
  end

  def test_the_spec_stage_is_no_longer_recognised
    worktree_creatable!

    _, stderr, status = run_script(HAND_OFF_PLAN, "spec", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/stage/i, stderr)
    assert_empty(rex_calls)
  end

  def test_plan_stage_splits_a_claude_worker_with_the_prompt
    worktree_creatable!

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert(status.success?, stderr)
    split = split_calls.first
    assert_match(/-b #{CALLER}\b.*--split[= ]right\b.*-c #{Regexp.escape(worktree_path('some-change'))}\b/, split)
    assert_match(/ -- claude --model opus\z/, split)
    assert_includes(worker_prompt("plan"), "docs/changes/some-change/intent.md")
    assert_includes(worker_prompt("plan"), "worktree at #{worktree_path('some-change')}")
  end

  def test_handing_off_an_intent_stage_splits_a_block_below_the_caller
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")

    assert_equal(1, split_calls.size)
    assert_match(/-b #{CALLER}\b.*--split[= ]below\b.*-c #{Regexp.escape(worktree_path('some-change'))}\b/, split_calls.first)
  end

  def test_handing_off_a_plan_stage_splits_right_of_the_intent_block
    worktree_creatable!
    record_row("some-change", "blkI")

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_match(/-b blkI\b.*--split[= ]right/, split_calls.first)
  end

  def test_handing_off_an_implement_stage_splits_right_of_the_plan_block
    worktree_creatable!
    record_row("some-change", "blkI", "blkP")

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert_match(/-b blkP\b.*--split[= ]right/, split_calls.first)
    assert_empty(split_calls.grep(/-b blkI\b/))
  end

  def test_handing_off_a_plan_stage_falls_back_to_the_caller_when_the_row_end_is_gone
    worktree_creatable!
    record_row("some-change", "blkI")

    run_script(HAND_OFF_PLAN, "plan", "some-change", extra_env: { "STUB_GONE_BLOCKS" => "blkI" })

    assert_match(/-b #{CALLER}\b.*--split[= ]right/, split_calls.first)
  end

  def test_an_autonomous_delivery_builds_the_row_intent_plan_implement
    worktree_creatable!
    split_ids("blkA", "blkB", "blkC")

    run_script(HAND_OFF_PLAN, "intent", "some-change", extra_env: split_ids_env)
    run_script(HAND_OFF_PLAN, "plan", "some-change", "--auto", caller_block: "blkA", extra_env: split_ids_env)
    run_script(HAND_OFF_PLAN, "implement", "some-change", "--auto", caller_block: "blkA", extra_env: split_ids_env)

    anchors = split_calls.map { |call| call[/-b (\S+)/, 1] }
    directions = split_calls.map { |call| call[/--split[= ](\w+)/, 1] }
    assert_equal([ CALLER, "blkA", "blkB" ], anchors)
    assert_equal(%w[below right right], directions)
  end

  def test_a_linked_hand_off_script_finds_open_column_beside_its_real_path
    worktree_creatable!
    linked_dir = Dir.mktmpdir
    @extra_dirs << linked_dir
    link = File.join(linked_dir, "hand-off-plan.sh")
    File.symlink(HAND_OFF_PLAN, link)

    _, stderr, status = run_script(link, "plan", "some-change")

    assert(status.success?, stderr)
    refute_empty(split_calls)
  end

  def test_passes_the_model_per_stage
    worktree_creatable!

    { "intent" => "opus", "plan" => "opus", "implement" => "sonnet" }.each do |stage, model|
      run_script(HAND_OFF_PLAN, stage, "some-change")

      assert_match(/ -- claude --model #{model}\z/, split_calls.last, stage)
    end
    assert_empty(rex_calls.grep(/permission-mode/))
  end

  def test_each_stage_opens_exactly_one_block
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")

    assert_equal(1, split_calls.size)
  end

  def test_only_the_intent_stage_splits_below
    worktree_creatable!

    %w[intent plan implement].each { |stage| run_script(HAND_OFF_PLAN, stage, "some-change") }

    assert_equal(3, split_calls.size)
    assert_match(/--split[= ]below/, split_calls.first)
    assert(split_calls.drop(1).all? { |call| call.match?(/--split[= ]right/) }, split_calls.inspect)
  end

  def test_names_the_worker_stage_dash_block_id
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert_call(/\Ablock rename\b.* blkW implement-blkW\z/)
  end

  def test_the_worker_block_is_recorded_in_the_row_record
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")
    run_script(HAND_OFF_PLAN, "implement", "some-change")

    assert_equal(%w[blkW blkW], row_record("some-change"))
  end

  def test_report_file_is_empty_before_the_worker_starts
    worktree_creatable!
    stale = report_path("plan-blkW")
    FileUtils.mkdir_p(File.dirname(stale))
    File.write(stale, "an earlier worker's notes\n")

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(report_state_at_prompt, "plan-blkW empty")
  end

  def test_prompt_is_sent_after_the_worker_is_ready
    worktree_creatable!
    status_sequence("working", "working", "idle")

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert(status.success?, stderr)
    send_index = rex_calls.index { |call| call.match?(/\Asend\b.* -b blkW\b/) }
    refute_nil(send_index, rex_calls.inspect)
    assert_operator(rex_calls.first(send_index).count { |call| call.include?("program_status") }, :>=, 3)
    key_index = rex_calls.index { |call| call.match?(/\Asend-key\b.* -b blkW\b.*enter/) }
    assert_operator(key_index, :>, send_index)
  end

  def test_ready_wait_finds_the_idle_agent_record_among_several
    worktree_creatable!
    records = [ { state: "working", app: "zsh" }, { state: "idle", app: "claude-code" } ]

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change",
                                   extra_env: { "STUB_RECORDS_JSON" => JSON.generate(records) })

    assert(status.success?, stderr)
    refute_nil(worker_prompt("plan"), "the agent record is idle, so the prompt is sent")

    only_shell = [ { state: "idle", app: "zsh" } ]
    _, stderr, status = run_script(HAND_OFF_PLAN, "implement", "some-change",
                                   extra_env: { "STUB_RECORDS_JSON" => JSON.generate(only_shell),
                                                "REX_READY_TIMEOUT" => "1" })

    assert_equal(1, status.exitstatus)
    assert_match(/ready|idle|timed out/i, stderr)
  end

  def test_unready_worker_fails_the_hand_off
    worktree_creatable!
    status_sequence("working")

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change",
                                   extra_env: { "REX_READY_TIMEOUT" => "1" })

    assert_equal(1, status.exitstatus)
    assert_match(/ready|idle|timed out/i, stderr)
    assert_empty(rex_calls.grep(/\Asend\b/))
    assert_empty(rex_calls.grep(/\Asend-key\b/))
    assert_call(/\Ablock close\b.* blkW\b/)
  end

  def test_stub_worker_report_reaches_the_coordinator
    worktree_creatable!

    stdout, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert(status.success?, stderr)
    path = worker_prompt("plan")[%r{\S*/rex/plan-blkW\.md}]
    refute_nil(path, "the prompt does not name the report file")
    assert_includes(stdout, path)
    prompt = worker_prompt("plan")
    assert_match(/rex send -b #{CALLER}\s/, prompt)
    assert_match(/rex send-key\b.*enter/, prompt)
    assert_includes(prompt, "Plan ready:")

    # The stub worker does what the prompt says: write the report, then tell the coordinator.
    File.write(path, "Plan ready: #{path}\nwhat plan.md decided\n")
    system(stub_env, File.join(@stub_bin, "rex"), "send", "-b", CALLER, "Plan ready: #{path}", exception: true)
    system(stub_env, File.join(@stub_bin, "rex"), "send-key", "-b", CALLER, "enter", exception: true)

    told = raw_calls.select { |call| call.first == "send" && option_of(call, "-b") == CALLER }
    assert_equal(1, told.size, rex_calls.inspect)
    assert_equal("Plan ready: #{path}", told.first.last)
    assert_match(/^Plan ready: /, File.read(path))
  end

  def test_the_worker_is_told_to_close_its_own_block_after_reporting
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")
    prompt = worker_prompt("plan")

    assert_includes(prompt, "rex block close $REX_BLOCK")
    assert_includes(prompt, "not the coordinator's id above")
  end

  def test_the_worker_is_told_where_to_report_and_who_to_tell
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(worker_prompt("plan"), report_path("plan-blkW"))
    assert_includes(worker_prompt("plan"), "block #{CALLER}")
    assert(File.directory?(File.dirname(report_path("plan-blkW"))),
           "the worker cannot write a report into a directory that is not there")
  end

  def test_each_stage_worker_retries_a_busy_coordinator_but_gives_up_eventually
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(worker_prompt("plan"), "at most twelve times")
    refute_match(/initiator/i, worker_prompt("plan"))
  end

  def test_the_plan_worker_reads_only_intent_md
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_includes(worker_prompt("plan"), "docs/changes/some-change/intent.md")
    refute_match(/\bspec\b/i, worker_prompt("plan"))
  end

  def test_the_intent_worker_is_told_to_invoke_the_intent_skill_and_not_commit_intent_md
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")
    prompt = worker_prompt("intent")

    assert_includes(prompt, "intent skill")
    assert_includes(prompt, "no upstream artifact")
    assert_match(/leave intent\.md uncommitted/, prompt)
    refute_includes(prompt, "git push -u origin HEAD")
  end

  def test_the_plan_worker_commits_intent_and_plan_then_pushes
    worktree_creatable!

    [ [], [ "--auto" ] ].each do |options|
      run_script(HAND_OFF_PLAN, "plan", "some-change", *options)
      prompt = worker_prompt("plan")

      assert_includes(prompt, "committed intent.md and plan.md")
      assert_operator(prompt.index("committed intent.md and plan.md"), :<, prompt.index("git push -u origin HEAD"))
    end
  end

  def test_the_implement_worker_is_told_to_push_when_done
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")
    prompt = worker_prompt("implement")

    assert_includes(prompt, "docs/changes/some-change/plan.md")
    assert_includes(prompt, "push the branch (git push -u origin HEAD)")
    assert_includes(prompt, "never use --no-verify")
    assert_includes(prompt, "what you did, and anything you could not finish")
  end

  def test_an_auto_worker_runs_the_skill_in_auto_mode_without_waiting_for_accepted
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change", "--auto")
    run_script(HAND_OFF_PLAN, "implement", "some-change", "--auto")

    %w[plan implement].each { |stage| assert_match(/with the auto argument/, worker_prompt(stage), stage) }
    refute_includes(worker_prompt("plan"), "literal word")
    assert_match(/do not wait for .*accepted/i, worker_prompt("plan"))
    assert_includes(worker_prompt("plan"), "Do not start the next stage")
    assert_includes(worker_prompt("implement"), "Decision needed:")
  end

  def test_without_auto_the_prompt_has_no_auto_wording
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    refute_includes(worker_prompt("plan"), "auto argument")
    refute_includes(worker_prompt("plan"), "Decision needed:")
    assert_includes(worker_prompt("plan"), "literal word")
  end

  def test_the_intent_and_plan_workers_are_given_the_coordinator_block_id
    worktree_creatable!

    %w[intent plan].each do |stage|
      run_script(HAND_OFF_PLAN, stage, "some-change")
      prompt = worker_prompt(stage)

      refute_match(/hand-off-plan\.sh/, prompt, stage)
      assert_includes(prompt, "Your coordinator's block id is #{CALLER}", stage)
      assert_includes(prompt, "REX_BLOCK set to that id", stage)
    end
  end

  def test_the_implement_worker_is_not_told_to_start_a_next_stage
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "implement", "some-change")

    refute_match(/hand-off-plan\.sh/, worker_prompt("implement"))
    refute_match(/coordinator's block id/, worker_prompt("implement"))
  end

  def test_the_intent_worker_coordinates_an_autonomous_delivery_itself
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "intent", "some-change")
    prompt = worker_prompt("intent")

    assert_includes(prompt, "Delivery: autonomous")
    assert_includes(prompt, "Delivery done:")
    assert_match(%r{account file path into \S*/rex/intent-\S+\.md}, prompt)
    condition = prompt.index("Unless intent.md records Delivery: autonomous")
    refute_nil(condition)
    assert_operator(condition, :<, prompt.index("Intent ready:"))
    assert_operator(condition, :<, prompt.index("rex block close"))
  end

  def test_only_the_intent_worker_hears_about_autonomous_delivery
    worktree_creatable!

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    refute_includes(worker_prompt("plan"), "Delivery done:")
  end

  def test_each_accepting_skill_chains_once_to_its_next_stage_with_the_coordinator_id
    { "intent" => "plan", "plan" => "implement" }.each do |stage, next_stage|
      skill = File.read(File.join(SKILLS_DIR, stage, "SKILL.md"))
      chain = "COORDINATOR=<coordinator> ~/.agents/bin/hand-off-plan #{next_stage} '<slug>'"

      assert_equal(1, skill.scan(chain).size, "#{stage}/SKILL.md must chain to #{next_stage} with the coordinator id")
      assert_equal(1, skill.scan("bin/hand-off-plan #{next_stage}").size, "#{stage}/SKILL.md must chain to #{next_stage} exactly once")
    end
  end

  def test_still_resolves_the_caller_to_the_main_checkout_from_a_linked_worktree
    worktree_creatable!
    main_checkout = @repo
    @repo = linked_worktree

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_match(/-c #{Regexp.escape(worktree_path('some-change', checkout: main_checkout))}\b/, split_calls.first)
  end

  def test_still_resolves_the_caller_to_the_submodule_checkout
    worktree_creatable!
    submodule = add_submodule("child")
    @repo = submodule

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_match(/-c #{Regexp.escape(worktree_path('some-change', checkout: submodule))}\b/, split_calls.first)
  end

  def test_survives_an_awkward_repository_path_intact
    @repo = repo_on("main", inside: "o'brien's work files")
    add_origin_in_place

    run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_path_survived(worker_prompt("plan"), report_path("plan-blkW"))
  end

  def test_stops_before_spawning_anything_when_the_report_directory_cant_be_created
    worktree_creatable!
    git_directory = File.join(@repo, ".git")
    FileUtils.chmod(0o500, git_directory)

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/report/i, stderr)
    assert_empty(rex_calls)
  ensure
    FileUtils.chmod(0o700, git_directory)
  end

  def test_handing_off_outside_a_repository_is_refused_before_a_block_is_opened
    @repo = Dir.mktmpdir
    @extra_dirs << @repo

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/repository/i, stderr)
    assert_empty(rex_calls)
  end

  def test_handing_off_reuses_an_existing_worktree_on_the_matching_branch
    worktree_creatable!
    worktree = File.join(@repo, ".worktrees", "some-change")
    git("worktree", "add", "--quiet", worktree, "-b", "some-change", "origin/main")

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert(status.success?, stderr)
    assert_match(/-c #{Regexp.escape(File.realpath(worktree))}\b/, split_calls.first)
  end

  def test_handing_off_refuses_when_the_worktree_exists_on_a_different_branch
    worktree_creatable!
    worktree = File.join(@repo, ".worktrees", "some-change")
    git("worktree", "add", "--quiet", worktree, "-b", "unrelated-branch", "origin/main")

    _, stderr, status = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_equal(1, status.exitstatus)
    assert_match(/some-change/, stderr)
    assert_empty(rex_calls)
  end

  def test_handing_off_reports_where_the_work_went_and_where_its_report_lands
    worktree_creatable!

    stdout, = run_script(HAND_OFF_PLAN, "plan", "some-change")

    assert_equal(1, stdout.lines.count, stdout)
    assert_match(/plan-blkW/, stdout)
  end

  def test_reviewing_records_the_reviewer_block_for_the_change
    @repo = linked_worktree

    _, stderr, status = run_script(START_REVIEW)

    assert(status.success?, stderr)
    assert_equal(%w[blkW], row_record("handed-over"))
  end

  def test_reviewing_without_a_change_folder_records_no_block
    _, stderr, status = run_script(START_REVIEW)

    assert(status.success?, stderr)
    assert_empty(Dir.glob(File.join(report_directory, "stage-panes-*")))
  end

  def test_opens_a_reviewer_column_right_of_the_caller_without_taking_the_screen
    _, stderr, status = run_script(START_REVIEW)

    assert(status.success?, stderr)
    assert_match(/-b #{CALLER}\b.*--split[= ]right\b.*-c #{Regexp.escape(File.realpath(@repo))}\b.*--focus=false/,
                 split_calls.first)
    assert_match(/ -- claude --model opus\z/, split_calls.first)
  end

  def test_reviewing_splits_right_of_the_last_stage_block_of_the_change
    @repo = linked_worktree
    record_row("handed-over", "blkI", "blkP")

    _, stderr, status = run_script(START_REVIEW)

    assert(status.success?, stderr)
    assert_match(/-b blkP\b.*--split[= ]right/, split_calls.first)
  end

  def test_reviewing_a_feature_branch_without_a_row_record_splits_right_of_the_caller
    git("checkout", "--quiet", "-b", "feature")

    _, stderr, status = run_script(START_REVIEW)

    assert(status.success?, stderr)
    assert_match(/-b #{CALLER}\b.*--split[= ]right/, split_calls.first)
    assert_equal(%w[blkW], row_record("feature"))
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

  def test_reviewing_outside_a_repository_is_refused_before_a_block_is_opened
    @repo = Dir.mktmpdir
    @extra_dirs << @repo

    _, stderr, status = run_script(START_REVIEW)

    assert_equal(1, status.exitstatus)
    assert_match(/repository/i, stderr)
    assert_empty(rex_calls)
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

  def test_the_reviewer_commits_through_commit_review_and_pushes_only_when_it_exits_0
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "review/scripts/commit-review")
    assert_match(/only when commit-review exits 0/, reviewer_prompt)
    assert_includes(reviewer_prompt, "never use --no-verify")
    assert_match(/leave review\.md uncommitted/, reviewer_prompt)
    assert_operator(reviewer_prompt.index("git push -u origin HEAD"), :>, reviewer_prompt.index("commit-review"))
  end

  def test_the_reviewer_pings_the_caller_block_that_asked_for_the_review
    run_script(START_REVIEW)

    assert_match(/rex send -b #{CALLER}\b/, reviewer_prompt)
    assert_match(/rex send-key\b.*enter/, reviewer_prompt)
    assert_match(/Review (clean|ready):/, reviewer_prompt)
  end

  def test_the_reviewer_retries_a_busy_caller_but_gives_up_eventually
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "at most twelve times")
    assert_match(/leave (your|this|the) block open/i, reviewer_prompt)
  end

  def test_the_reviewer_closes_its_own_block_not_the_callers
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "rex block close $REX_BLOCK")
    assert_match(/not the caller's id/, reviewer_prompt)
    assert_operator(reviewer_prompt.index("rex block close"), :>, reviewer_prompt.index("Review ready:"))
  end

  def test_the_reviewer_runs_deliver_check_after_commit_review
    run_script(START_REVIEW)

    assert_match(%r{deliver/scripts/deliver --check}, reviewer_prompt)
    assert_operator(reviewer_prompt.index("deliver --check"), :>, reviewer_prompt.index("commit-review"))
    assert_operator(reviewer_prompt.index("deliver --check"), :<, reviewer_prompt.index("Review ready:"))
    assert_includes(reviewer_prompt, "Review clean:")
  end

  def test_the_reviewer_reads_intent_md_and_plan_md
    run_script(START_REVIEW)

    assert_includes(reviewer_prompt, "intent.md and plan.md")
    refute_match(/spec\.md/, reviewer_prompt)
  end

  def test_reviewing_reports_where_the_findings_will_land
    stdout, = run_script(START_REVIEW)

    assert_includes(stdout, "docs/changes")
    assert_includes(stdout, "review.md")
  end

  def test_an_unready_reviewer_fails_the_review
    status_sequence("working")

    _, stderr, status = run_script(START_REVIEW, extra_env: { "REX_READY_TIMEOUT" => "1" })

    assert_equal(1, status.exitstatus)
    assert_match(/ready|idle|timed out/i, stderr)
    assert_empty(rex_calls.grep(/\Asend\b/))
  end

  private

  def track_origin_head_on(branch)
    git("remote", "add", "origin", "git@example.com:someone/repo.git")
    git("update-ref", "refs/remotes/origin/#{branch}", "HEAD")
    git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/#{branch}")
  end

  # Replaces the repository of setup with a copy that has an origin and an excluded .worktrees.
  def worktree_creatable!
    FileUtils.rm_rf(@repo)
    copy = WITH_ORIGIN.copy
    @extra_dirs << copy
    @repo = File.join(copy, "repo")
  end

  # The same, for a repository that must stay where it is.
  def add_origin_in_place
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
    return @repo = REPOSITORIES[branch].copy.tap { |copy| @extra_dirs << copy } unless inside

    @repo = Dir.mktmpdir(nil, awkward_parent(inside))
    @extra_dirs << @repo
    self.class.init_repository(@repo, branch)
    @repo
  end

  def git(*arguments)
    self.class.run_git(@repo, *arguments)
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

  def rex_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true).map { |line| JSON.parse(line).reject { |word| word == "-s" || word == "S1" }.join(" ") } : []
  end

  def split_calls
    rex_calls.grep(/\Asplit\b/)
  end

  # Every recorded call as its argument array, without the session flag.
  def raw_calls
    lines = File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
    lines.map { |line| JSON.parse(line).reject { |word| word == "-s" || word == "S1" } }
  end

  def option_of(call, flag)
    call.each_cons(2).find { |name, _| name == flag }&.last
  end

  def assert_call(pattern)
    assert(rex_calls.any? { |call| call.match?(pattern) }, "no rex call matches #{pattern.inspect} in #{rex_calls.inspect}")
  end

  # The text sent to the worker block with `rex send -b <worker>`: the last argument of that call.
  def prompt_sent_to(block)
    lines = File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
    calls = lines.map { |line| JSON.parse(line) }
    send_call = calls.find { |call| call.first == "send" && call.each_cons(2).any? { |flag, id| flag == "-b" && id == block } }
    send_call&.last
  end

  def worker_prompt(_stage)
    prompt_sent_to("blkW") || prompt_sent_to("blkV")
  end

  def reviewer_prompt
    prompt_sent_to("blkW")
  end

  def record_row(slug, *lines)
    FileUtils.mkdir_p(report_directory)
    File.write(File.join(report_directory, "stage-panes-#{slug}"), lines.map { |line| "#{line}\n" }.join)
  end

  def row_record(slug)
    path = File.join(report_directory, "stage-panes-#{slug}")
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  def split_ids(*ids)
    @split_ids_file = File.join(@stub_bin, "split-ids")
    File.write(@split_ids_file, ids.map { |id| "#{id}\n" }.join)
  end

  def split_ids_env
    { "STUB_SPLIT_IDS" => @split_ids_file }
  end

  # program_status answers, one per call; the last repeats.
  def status_sequence(*states)
    @status_file = File.join(@stub_bin, "status-sequence")
    File.write(@status_file, states.map { |state| "#{state}\n" }.join)
  end

  def worktree_path(slug, checkout: @repo)
    path = File.join(checkout, ".worktrees", slug)
    File.directory?(path) ? File.realpath(path) : path
  end

  def assert_path_survived(prompt, path)
    assert_includes(prompt, path)
    quoted = [ "'#{path}", "#{path}'" ].select { |form| prompt.include?(form) }
    assert_empty(quoted, "the prompt wraps the path in quotes of its own, which this path would break")
  end

  # Asking git keeps this right for a linked worktree, where .git is a file rather than a directory
  # and the reports live in the main checkout.
  def report_directory
    shared_git_directory, = Open3.capture2("git", "-C", @repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
    File.join(shared_git_directory.strip, "rex")
  end

  def report_path(worker_name)
    File.join(report_directory, "#{worker_name}.md")
  end

  def report_state_log
    @report_state_log ||= File.join(@stub_bin, "report-state.log")
  end

  def report_state_at_prompt
    File.exist?(report_state_log) ? File.readlines(report_state_log, chomp: true) : []
  end

  def git_call_log
    @git_call_log ||= File.join(@stub_bin, "git-calls.log")
  end

  def git_calls
    File.exist?(git_call_log) ? File.readlines(git_call_log, chomp: true) : []
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def stub_env
    { "REX_CALL_LOG" => call_log, "REPORT_DIR" => report_directory, "REPORT_STATE_LOG" => report_state_log,
      "STUB_STATUS_FILE" => @status_file.to_s }
  end

  def run_script(script, *arguments, rex_env: "S1", caller_block: CALLER, extra_env: {})
    environment = stub_env.merge(
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "GIT_CALL_LOG" => git_call_log,
      "REX_SESSION" => rex_env,
      "REX_BLOCK" => caller_block,
      "REX_READY_TIMEOUT" => "5",
      "REX_READY_POLL" => "0.05",
      "WORKTREE_TOOLS_DIR" => WORKTREE_TOOLS_DIR,
      "CLAUDE_SKILLS_DIR" => SKILLS_DIR
    )
    Open3.capture3(environment.merge(extra_env), script, *arguments, chdir: @repo)
  end

  # A `rex` that logs each call as a JSON array. split answers the creation JSON with a block id from
  # STUB_SPLIT_IDS, else blkV (below) or blkW; it fails for an anchor listed in STUB_GONE_BLOCKS.
  # `block ls` lists the live blocks. program_status answers from STUB_STATUS_FILE (default idle).
  # The first send to a block logs the state of that block's report files.
  def install_rex_stub
    stub = File.join(@stub_bin, "rex")
    File.write(stub, <<~'RUBY')
      #!/usr/bin/env -S ruby --disable-gems
      require "json"

      File.open(ENV.fetch("REX_CALL_LOG"), "a") { |file| file.puts(JSON.generate(ARGV)) }
      words = ARGV.reject { |word| word == "-s" || word == "S1" }
      option = ->(flag) { ARGV.each_cons(2).find { |name, _| name == flag }&.last }
      gone = ENV["STUB_GONE_BLOCKS"].to_s.split
      puts_json = ->(data) { puts JSON.generate(data) }

      if words.first == "split"
        exit 1 if gone.include?(option.call("-b"))
        queue = ENV["STUB_SPLIT_IDS"]
        if queue && File.exist?(queue) && !File.zero?(queue)
          lines = File.readlines(queue, chomp: true)
          id = lines.shift
          File.write(queue, lines.map { |line| "#{line}\n" }.join)
        else
          id = ARGV.join(" ").match?(/--split[= ]below/) ? "blkV" : "blkW"
        end
        puts_json.call(anchor_id: option.call("-b"), block_ids: [ id ], split_ids: [ "s1" ], revision: 1)
      elsif words.first(2) == %w[block ls]
        live = (%w[blk1 blkV blkW blkA blkB blkC blkI blkP] - gone)
        puts_json.call(blocks: live.map { |id| { block_id: id, label: "shell", flavor: "shell" } })
      elsif ARGV.include?("block.method")
        request = JSON.parse(ARGV[ARGV.index("block.method") + 1])
        if request["method"] == "program_status" && ENV["STUB_RECORDS_JSON"]
          puts ENV["STUB_RECORDS_JSON"].then { |json| JSON.generate(records: JSON.parse(json)) }
          exit
        end
        state = "idle"
        status_file = ENV["STUB_STATUS_FILE"].to_s
        if request["method"] == "program_status" && File.file?(status_file) && !File.zero?(status_file)
          lines = File.readlines(status_file, chomp: true)
          state = lines.first
          File.write(status_file, lines.drop(1).map { |line| "#{line}\n" }.join) if lines.size > 1
        end
        puts_json.call(records: [ { state: state, app: "claude-code" } ])
      elsif words.first == "send" && ARGV.include?("-b")
        id = option.call("-b")
        Dir[File.join(ENV.fetch("REPORT_DIR"), "*-#{id}.md")].each do |path|
          state = File.zero?(path) ? "empty" : "holds-something"
          File.open(ENV.fetch("REPORT_STATE_LOG"), "a") { |file| file.puts("#{File.basename(path, '.md')} #{state}") }
        end
      end
    RUBY
    FileUtils.chmod(0o755, stub)
  end
end
