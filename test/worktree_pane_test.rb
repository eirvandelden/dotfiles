#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# worktree-pane opens or closes the herdr pane rooted in a worktree's directory. It talks to
# herdr only, never to git worktree state, so a stub herdr on PATH is enough to test it.
class WorktreePaneTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-pane", __dir__)

  def setup
    @stub_bin = Dir.mktmpdir
    @extra_dirs = [ @stub_bin ]
    install_herdr_stub
    @worktree = repo_worktree
  end

  def teardown
    FileUtils.rm_rf(@extra_dirs)
  end

  def test_open_splits_a_pane_below_rooted_in_the_worktree_without_focus
    run_script("open", @worktree)

    assert_includes(herdr_calls,
                    "pane split --current --direction down --cwd #{File.realpath(@worktree)} --no-focus")
  end

  def test_open_labels_the_pane_repo_slash_branch
    run_script("open", @worktree)

    assert_includes(herdr_calls, "pane rename w1:pV dotfiles/feature")
  end

  def test_open_scopes_the_pane_lookup_to_the_current_workspace
    run_script("open", @worktree)

    assert_includes(herdr_calls, "pane list --workspace w1")
  end

  def test_open_splits_when_the_only_matching_pane_is_in_another_workspace
    write_stub_panes([ { pane_id: "w2:pQ", cwd: File.realpath(@worktree), agent_status: "idle", workspace_id: "w2" } ])

    run_script("open", @worktree)

    assert_includes(herdr_calls.grep(/\Apane split/),
                    "pane split --current --direction down --cwd #{File.realpath(@worktree)} --no-focus")
  end

  def test_open_reuses_an_existing_pane_rooted_in_the_worktree
    write_stub_panes([ { pane_id: "w1:pQ", cwd: File.realpath(@worktree), agent_status: "idle" } ])

    run_script("open", @worktree)

    assert_empty(herdr_calls.grep(/\Apane split/))
  end

  def test_open_outside_herdr_does_nothing_and_exits_zero
    _, _, status = run_script("open", @worktree, herdr_env: nil)

    assert_equal(0, status.exitstatus)
    assert_empty(herdr_calls)
  end

  def test_open_warns_once_and_exits_zero_when_herdr_refuses_the_split
    stdout, stderr, status = run_script("open", @worktree, env: { "HERDR_STUB_FAIL_SPLIT" => "1" })

    assert_equal(0, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
    assert_match(/herdr: refused to split/, stderr)
    assert_empty(stdout)
  end

  def test_close_skips_a_pane_with_a_running_agent_and_names_it
    write_stub_panes([ { pane_id: "w1:pQ", cwd: File.realpath(@worktree), agent_status: "running" } ])

    _, stderr, = run_script("close", @worktree)

    assert_empty(herdr_calls.grep(/\Apane close/))
    assert_includes(stderr, "w1:pQ")
  end

  def test_close_closes_an_idle_pane_rooted_in_the_worktree
    write_stub_panes([ { pane_id: "w1:pQ", cwd: File.realpath(@worktree), agent_status: "idle" } ])

    run_script("close", @worktree)

    assert_includes(herdr_calls, "pane close w1:pQ")
  end

  def test_close_scopes_the_pane_lookup_to_the_current_workspace
    run_script("close", @worktree)

    assert_includes(herdr_calls, "pane list --workspace w1")
  end

  def test_close_with_no_matching_pane_closes_nothing
    write_stub_panes([ { pane_id: "w1:pQ", cwd: "/somewhere/else", agent_status: "idle" } ])

    run_script("close", @worktree)

    assert_empty(herdr_calls.grep(/\Apane close/))
  end

  def test_close_leaves_a_pane_in_another_workspace_alone
    write_stub_panes([ { pane_id: "w2:pQ", cwd: File.realpath(@worktree), agent_status: "idle", workspace_id: "w2" } ])

    run_script("close", @worktree)

    assert_empty(herdr_calls.grep(/\Apane close/))
  end

  def test_label_renames_the_given_pane_repo_slash_branch
    run_script("label", @worktree, "w1:pQ")

    assert_includes(herdr_calls, "pane rename w1:pQ dotfiles/feature")
  end

  def test_label_outside_herdr_does_nothing
    _, _, status = run_script("label", @worktree, "w1:pQ", herdr_env: nil)

    assert_equal(0, status.exitstatus)
    assert_empty(herdr_calls)
  end

  private

  def repo_worktree
    enclosing = Dir.mktmpdir
    @extra_dirs << enclosing

    repo = File.join(enclosing, "dotfiles")
    FileUtils.mkdir_p(repo)
    git(repo, "init", "--quiet", "--initial-branch=main")
    git(repo, "commit", "--quiet", "--allow-empty", "-m", "initial")

    worktree = File.join(enclosing, "worktree")
    git(repo, "worktree", "add", "--quiet", "-b", "feature", worktree)
    worktree
  end

  def git(repo, *arguments)
    system("git", "-C", repo, "-c", "core.hooksPath=/dev/null", "-c", "user.email=test@example.com",
           "-c", "user.name=Test", *arguments) || raise("git #{arguments.join(' ')} failed")
  end

  def write_stub_panes(panes)
    panes = panes.map { |pane| { workspace_id: "w1" }.merge(pane) }
    File.write(stub_panes_file, JSON.generate(panes))
  end

  def stub_panes_file
    @stub_panes_file ||= File.join(@stub_bin, "panes.json")
  end

  def install_herdr_stub
    stub = File.join(@stub_bin, "herdr")
    File.write(stub, <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("HERDR_CALL_LOG"), "a") { |file| file.puts(ARGV.join(" ")) }

      case ARGV[0..1]
      when [ "pane", "list" ]
        panes = File.exist?(ENV["HERDR_STUB_PANES"].to_s) ? JSON.parse(File.read(ENV["HERDR_STUB_PANES"])) : []
        workspace_index = ARGV.index("--workspace")
        panes = panes.select { |pane| pane["workspace_id"] == ARGV[workspace_index + 1] } if workspace_index
        puts JSON.generate({ result: { panes: panes } })
      when [ "pane", "split" ]
        if ENV["HERDR_STUB_FAIL_SPLIT"] == "1"
          warn "herdr: refused to split"
          exit 1
        end
        puts JSON.generate({ result: { pane: { pane_id: "w1:pV" } } })
      else
        puts JSON.generate({ result: {} })
      end
    RUBY
    FileUtils.chmod(0o755, stub)
  end

  def run_script(command, path, *rest, herdr_env: "1", env: {})
    environment = {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "HERDR_CALL_LOG" => call_log,
      "HERDR_STUB_PANES" => stub_panes_file,
      "HERDR_ENV" => herdr_env,
      "HERDR_WORKSPACE_ID" => "w1"
    }.merge(env)
    Open3.capture3(environment, "ruby", SCRIPT, command, path, *rest)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def herdr_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
  end
end
