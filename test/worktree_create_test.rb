#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# worktree-create sweeps merged/gone worktrees, then creates a fresh one off origin's default
# branch. It shells out to git, gh (PR state) and, inside herdr, worktree-pane — all stubbed.
class WorktreeCreateTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-create", __dir__)

  def setup
    @enclosing = Dir.mktmpdir
    @stub_bin = Dir.mktmpdir
    install_gh_stub
    install_herdr_stub
    @origin, @repo = origin_and_clone
  end

  def teardown
    FileUtils.rm_rf([ @enclosing, @stub_bin ])
  end

  def test_creates_a_worktree_off_the_default_branch_and_prints_its_path
    stdout, stderr, status = run_script("feature")

    assert(status.success?, stderr)
    path = stdout.strip
    assert_equal(File.join(File.realpath(@repo), ".worktrees", "feature"), path)
    assert(File.directory?(path))
    assert_equal("feature", git(path, "rev-parse", "--abbrev-ref", "HEAD").strip)
  end

  def test_inside_herdr_it_opens_a_pane_rooted_in_the_new_worktree
    run_script("feature")

    path = File.join(@repo, ".worktrees", "feature")
    assert_includes(herdr_calls,
                    "pane split --current --direction down --cwd #{File.realpath(path)} --no-focus")
  end

  def test_no_pane_flag_skips_opening_a_pane
    run_script("feature", extra_args: [ "--no-pane" ])

    assert_empty(herdr_calls)
  end

  def test_a_merged_worktree_is_swept_before_the_new_one_is_created
    add_worktree("merged-branch", from: "origin/main")
    merged = File.join(@repo, ".worktrees", "merged-branch")
    commit(merged, "more work")
    write_gh_states("merged-branch" => "MERGED")

    run_script("feature", pane_cwd: File.realpath(merged))

    assert_not(File.directory?(File.join(@repo, ".worktrees", "merged-branch")))
    assert_not(branch?(@repo, "merged-branch"))
    assert_includes(herdr_calls, "pane close w1:pQ")
  end

  def test_a_dirty_worktree_is_kept
    add_worktree("dirty-branch", from: "origin/main")
    dirty = File.join(@repo, ".worktrees", "dirty-branch")
    commit(dirty, "more work")
    File.write(File.join(dirty, "scratch.txt"), "uncommitted")
    write_gh_states("dirty-branch" => "MERGED")

    run_script("feature")

    assert(File.directory?(dirty))
  end

  def test_a_worktree_with_an_open_pr_is_kept
    add_worktree("open-pr-branch", from: "origin/main")
    commit(File.join(@repo, ".worktrees", "open-pr-branch"), "more work")
    write_gh_states("open-pr-branch" => "OPEN")

    run_script("feature")

    assert(File.directory?(File.join(@repo, ".worktrees", "open-pr-branch")))
  end

  def test_a_fresh_worktree_with_no_pr_yet_is_kept
    add_worktree("fresh-branch", from: "origin/main")

    run_script("feature")

    assert(File.directory?(File.join(@repo, ".worktrees", "fresh-branch")))
  end

  def test_refuses_an_empty_name
    _, stderr, status = run_script("")

    assert_not(status.success?)
    assert_match(/name/i, stderr)
  end

  def test_refuses_when_worktrees_is_not_ignored
    FileUtils.rm_f(File.join(@repo, ".git", "info", "exclude"))
    system("git", "-C", @repo, "config", "--unset-all", "core.excludesFile", err: File::NULL)

    _, stderr, status = run_script("feature")

    assert_not(status.success?)
    assert_match(/\.worktrees/, stderr)
  end

  def test_runs_worktree_init_when_the_alias_exists
    marker = File.join(@enclosing, "worktree-init-ran-in.txt")
    stub_script = File.join(@stub_bin, "record-worktree-init")
    File.write(stub_script, "#!/bin/sh\npwd > #{marker}\n")
    FileUtils.chmod(0o755, stub_script)
    system("git", "-C", @repo, "config", "alias.worktree-init", "!#{stub_script}") ||
      raise("git config failed")

    run_script("feature")

    assert_equal(File.realpath(File.join(@repo, ".worktrees", "feature")),
                 File.read(marker).strip)
  end

  def test_runs_nothing_when_the_alias_is_absent
    run_script("feature")

    assert_not(File.exist?(File.join(@enclosing, "worktree-init-ran-in.txt")))
  end

  private

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
    system("git", "-C", dir, "-c", "core.hooksPath=/dev/null", *arguments) ||
      raise("git #{arguments.join(' ')} failed")
  end

  def commit(dir, message)
    File.write(File.join(dir, "file-#{message.tr(' ', '-')}.txt"), message)
    git(dir, "add", "-A")
    git(dir, "commit", "--quiet", "-m", message)
  end

  def add_worktree(branch, from:)
    git(@repo, "worktree", "add", "--quiet", File.join(".worktrees", branch), "-b", branch, from)
  end

  def branch?(repo, name)
    _, status = Open3.capture2("git", "-C", repo, "rev-parse", "--verify", "refs/heads/#{name}", err: File::NULL)
    status.success?
  end

  def git(dir, *arguments)
    output, status = Open3.capture2("git", "-C", dir, "-c", "core.hooksPath=/dev/null",
                                     "-c", "user.email=test@example.com", "-c", "user.name=Test",
                                     *arguments)
    raise("git #{arguments.join(' ')} failed: #{output}") unless status.success?

    output
  end

  def write_gh_states(states)
    File.write(gh_states_file, states.map { |branch, state| "#{branch}=#{state}" }.join("\n"))
  end

  def gh_states_file
    @gh_states_file ||= File.join(@stub_bin, "gh-states.txt")
  end

  def install_gh_stub
    write_gh_states({})
    stub = File.join(@stub_bin, "gh")
    File.write(stub, <<~'RUBY')
      #!/usr/bin/env ruby
      branch = ARGV[2]
      states = File.exist?(ENV["GH_STUB_STATES"].to_s) ? File.readlines(ENV["GH_STUB_STATES"], chomp: true) : []
      line = states.find { |entry| entry.start_with?("#{branch}=") }
      exit 1 unless line

      puts line.split("=", 2).last
    RUBY
    FileUtils.chmod(0o755, stub)
  end

  def install_herdr_stub
    stub = File.join(@stub_bin, "herdr")
    File.write(stub, <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("HERDR_CALL_LOG"), "a") { |file| file.puts(ARGV.join(" ")) }

      case ARGV[0..1]
      when [ "pane", "list" ]
        cwd = ENV["HERDR_STUB_PANE_CWD"]
        panes = cwd ? [ { pane_id: "w1:pQ", cwd: cwd, agent_status: "idle" } ] : []
        puts JSON.generate({ result: { panes: panes } })
      when [ "pane", "split" ]
        puts JSON.generate({ result: { pane: { pane_id: "w1:pV" } } })
      else
        puts JSON.generate({ result: {} })
      end
    RUBY
    FileUtils.chmod(0o755, stub)
  end

  def run_script(name, extra_args: [], pane_cwd: nil)
    environment = {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "HERDR_CALL_LOG" => call_log,
      "GH_STUB_STATES" => gh_states_file,
      "HOME" => @enclosing,
      "HERDR_ENV" => "1"
    }
    environment["HERDR_STUB_PANE_CWD"] = pane_cwd if pane_cwd
    Open3.capture3(environment, "ruby", SCRIPT, name, *extra_args, chdir: @repo)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def herdr_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end
end
