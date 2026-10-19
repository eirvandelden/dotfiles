#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "timeout"
require "tmpdir"
require_relative "isolated_git"

# worktree-sweep removes merged worktrees of the repository it runs in. It shells out to git, gh
# (PR state) and, inside herdr, worktree-pane; gh and herdr are stubbed.
class WorktreeSweepTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-sweep", __dir__)
  DEADLINE = 20

  def setup
    @enclosing = File.realpath(Dir.mktmpdir)
    @stub_bin = File.join(@enclosing, "bin")
    FileUtils.mkdir_p(@stub_bin)
    install_gh_stub
    install_git_recorder
    @origin, @repo = origin_and_clone
  end

  def teardown
    stop_waiter
    stop_hanging_stubs if @missed_deadline
    FileUtils.rm_rf(@enclosing)
  end

  def test_removes_a_merged_clean_worktree_and_its_branch
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")

    _, stderr, status = run_script

    assert(status.success?, stderr)
    refute(File.directory?(merged))
    refute(branch?("merged-branch"))
  end

  def test_removes_a_branch_pushed_under_its_own_name_once_origin_main_contains_it
    pushed = add_worktree("pushed")
    commit(pushed, "pushed work")
    git(pushed, "push", "--quiet", "-u", "origin", "pushed")
    git(@repo, "push", "--quiet", "origin", "pushed:main")
    advance_origin_main

    _, stderr, status = run_script

    assert(status.success?, stderr)
    refute(File.directory?(pushed))
    refute(branch?("pushed"))
  end

  def test_keeps_a_never_pushed_branch_that_origin_main_moved_past
    never_pushed = add_worktree("never-pushed")
    advance_origin_main

    _, stderr, status = run_script

    assert(status.success?, stderr)
    assert(File.directory?(never_pushed))
    assert(branch?("never-pushed"))
  end

  def test_keeps_the_worktree_it_runs_in
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")

    _, stderr, status = run_script(chdir: merged)

    assert(status.success?, stderr)
    assert(File.directory?(merged))
  end

  def test_keeps_the_worktree_it_runs_in_from_one_of_its_subdirectories
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    FileUtils.mkdir_p(File.join(merged, "sub"))
    write_gh_states("merged-branch" => "MERGED")

    _, stderr, status = run_script(chdir: File.join(merged, "sub"))

    assert(status.success?, stderr)
    assert(File.directory?(merged))
  end

  def test_ignores_git_dir_and_git_index_file_from_a_hook_environment
    dirty = add_worktree("dirty-branch")
    commit(dirty, "more work")
    File.write(File.join(dirty, "scratch.txt"), "uncommitted")
    write_gh_states("dirty-branch" => "MERGED", "main" => "MERGED")
    hook_environment = {
      "GIT_DIR" => File.join(@repo, ".git"),
      "GIT_INDEX_FILE" => File.join(@repo, ".git", "index"),
      "GIT_WORK_TREE" => @repo
    }

    _, stderr, status = run_script(extra_env: hook_environment)

    assert(status.success?, stderr)
    assert(File.directory?(dirty), "a dirty worktree must survive; GIT_DIR made it look clean")
    assert_empty(git_calls.grep(/\Aworktree remove /), "the sweep tried to remove a worktree")
  end

  def test_fetches_the_default_branch_before_it_sweeps
    pushed = add_worktree("pushed")
    commit(pushed, "pushed work")
    git(pushed, "push", "--quiet", "-u", "origin", "pushed")
    merge_into_origin_main_from_elsewhere("pushed")
    advance_origin_main

    run_script

    assert(git_calls.any? { |call| call.match?(/\Afetch .*origin main\z/) }, git_calls.join("\n"))
    refute(File.directory?(pushed))
  end

  # A pull in the main checkout reads FETCH_HEAD between its fetch and its merge; a background
  # sweep that rewrote it there would make that pull merge origin/main instead of its upstream.
  def test_leaves_the_fetch_head_of_the_main_checkout_alone
    git(@repo, "fetch", "--quiet", "origin")
    fetch_head = File.join(@repo, ".git", "FETCH_HEAD")
    before = File.read(fetch_head)
    advance_origin_main

    run_script

    assert(git_calls.any? { |call| call.match?(/\Afetch .*origin main\z/) }, git_calls.join("\n"))
    assert_equal(before, File.read(fetch_head))
  end

  def test_still_sweeps_when_the_fetch_fails
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")
    git(@repo, "remote", "set-url", "origin", File.join(@enclosing, "gone.git"))

    _, stderr, status = run_script

    assert(status.success?, stderr)
    refute(File.directory?(merged))
  end

  # A background sweep holds the repository's lock; a call that never returns would keep it.
  def test_gives_up_on_a_gh_call_that_hangs
    pushed = add_worktree("pushed")
    commit(pushed, "pushed work")
    git(pushed, "push", "--quiet", "-u", "origin", "pushed")
    merge_into_origin_main_from_elsewhere("pushed")
    advance_origin_main
    FileUtils.touch(gh_hang_file)

    _, stderr, status = run_script_within_deadline(extra_env: time_limit_env)

    assert(status.success?, stderr)
    refute(File.directory?(pushed), "the ancestor rule still applies when gh gives no answer")
  end

  def test_gives_up_on_a_fetch_that_hangs
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")
    git(@repo, "remote", "set-url", "origin", "ssh://git.example.invalid/repo.git")
    install_hanging_ssh
    env = time_limit_env.merge("GIT_SSH_COMMAND" => File.join(@stub_bin, "hanging-ssh"))

    _, stderr, status = run_script_within_deadline(extra_env: env)

    assert(status.success?, stderr)
    refute(File.directory?(merged))
  end

  def test_stopping_hanging_stubs_spares_processes_outside_them
    install_hanging_ssh
    stub = Process.spawn(script_environment, File.join(@stub_bin, "hanging-ssh"), pgroup: true)
    bystander = Process.spawn("sleep", "30", pgroup: stub)

    stop_hanging_stubs

    assert_equal(stub, Process.wait(stub), "the stub should exit")
    assert_nil(exited_within(bystander, 1), "the bystander must keep running")
  ensure
    reap(bystander)
  end

  # teardown removes the folder right after the release; a stub that missed the release file
  # between two polls must still end instead of hanging for ten minutes.
  def test_hanging_stubs_end_once_their_folder_is_removed
    install_hanging_ssh
    FileUtils.touch(gh_hang_file)
    stubs = %w[hanging-ssh gh].map { |name| Process.spawn(script_environment, File.join(@stub_bin, name)) }
    sleep 0.5

    FileUtils.rm_rf(@enclosing)

    # exited_within reaps a stub that ended, so only the ones left may still be signalled.
    stubs.reject! { |stub| exited_within(stub, 5) }
    assert_empty(stubs, "a stub kept hanging")
  ensure
    stubs&.each { |stub| reap(stub) }
  end

  def test_writes_nothing_to_stdout
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")

    stdout, = run_script

    assert_empty(stdout)
  end

  def test_the_default_branch_comes_from_origin_head
    git(@repo, "remote", "set-head", "origin", "main")
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")

    _, stderr, status = run_script

    assert(status.success?, stderr)
    refute(File.directory?(merged))
  end

  def test_refuses_outside_a_git_repository
    _, stderr, status = run_script(chdir: @enclosing)

    refute(status.success?)
    assert_match(/not inside a git repository/, stderr)
  end

  def test_waits_for_a_running_sweep_to_release_the_lock
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")

    with_lock_held do
      stdin, stdout, stderr, waiter = Open3.popen3(script_environment, "ruby", SCRIPT, chdir: @repo)
      [ stdin, stdout, stderr ].each(&:close)
      @waiter = waiter
      # Its last git call before it takes the lock finds the lock file's directory.
      wait_until("the sweep to reach the lock") { git_calls.any? { |call| call.include?("--git-common-dir") } }
      sleep 0.5
      assert(waiter.alive?, "the sweep must still be waiting")
      assert_empty(git_calls.grep(/\Afetch /), "the sweep must not fetch while the lock is held")
      assert(File.directory?(merged), "the sweep must wait while the lock is held")
    end

    wait_until("the waiting sweep to finish", deadline: 60) { !@waiter.alive? }
    refute(File.directory?(merged))
  end

  def test_with_detach_it_returns_before_the_sweep_finishes_and_prints_nothing
    merged = add_worktree("merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")

    with_lock_held do
      stdout, stderr, status = Timeout.timeout(DEADLINE) { run_script("--detach") }

      assert(status.success?, stderr)
      assert_empty(stdout)
      assert_empty(stderr)
      assert(File.directory?(merged), "the detached sweep must still be waiting for the lock")
    end

    wait_until("the detached sweep to remove the worktree", deadline: 60) { !File.exist?(merged) }
    wait_until("the detached sweep to release the lock") { lock_free? }
    refute(branch?("merged-branch"))
  end

  def test_with_detach_it_creates_the_lock_file_before_returning
    refute(File.exist?(lock_file))

    _, stderr, status = Timeout.timeout(DEADLINE) { run_script("--detach") }

    assert(status.success?, stderr)
    assert(File.exist?(lock_file), "the lock file must exist as soon as the hook command returns")
    wait_until("the detached sweep to release the lock", deadline: 60) { lock_free? }
  end

  private

  # A failed assertion inside the lock block releases the lock, and the waiting sweep would
  # carry on while teardown deletes its directories.
  def stop_waiter
    return unless @waiter&.alive?

    Process.kill("KILL", @waiter.pid)
    @waiter.join
  end

  def lock_free?
    File.open(lock_file, File::RDWR) do |file|
      return false unless file.flock(File::LOCK_EX | File::LOCK_NB)

      file.flock(File::LOCK_UN)
      true
    end
  end

  def lock_file
    File.join(@repo, ".git", "worktree-sweep.lock")
  end

  def with_lock_held
    File.open(lock_file, File::RDWR | File::CREAT) do |file|
      file.flock(File::LOCK_EX)
      yield
    end
  end

  def reap(pid)
    Process.kill("KILL", pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD, TypeError
    nil
  end

  def exited_within(pid, seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    loop do
      return pid if Process.wait(pid, Process::WNOHANG)
      return nil if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def wait_until(what, deadline: DEADLINE)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + deadline
    until yield
      flunk("timed out waiting for #{what}") if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def advance_origin_main
    extra_clone = File.join(@enclosing, "advance-#{rand(1_000_000)}")
    hookless_git(@enclosing, "clone", "--quiet", @origin, extra_clone)
    commit(extra_clone, "origin moved on #{rand(1_000_000)}")
    hookless_git(extra_clone, "push", "--quiet", "origin", "main")
  end

  def merge_into_origin_main_from_elsewhere(branch)
    other = File.join(@enclosing, "merger-#{branch}")
    hookless_git(@enclosing, "clone", "--quiet", @origin, other)
    git(other, "merge", "--quiet", "--ff-only", "origin/#{branch}")
    hookless_git(other, "push", "--quiet", "origin", "main")
  end

  def origin_and_clone
    origin = File.join(@enclosing, "origin.git")
    FileUtils.mkdir_p(origin)
    hookless_git(origin, "init", "--quiet", "--bare", "--initial-branch=main")
    seed = File.join(@enclosing, "seed")
    hookless_git(@enclosing, "clone", "--quiet", origin, seed)
    commit(seed, "initial")
    hookless_git(seed, "push", "--quiet", "origin", "main")
    repo = File.join(@enclosing, "repo")
    hookless_git(@enclosing, "clone", "--quiet", origin, repo)
    File.write(File.join(repo, ".git", "info", "exclude"), ".worktrees\n")
    [ origin, repo ]
  end

  def hookless_git(dir, *arguments)
    system("git", "-C", dir, "-c", "core.hooksPath=/dev/null", *arguments, err: File::NULL) ||
      raise("git #{arguments.join(' ')} failed")
  end

  def commit(dir, message)
    File.write(File.join(dir, "file-#{message.tr(' ', '-')}.txt"), message)
    git(dir, "add", "-A")
    git(dir, "commit", "--quiet", "-m", message)
  end

  def add_worktree(name)
    git(@repo, "worktree", "add", "--quiet", File.join(".worktrees", name), "-b", name, "origin/main")
    File.join(@repo, ".worktrees", name)
  end

  def branch?(name)
    _, status = Open3.capture2("git", "-C", @repo, "rev-parse", "--verify", "refs/heads/#{name}",
                               err: File::NULL)
    status.success?
  end

  def git(dir, *arguments)
    output, status = Open3.capture2e("git", "-C", dir, "-c", "core.hooksPath=/dev/null",
                                     "-c", "user.email=test@example.com", "-c", "user.name=Test",
                                     *arguments)
    raise("git #{arguments.join(' ')} failed: #{output}") unless status.success?

    output
  end

  def write_gh_states(states)
    File.write(gh_states_file, states.map { |branch, state| "#{branch}=#{state}" }.join("\n"))
  end

  def gh_states_file
    File.join(@stub_bin, "gh-states.txt")
  end

  def gh_hang_file
    File.join(@stub_bin, "gh-hang")
  end

  def release_file
    File.join(@enclosing, "release-hanging-stubs")
  end

  # The hanging stubs run in the process group of the call that started them (git fetch, or gh),
  # which a missed deadline does not reach. They wait for the release file, so this sends no
  # signal: a stub that is already gone gets nothing, and no process outside the stubs can be hit.
  # A stub started after the release sees the file and exits at once, so git cannot start ssh again.
  # A stub also ends once the folder of the release file is gone, so teardown's removal right
  # after the release cannot leave one hanging.
  def stop_hanging_stubs
    FileUtils.touch(release_file)
  end

  def install_hanging_ssh
    write_stub("hanging-ssh", <<~'SH')
      #!/bin/sh
      waited=0
      while [ ! -e "$RELEASE_HANGING_STUBS" ] && [ -d "${RELEASE_HANGING_STUBS%/*}" ] && [ "$waited" -lt 3000 ]; do
        sleep 0.2
        waited=$((waited + 1))
      done
    SH
  end

  def time_limit_env
    { "WORKTREE_TOOLS_TIME_LIMIT" => "3" }
  end

  def install_gh_stub
    write_gh_states({})
    write_stub("gh", <<~'RUBY')
      #!/usr/bin/env ruby
      if File.exist?(ENV["GH_STUB_HANG"].to_s)
        release = ENV.fetch("RELEASE_HANGING_STUBS")
        3000.times do
          break if File.exist?(release) || !File.directory?(File.dirname(release))

          sleep 0.2
        end
        exit 1
      end
      states = File.exist?(ENV["GH_STUB_STATES"].to_s) ? File.readlines(ENV["GH_STUB_STATES"], chomp: true) : []
      line = states.find { |entry| entry.start_with?("#{ARGV[2]}=") }
      exit 1 unless line

      puts line.split("=", 2).last
    RUBY
  end

  def install_git_recorder
    write_stub("git", <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> "$GIT_CALL_LOG"
      exec /usr/bin/git "$@"
    SH
  end

  def write_stub(name, body)
    path = File.join(@stub_bin, name)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end

  def git_calls
    log = File.join(@enclosing, "git-calls.log")
    File.exist?(log) ? File.readlines(log, chomp: true) : []
  end

  def script_environment(extra_env = {})
    {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "HOME" => @enclosing,
      "GH_STUB_STATES" => gh_states_file,
      "GH_STUB_HANG" => gh_hang_file,
      "RELEASE_HANGING_STUBS" => release_file,
      "GIT_CALL_LOG" => File.join(@enclosing, "git-calls.log")
    }.merge(extra_env)
  end

  def run_script(*arguments, chdir: @repo, extra_env: {})
    Open3.capture3(script_environment(extra_env), "ruby", SCRIPT, *arguments, chdir: chdir)
  end

  # Kills the sweep and its children and fails when it does not finish in time, so a hang
  # cannot stall the suite.
  def run_script_within_deadline(extra_env: {})
    stdin, stdout, stderr, waiter = Open3.popen3(script_environment(extra_env), "ruby", SCRIPT,
                                                 chdir: @repo, pgroup: true)
    stdin.close
    unless waiter.join(DEADLINE)
      @missed_deadline = true
      Process.kill("KILL", -waiter.pid)
      flunk("worktree-sweep did not finish within #{DEADLINE} seconds")
    end
    [ stdout.read, stderr.read, waiter.value ]
  ensure
    [ stdout, stderr ].each { |io| io&.close }
  end
end
