#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "lefthook_binary"

# A real `git pull` runs the global hook shims, the real lefthook binary and the repository's
# lefthook.yml; the detached sweep it starts removes merged worktrees. gh and herdr are stubbed.
class WorktreeSweepOnPullTest < Minitest::Test
  DEADLINE = 20
  NATIVE_LEFTHOOK = LefthookBinary.locate

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @tmp = File.realpath(Dir.mktmpdir)
    @home = File.join(@tmp, "home")
    @bin = File.join(@tmp, "bin")
    FileUtils.mkdir_p([ @home, @bin ])
    install_home
    install_stubs
    write_gitconfig
    @origin, @repo = origin_and_clone
  end

  def teardown
    return unless @tmp

    FileUtils.touch(release_file)
    wait_for_sweep_to_finish if @repo && File.exist?(lock_file(@repo))
    FileUtils.rm_rf(@tmp)
  end

  def test_a_pull_on_main_in_the_main_checkout_removes_a_merged_worktree_its_branch_and_its_pane
    foo = merged_worktree("foo")
    pane_cwd(foo)

    pull(@repo)

    wait_until("#{foo} to be removed") { !File.exist?(foo) }
    wait_for_sweep_to_finish
    refute(branch?(@repo, "foo"), "the local branch foo should be gone")
    assert_includes(herdr_calls, "pane close w1:pQ")
  end

  private

  # --- environment -------------------------------------------------------------------------

  def install_home
    dotfiles = File.join(@home, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(dotfiles, "lefthook.yml"))
    FileUtils.mkdir_p(File.join(@home, ".config", "git"))
    File.symlink(File.join(@repo_root, "git/.config/git/worktree-tools"),
                 File.join(@home, ".config", "git", "worktree-tools"))
    @hooks = File.join(@tmp, "hooks")
    FileUtils.cp_r(File.join(@repo_root, "git/.config/git/hooks"), @hooks)
  end

  def write_gitconfig
    @gitconfig = File.join(@tmp, "gitconfig")
    File.write(@gitconfig, <<~GITCONFIG)
      [core]
        hooksPath = #{@hooks}
      [user]
        name = Test
        email = test@example.com
      [pull]
        rebase = true
      [rebase]
        autoStash = true
    GITCONFIG
  end

  def install_stubs
    write_executable("lefthook", "#!/bin/sh\nexec \"#{NATIVE_LEFTHOOK}\" \"$@\"\n")
    write_executable("gh", gh_stub)
    write_executable("herdr", herdr_stub)
    write_gh_states({})
  end

  def gh_stub
    <<~'RUBY'
      #!/usr/bin/env ruby
      if File.exist?(ENV.fetch("GH_STUB_LOGGED_OUT", ""))
        warn "gh: not logged in"
        exit 1
      end
      states = File.exist?(ENV["GH_STUB_STATES"].to_s) ? File.readlines(ENV["GH_STUB_STATES"], chomp: true) : []
      line = states.find { |entry| entry.start_with?("#{ARGV[2]}=") }
      exit 1 unless line

      sleep 0.1 until !File.exist?(ENV["GH_STUB_BLOCK"].to_s) || File.exist?(ENV.fetch("GH_STUB_RELEASE"))
      puts line.split("=", 2).last
    RUBY
  end

  def herdr_stub
    <<~'RUBY'
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("HERDR_CALL_LOG"), "a") { |file| file.puts(ARGV.join(" ")) }
      if ARGV[0..1] == [ "pane", "list" ]
        cwds = File.exist?(ENV.fetch("HERDR_STUB_PANES")) ? File.readlines(ENV.fetch("HERDR_STUB_PANES"), chomp: true) : []
        panes = cwds.each_with_index.map { |cwd, i| { pane_id: "w1:pQ#{i.zero? ? '' : i}", cwd: cwd, agent: nil, agent_status: "idle" } }
        puts JSON.generate({ result: { panes: panes } })
      else
        puts JSON.generate({ result: {} })
      end
    RUBY
  end

  def write_executable(name, body)
    path = File.join(@bin, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end

  def environment
    {
      "HOME" => @home,
      "PATH" => "#{@bin}:#{ENV.fetch('PATH')}",
      "GIT_CONFIG_GLOBAL" => @gitconfig,
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "LEFTHOOK_BIN" => NATIVE_LEFTHOOK.to_s,
      "HERDR_ENV" => "1",
      "HERDR_CALL_LOG" => herdr_log,
      "HERDR_STUB_PANES" => panes_file,
      "GH_STUB_STATES" => gh_states_file,
      "GH_STUB_RELEASE" => release_file,
      "GH_STUB_BLOCK" => block_file,
      "GH_STUB_LOGGED_OUT" => logged_out_file
    }
  end

  def herdr_log = File.join(@tmp, "herdr-calls.log")
  def panes_file = File.join(@tmp, "panes.txt")
  def gh_states_file = File.join(@tmp, "gh-states.txt")
  def release_file = File.join(@tmp, "gh-release")
  def block_file = File.join(@tmp, "gh-block")
  def logged_out_file = File.join(@tmp, "gh-logged-out")

  def herdr_calls
    File.exist?(herdr_log) ? File.readlines(herdr_log, chomp: true) : []
  end

  def write_gh_states(states)
    File.write(gh_states_file, states.map { |branch, state| "#{branch}=#{state}" }.join("\n"))
  end

  def pane_cwd(path)
    File.write(panes_file, "#{path}\n")
  end

  # --- repositories ------------------------------------------------------------------------

  def origin_and_clone
    origin = File.join(@tmp, "origin.git")
    run_git(@tmp, "init", "--quiet", "--bare", "--initial-branch=main", origin)
    seed = File.join(@tmp, "seed")
    run_git(@tmp, "clone", "--quiet", origin, seed)
    commit(seed, "initial")
    run_git(seed, "push", "--quiet", "origin", "main")
    repo = File.join(@tmp, "repo")
    run_git(@tmp, "clone", "--quiet", origin, repo)
    File.write(File.join(repo, ".git", "info", "exclude"), ".worktrees\n")
    [ origin, repo ]
  end

  # A worktree whose branch was pushed with -u, has a MERGED PR, and whose commit origin/main
  # now holds. The main checkout still has to pull to see it.
  def merged_worktree(name, repo: @repo)
    path = File.join(repo, ".worktrees", name)
    run_git(repo, "worktree", "add", "--quiet", File.join(".worktrees", name), "-b", name, "origin/main")
    commit(path, "work on #{name}")
    run_git(path, "push", "--quiet", "-u", "origin", name)
    merge_on_origin(name)
    write_gh_states(gh_states.merge(name => "MERGED"))
    File.realpath(path)
  end

  def gh_states
    File.readlines(gh_states_file, chomp: true).to_h { |line| line.split("=", 2) }
  end

  def merge_on_origin(branch)
    pusher = File.join(@tmp, "pusher-#{branch}")
    run_git(@tmp, "clone", "--quiet", @origin, pusher)
    run_git(pusher, "merge", "--quiet", "--ff-only", "origin/#{branch}")
    run_git(pusher, "push", "--quiet", "origin", "main")
  end

  def commit(dir, message)
    File.write(File.join(dir, "file-#{message.tr(' ', '-')}.txt"), message)
    run_git(dir, "add", "-A")
    run_git(dir, "commit", "--quiet", "-m", message)
  end

  def branch?(repo, name)
    _, status = Open3.capture2("git", "-C", repo, "rev-parse", "--verify", "refs/heads/#{name}",
                               err: File::NULL)
    status.success?
  end

  def run_git(dir, *arguments)
    output, status = Open3.capture2e({ "GIT_CONFIG_GLOBAL" => @gitconfig, "LEFTHOOK" => "0" },
                                     "git", "-C", dir, *arguments)
    raise("git #{arguments.join(' ')} failed: #{output}") unless status.success?

    output
  end

  def pull(dir)
    stdout, stderr, status = Open3.capture3(environment, "git", "pull", chdir: dir)
    flunk("git pull failed: #{stdout}#{stderr}") unless status.success?

    [ stdout, stderr ]
  end

  # --- bounded waits -----------------------------------------------------------------------

  def wait_until(what)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
    until yield
      flunk("timed out after #{DEADLINE}s waiting for #{what}") if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def lock_file(repo)
    File.join(repo, ".git", "worktree-sweep.lock")
  end

  # The sweep holds an exclusive flock for as long as it runs; taking it means the sweep ended.
  def wait_for_sweep_to_finish(repo: @repo)
    wait_until("the lock file #{lock_file(repo)}") { File.exist?(lock_file(repo)) }
    File.open(lock_file(repo), File::RDWR) do |file|
      wait_until("the sweep to release its lock") { file.flock(File::LOCK_EX | File::LOCK_NB) }
    end
  end
end
