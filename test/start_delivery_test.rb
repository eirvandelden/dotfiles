#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# start-delivery hands an accepted autonomous intent to a Claude coordinator: a pane inside Herdr,
# a background session outside it. A stub `claude`, a stub preflight and a stub hand-off script
# record what it starts, so no network, no login and no real session is involved.
class StartDeliveryTest < Minitest::Test
  SCRIPT = File.expand_path("../agents/.agents/skills/intent/scripts/start-delivery", __dir__)
  PERSONAL_ORIGIN = "git@github.com:eirvandelden/foo.git".freeze
  INTENT = <<~MD.freeze
    # Intent: Fix login

    Author: Etienne. Status: accepted (2026-10-01). Delivery: autonomous.

    ## Problem

    Login fails.
  MD

  def setup
    @root = File.realpath(Dir.mktmpdir)
    @home = File.join(@root, "home")
    @bin = File.join(@root, "bin")
    FileUtils.mkdir_p([ @home, @bin ])
    @repo = File.join(@root, "repo")
    build_repo(INTENT)
    install_claude_stub
    install_preflight_stub(exit_status: 0)
    install_hand_off_stub
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_outside_herdr_starts_a_background_claude_coordinator_in_the_worktree
    _, stderr, status = run_script

    assert_predicate(status, :success?, stderr)
    argv = claude_argv
    assert_equal("--bg", argv[0])
    assert_equal(%w[--model opus --name deliver-fix-login], argv[1, 4])
    prompt = argv.last
    assert_includes(prompt, "docs/changes/fix-login")
    assert_includes(prompt, @repo)
    assert_includes(prompt, "Delivery: autonomous")
    assert_includes(prompt, "Autonomous delivery")
    assert_includes(prompt, "never merge")
    assert_includes(prompt, "deliver-fix-login.md")
    assert_equal(@repo, File.realpath(File.read(claude_cwd_log).strip))
  end

  def test_outside_herdr_reports_how_to_attach_and_where_the_report_lands
    stdout, _, status = run_script
    handoff = File.join(@repo, ".git", "herdr", "deliver-fix-login-handoff.md")

    assert_predicate(status, :success?)
    assert(File.exist?(handoff), "expected #{handoff}")
    report = File.read(handoff)
    [ "Started background session 0a1b2c3d", "claude attach 0a1b2c3d", "claude logs 0a1b2c3d",
      "claude stop 0a1b2c3d", "deliver-fix-login.md", @repo ].each do |text|
      assert_includes(report, text)
      assert_includes(stdout, text)
    end
  end

  def test_inside_herdr_hands_the_deliver_stage_to_a_pane
    _, stderr, status = run_script(herdr: true)

    assert_predicate(status, :success?, stderr)
    assert_equal([ "deliver fix-login" ], File.readlines(hand_off_log, chomp: true))
    refute(File.exist?(claude_log), "claude must not start directly inside Herdr")
  end

  def test_refuses_an_intent_that_is_not_accepted
    build_repo(INTENT.sub("accepted (2026-10-01)", "draft"))

    assert_refused(/accepted/i)
  end

  def test_refuses_a_step_by_step_intent
    build_repo(INTENT.sub("autonomous", "step-by-step"))

    assert_refused(/autonomous/i)
  end

  def test_refuses_a_work_origin
    git("remote", "set-url", "origin", "git@github.com:somecompany/foo.git")

    assert_refused(/personal/i)
  end

  def test_refuses_an_uncommitted_intent
    File.write(File.join(@repo, "docs/changes/fix-login/intent.md"), "#{INTENT}\nExtra.\n")

    assert_refused(/commit/i)
  end

  def test_a_preflight_blocker_stops_before_claude_starts
    install_preflight_stub(exit_status: 1)

    stdout, = assert_refused(/preflight/i)

    assert_includes(stdout, "Blockers: github")
  end

  def test_never_passes_a_permission_bypass_flag
    run_script
    run_script(herdr: true)

    everything = File.read(claude_log) + File.read(hand_off_log)
    refute_match(/dangerously|permission-mode|skip-permissions/, everything)
  end

  def test_a_background_child_holding_stdout_does_not_hang_the_hand_off
    write_executable("claude", <<~SH)
      #!/bin/sh
      (sleep 30 &)
      echo "backgrounded"
    SH
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    _, stderr, status = run_script

    assert_predicate(status, :success?, stderr)
    assert_operator(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 10)
    assert(File.exist?(File.join(@repo, ".git", "herdr", "deliver-fix-login-handoff.md")))
  end

  def test_a_coordinator_start_that_never_ends_is_refused_after_the_deadline
    write_executable("claude", "#!/bin/sh\nexec sleep 30\n")
    @extra_env = { "START_DELIVERY_TIMEOUT" => "1" }

    _, stderr, status = run_script

    assert_equal(1, status.exitstatus)
    assert_match(/did not finish within 1s/, stderr)
  end

  def test_reads_the_session_id_from_the_real_claude_bg_output
    write_executable("claude", <<~'SH')
      #!/bin/sh
      echo "Starting background service…"
      echo "backgrounded · 8eb97c3b · adr-bg-smoke"
      echo "  claude agents             list sessions"
      echo "  claude attach 8eb97c3b    open in this terminal"
      echo "  claude logs 8eb97c3b      show recent output"
      echo "  claude stop 8eb97c3b      stop this session"
    SH

    stdout, = run_script

    assert_includes(stdout, "Attach: claude attach 8eb97c3b\n")
    assert_includes(stdout, "Stop: claude stop 8eb97c3b\n")
  end

  def test_inside_herdr_refuses_a_branch_that_differs_from_the_slug
    git("checkout", "-q", "-b", "ai/fix-login")

    _, stderr, status = run_script(herdr: true)

    assert_equal(1, status.exitstatus, stderr)
    assert_match(%r{current branch is ai/fix-login}, stderr)
    refute(File.exist?(hand_off_log), "no stage may start")
  end

  def test_outside_herdr_a_prefixed_branch_still_starts
    git("checkout", "-q", "-b", "ai/fix-login")

    _, stderr, status = run_script

    assert_predicate(status, :success?, stderr)
  end

  private

  def assert_refused(pattern)
    stdout, stderr, status = run_script

    assert_equal(1, status.exitstatus, "#{stdout}#{stderr}")
    assert_match(pattern, stderr)
    refute(File.exist?(claude_log), "Claude must not start")
    refute(File.exist?(hand_off_log), "no stage may start")
    [ stdout, stderr ]
  end

  def run_script(herdr: false)
    environment = {
      "HOME" => @home, "PATH" => "#{@bin}:#{ENV.fetch('PATH')}",
      "DELIVERY_PREFLIGHT" => File.join(@bin, "delivery-preflight"),
      "HERDR_SCRIPTS_DIR" => @bin, "HERDR_ENV" => nil, "HERDR_PANE_ID" => nil,
      "CLAUDE_LOG" => claude_log, "CLAUDE_CWD_LOG" => claude_cwd_log, "HAND_OFF_LOG" => hand_off_log
    }
    environment.merge!(@extra_env || {})
    environment.merge!("HERDR_ENV" => "1", "HERDR_PANE_ID" => "w1:p1") if herdr
    Open3.capture3(environment, SCRIPT, chdir: @repo)
  end

  def build_repo(intent)
    FileUtils.rm_rf(@repo)
    FileUtils.mkdir_p(File.join(@repo, "docs/changes/fix-login"))
    File.write(File.join(@repo, "docs/changes/fix-login/intent.md"), intent)
    git("init", "-q", "-b", "main")
    git("remote", "add", "origin", PERSONAL_ORIGIN)
    git("checkout", "-q", "-b", "fix-login")
    git("add", "-A")
    git("commit", "-q", "-m", "intent")
  end

  def git(*arguments)
    system("git", "-C", @repo, "-c", "user.email=t@example.com", "-c", "user.name=T",
           "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", *arguments) ||
      raise("git #{arguments.join(' ')} failed")
  end

  def install_claude_stub
    write_executable("claude", <<~SH)
      #!/bin/sh
      pwd > "$CLAUDE_CWD_LOG"
      for argument in "$@"; do printf '%s\\0' "$argument"; done >> "$CLAUDE_LOG"
      echo "Started background session 0a1b2c3d"
    SH
  end

  def install_preflight_stub(exit_status:)
    output = exit_status.zero? ? "No blockers." : "Blockers: github"
    write_executable("delivery-preflight", "#!/bin/sh\necho '#{output}'\nexit #{exit_status}\n")
  end

  def install_hand_off_stub
    write_executable("hand-off-plan.sh", "#!/bin/sh\necho \"$*\" >> \"$HAND_OFF_LOG\"\n")
  end

  def write_executable(name, content)
    path = File.join(@bin, name)
    File.write(path, content)
    FileUtils.chmod(0o755, path)
  end

  def claude_log = File.join(@root, "claude.log")
  def claude_cwd_log = File.join(@root, "claude-cwd.log")
  def hand_off_log = File.join(@root, "hand-off.log")
  def claude_argv = File.read(claude_log).split("\0")
end
