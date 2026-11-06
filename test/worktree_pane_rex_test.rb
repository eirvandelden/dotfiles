#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "isolated_git"

# worktree-pane opens, closes or labels the Rex block rooted in a worktree's directory. It talks to
# Rex only, never to git worktree state, so a stub rex on PATH is enough to test it. Rex has no cwd in
# `block ls`, so the stub answers the `pwd` block method and, when that is empty, the `process` one.
class WorktreePaneRexTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-pane-rex", __dir__)

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
    install_rex_stub
    @worktree = repo_worktree
  end

  def teardown
    FileUtils.rm_rf(@extra_dirs)
  end

  def test_open_splits_a_block_below_the_caller_rooted_in_the_worktree_without_focus
    run_script("open", @worktree)

    assert_call(%r{\Asplit\b.*-b blkCaller\b.*--split[= ]below\b.*-c #{Regexp.escape(File.realpath(@worktree))}\b.*--focus=false})
  end

  def test_open_labels_the_block_repo_slash_branch
    run_script("open", @worktree)

    assert_call(%r{\Ablock rename\b.* blkNew dotfiles/feature\z})
  end

  def test_open_splits_when_the_only_matching_block_is_in_another_session
    write_stub_blocks([ { block_id: "blkQ", session: "other", pwd: file_url(@worktree) } ])

    run_script("open", @worktree)

    assert_call(/\Asplit\b/)
  end

  def test_open_skips_an_existing_block_rooted_in_the_worktree
    write_stub_blocks([ { block_id: "blkQ", pwd: file_url(@worktree) } ])

    run_script("open", @worktree)

    assert_empty(rex_calls.grep(/\Asplit\b/))
  end

  def test_open_outside_rex_does_nothing_and_exits_zero
    _, _, status = run_script("open", @worktree, rex_env: nil)

    assert_equal(0, status.exitstatus)
    assert_empty(rex_calls)
  end

  def test_open_warns_once_and_exits_zero_when_rex_refuses_the_split
    stdout, stderr, status = run_script("open", @worktree, env: { "REX_STUB_FAIL_SPLIT" => "1" })

    assert_equal(0, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
    assert_match(/rex: refused to split/, stderr)
    assert_empty(stdout)
  end

  def test_close_closes_only_blocks_at_the_worktree
    write_stub_blocks([
      { block_id: "blkHere", pwd: file_url(@worktree) },
      { block_id: "blkElsewhere", pwd: file_url("/somewhere/else") }
    ])

    run_script("close", @worktree)

    assert_equal([ "blkHere" ], closed_blocks)
  end

  def test_close_leaves_a_block_with_an_agent_open
    write_stub_blocks([
      { block_id: "blkIdle", pwd: file_url(@worktree), records: [ { state: "idle", app: "claude-code" } ] },
      { block_id: "blkWorking", pwd: file_url(@worktree), records: [ { state: "working", app: "claude-code" } ] },
      { block_id: "blkDone", pwd: file_url(@worktree), records: [ { state: "done", app: "claude-code" } ] }
    ])

    _, stderr, = run_script("close", @worktree)

    assert_empty(closed_blocks)
    assert_includes(stderr, "blkIdle")
    assert_includes(stderr, "blkWorking")
    assert_includes(stderr, "blkDone")
  end

  def test_close_skips_a_block_with_an_unknown_cwd
    write_stub_blocks([ { block_id: "blkMystery" } ])

    run_script("close", @worktree)

    assert_empty(closed_blocks)
  end

  def test_close_leaves_a_block_open_when_its_agent_state_is_unknown
    write_stub_blocks([
      { block_id: "blkFails", pwd: file_url(@worktree), status: "fails" },
      { block_id: "blkGarbage", pwd: file_url(@worktree), status: "garbage" }
    ])

    run_script("close", @worktree)

    assert_empty(closed_blocks)
  end

  def test_cwd_falls_back_to_the_foreground_process
    write_stub_blocks([ { block_id: "blkFallback", foreground_cwd: File.realpath(@worktree) } ])

    run_script("close", @worktree)

    assert_equal([ "blkFallback" ], closed_blocks)
  end

  def test_close_leaves_a_block_in_another_session_alone
    write_stub_blocks([ { block_id: "blkOther", session: "other", pwd: file_url(@worktree) } ])

    run_script("close", @worktree)

    assert_empty(closed_blocks)
  end

  def test_close_with_no_matching_block_closes_nothing
    write_stub_blocks([ { block_id: "blkQ", pwd: file_url("/somewhere/else") } ])

    run_script("close", @worktree)

    assert_empty(closed_blocks)
  end

  def test_label_renames_the_given_block_repo_slash_branch
    run_script("label", @worktree, "blkQ")

    assert_call(%r{\Ablock rename\b.* blkQ dotfiles/feature\z})
  end

  def test_label_outside_rex_does_nothing
    _, _, status = run_script("label", @worktree, "blkQ", rex_env: nil)

    assert_equal(0, status.exitstatus)
    assert_empty(rex_calls)
  end

  def test_open_without_a_path_prints_usage_and_exits_one
    _, stderr, status = run_script("open", nil)

    assert_equal(1, status.exitstatus)
    assert_equal(1, stderr.lines.count, stderr)
    assert_match(/Usage: worktree-pane/, stderr)
  end

  def test_label_without_a_block_id_prints_usage_and_exits_one
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

  def file_url(path)
    path.start_with?("/somewhere") ? "file://host#{path}" : "file://host#{File.realpath(path)}"
  end

  # Each block: block_id, session (default "S1"), pwd (a file:// URL), foreground_cwd, records, and status
  # ("fails" or "garbage") to make its program_status call fail or answer unparsable text.
  def write_stub_blocks(blocks)
    File.write(stub_blocks_file, JSON.generate(blocks.map { |block| { session: "S1", records: [] }.merge(block) }))
  end

  def stub_blocks_file
    @stub_blocks_file ||= File.join(@stub_bin, "blocks.json")
  end

  # A `rex` that logs every call, one line, and answers: `block ls --json` from blocks.json (no cwd, as the
  # real one), `api call block.method` for program_status, pwd and process, and `split` with a new block.
  def install_rex_stub
    stub = File.join(@stub_bin, "rex")
    File.write(stub, <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("REX_CALL_LOG"), "a") { |file| file.puts(ARGV.join(" ")) }
      blocks = File.exist?(ENV["REX_STUB_BLOCKS"].to_s) ? JSON.parse(File.read(ENV["REX_STUB_BLOCKS"])) : []
      session = ARGV.each_cons(2).find { |flag, _| flag == "-s" }&.last || ENV["REX_SESSION"]

      if ARGV.first(2) == %w[block ls]
        listed = blocks.select { |block| block["session"] == session }
        puts JSON.generate(blocks: listed.map { |block| { block_id: block["block_id"], label: "shell", flavor: "shell" } })
      elsif ARGV.include?("block.method")
        request = JSON.parse(ARGV[ARGV.index("block.method") + 1])
        block = blocks.find { |candidate| candidate["block_id"] == request["block_id"] } || {}
        case request["method"]
        when "program_status"
          case block["status"]
          when "fails" then warn("rex: program_status failed") || exit(1)
          when "garbage" then puts "not json at all"
          else puts JSON.generate(records: block.fetch("records", []))
          end
        when "pwd" then puts JSON.generate(block["pwd"] ? { pwd: block["pwd"] } : {})
        when "process"
          puts JSON.generate(block["foreground_cwd"] ? { foreground: { name: "zsh", cwd: block["foreground_cwd"] } } : {})
        else puts "{}"
        end
      elsif ARGV.first == "split"
        if ENV["REX_STUB_FAIL_SPLIT"] == "1"
          warn "rex: refused to split"
          exit 1
        end
        puts JSON.generate(anchor_id: "blkCaller", block_ids: [ "blkNew" ], split_ids: [ "s1" ], revision: 1)
      end
    RUBY
    FileUtils.chmod(0o755, stub)
  end

  def run_script(command, path, *rest, rex_env: "S1", env: {})
    environment = {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "REX_CALL_LOG" => call_log,
      "REX_STUB_BLOCKS" => stub_blocks_file,
      "REX_SESSION" => rex_env,
      "REX_BLOCK" => "blkCaller"
    }.merge(env)
    Open3.capture3(environment, "ruby", SCRIPT, *[ command, path, *rest ].compact)
  end

  def call_log
    @call_log ||= File.join(@stub_bin, "calls.log")
  end

  def rex_calls
    File.exist?(call_log) ? File.readlines(call_log, chomp: true) : []
  end

  def assert_call(pattern)
    assert(rex_calls.any? { |call| call.match?(pattern) }, "no rex call matches #{pattern.inspect} in #{rex_calls.inspect}")
  end

  def closed_blocks
    rex_calls.grep(/\Ablock close\b/).flat_map { |call| call.split.drop(2).reject { |word| word.start_with?("-") || word == "S1" } }
  end
end
