#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "isolated_git"

# worktree-pane opens or closes the herdr pane rooted in a worktree's directory. It talks to
# herdr only, never to git worktree state, so a stub herdr on PATH is enough to test it.
class WorktreePaneTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-pane", __dir__)

  # A repository at <root>/dotfiles with one empty commit and a linked worktree on feature at <root>/worktree.
  REPOSITORY = GitFixture.new do |root|
    repo = File.join(root, "dotfiles")
    git = [ "git", "-C", repo, "-c", "core.hooksPath=/dev/null", "-c", "user.email=test@example.com",
            "-c", "user.name=Test" ]
    system("git", "init", "--quiet", "--initial-branch=main", repo, exception: true)
    system(*git, "commit", "--quiet", "--allow-empty", "-m", "initial", exception: true)
    system(*git, "worktree", "add", "--quiet", "-b", "feature", File.join(root, "worktree"), exception: true)
  end

  def setup
    @stub_bin = Dir.mktmpdir
    @extra_dirs = [ @stub_bin ]
    install_herdr_stub
    install_rex_stub
    @worktree = repo_worktree
  end

  def teardown
    FileUtils.rm_rf(@extra_dirs)
  end

  def test_a_rex_only_environment_hands_over_to_the_rex_tool
    _stdout, stderr, status = run_script("open", @worktree, herdr_env: nil, env: rex_environment)

    assert(status.success?, stderr)
    assert(rex_calls.any? { |call| call.start_with?("split") }, rex_calls.inspect)
    assert_empty(herdr_calls)
  end

  def test_herdr_wins_over_rex_in_the_pane_tool
    _stdout, stderr, status = run_script("open", @worktree, env: rex_environment)

    assert(status.success?, stderr)
    assert(herdr_calls.any? { |call| call.start_with?("pane split") }, herdr_calls.inspect)
    assert_empty(rex_calls)
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

  def test_close_skips_panes_with_an_agent_whatever_their_status_and_names_them
    write_stub_panes([
      { pane_id: "w1:pA", cwd: File.realpath(@worktree), agent: "claude", agent_status: "idle" },
      { pane_id: "w1:pB", cwd: File.realpath(@worktree), agent: "claude", agent_status: "working" },
      { pane_id: "w1:pC", cwd: File.realpath(@worktree), agent: "claude", agent_status: "done" }
    ])

    _, stderr, = run_script("close", @worktree)

    assert_empty(herdr_calls.grep(/\Apane close/))
    assert_includes(stderr, "w1:pA")
    assert_includes(stderr, "w1:pB")
    assert_includes(stderr, "w1:pC")
  end

  def test_close_closes_a_pane_without_an_agent
    write_stub_panes([ { pane_id: "w1:pQ", cwd: File.realpath(@worktree), agent: nil, agent_status: "unknown" } ])

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

  def test_open_without_a_path_prints_usage_and_exits_one
    _, stderr, status = run_script("open", nil)

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
    assert_match(/Usage: worktree-pane/, stderr)
  end

  def test_label_without_a_pane_id_prints_usage_and_exits_one
    _, stderr, status = run_script("label", @worktree)

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
    assert_match(/Usage: worktree-pane/, stderr)
  end

  def test_open_on_a_missing_path_prints_one_line_and_exits_one
    _, stderr, status = run_script("open", "/no/such/path")

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
  end

  def test_open_outside_any_git_repository_prints_one_line_and_exits_one
    outside = Dir.mktmpdir
    @extra_dirs << outside

    _, stderr, status = run_script("open", outside)

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
  end

  def test_an_unknown_command_prints_usage_before_any_path_or_git_check
    outside = Dir.mktmpdir
    @extra_dirs << outside

    _, stderr, status = run_script("bogus", outside)

    assert_equal(1, status.exitstatus)
    assert_match(/Usage: worktree-pane/, stderr)
  end

  def test_the_shebang_does_not_depend_on_rv_being_on_path
    assert_equal("#!/usr/bin/env ruby\n", File.readlines(SCRIPT).first)
  end

  private

  def repo_worktree
    enclosing = REPOSITORY.copy
    @extra_dirs << enclosing
    File.join(enclosing, "worktree")
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

  def rex_environment
    { "REX_SESSION" => "S1", "REX_BLOCK" => "blkCaller", "REX_CALL_LOG" => rex_call_log }
  end

  def rex_call_log
    File.join(@stub_bin, "rex-calls.log")
  end

  def rex_calls
    File.exist?(rex_call_log) ? File.readlines(rex_call_log, chomp: true) : []
  end

  # A `rex` that logs its calls, lists no blocks and answers `split` with a new block.
  def install_rex_stub
    stub = File.join(@stub_bin, "rex")
    File.write(stub, <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("REX_CALL_LOG"), "a") { |file| file.puts(ARGV.join(" ")) }
      if ARGV.first(2) == %w[block ls]
        puts JSON.generate(blocks: [])
      elsif ARGV.first == "split"
        puts JSON.generate(anchor_id: "blkCaller", block_ids: [ "blkNew" ], split_ids: [ "s1" ], revision: 1)
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
    Open3.capture3(environment, "ruby", SCRIPT, *[ command, path, *rest ].compact)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def herdr_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
  end
end
