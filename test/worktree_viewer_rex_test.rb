#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "git_fixture"
require_relative "isolated_git"

# worktree-viewer opens the file viewer program at the worktree an agent works in. The caller is the
# Rex block named by REX_BLOCK. Everything outside the launcher is stubbed: rex on PATH, and a fake
# plugin folder under HOME that holds a stub viewer program. Every rex call lands in a JSON-lines log.
class WorktreeViewerRexTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/worktree-viewer-rex", __dir__)
  PROGRAM_NAME = "herdr-file-viewer".freeze

  # A repository at <root>/repo with one empty commit and a linked worktree on feature at
  # <root>/repo/.worktrees/feature.
  REPOSITORY = GitFixture.new do |root|
    repo = File.join(root, "repo")
    git = [ "git", "-C", repo, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test", "-c", "user.email=test@example.com" ]
    system("git", "init", "--quiet", "--initial-branch=main", repo, exception: true)
    system(*git, "commit", "--quiet", "--allow-empty", "-m", "initial", exception: true)
    system(*git, "worktree", "add", "--quiet", File.join(repo, ".worktrees", "feature"), "-b", "feature", exception: true)
  end

  def setup
    @root = Dir.mktmpdir
    @stub_bin = File.join(@root, "bin")
    @state_home = File.join(@root, "state")
    @program = File.join(@root, ".config/herdr/plugins/github", "#{PROGRAM_NAME}-abc123",
                         "target", "release", PROGRAM_NAME)
    @config_dir = File.join(@root, ".config/herdr/plugins/config", PROGRAM_NAME)
    [ @stub_bin, @state_home, @config_dir, File.dirname(@program) ].each { |dir| FileUtils.mkdir_p(dir) }
    install_rex_stub
    install_executable(@program, "#!/bin/sh\nexit 0\n")
    @copy = REPOSITORY.copy
    @repo = File.join(@copy, "repo")
    @worktree = File.join(@repo, ".worktrees", "feature")
    @caller_cwd = @repo
  end

  def teardown
    FileUtils.rm_rf([ @root, @copy ].compact)
  end

  def test_an_unknown_mode_prints_usage_and_exits_one
    _stdout, stderr, status = run_launcher("sideways")

    assert_equal(1, status.exitstatus)
    assert_match(/Usage: worktree-viewer split\|tab/, stderr)
    assert_empty(rex_calls)
  end

  def test_split_opens_the_viewer_at_the_recorded_worktree
    record_worktree

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    split = first_call("split")
    assert_equal("blkA", option(split, "-b"))
    assert_equal(@worktree, option(split, "-c"))
    assert_includes(command_after_dashes(split), @program)
    assert_includes(split.join(" "), "Files")
  end

  def test_split_gives_the_viewer_its_config_folder
    record_worktree

    run_launcher("split")

    assert_includes(command_after_dashes(first_call("split")).join(" "), "HERDR_PLUGIN_CONFIG_DIR=#{@config_dir}")
  end

  def test_tab_opens_a_window_rooted_in_the_recorded_worktree
    record_worktree

    _stdout, stderr, status = run_launcher("tab")

    assert(status.success?, stderr)
    window = first_call("window", "new")
    assert_equal(@worktree, option(window, "-c"))
    assert_includes(command_after_dashes(window), @program)
    assert_empty(calls_matching("split"))
  end

  def test_a_record_for_a_removed_worktree_opens_at_the_block_folder_with_the_picker
    record_worktree
    system("git", "-C", @repo, "worktree", "remove", "--force", @worktree, exception: true)

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@repo, option(first_call("split"), "-c"))
    assert_picker_requested
  end

  def test_a_record_for_another_repository_opens_at_the_block_folder_with_the_picker
    record_worktree(add_worktree(create_repository("other"), "feature"))

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@repo, option(first_call("split"), "-c"))
    assert_picker_requested
  end

  def test_the_main_checkout_without_a_record_gets_the_picker
    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@repo, option(first_call("split"), "-c"))
    assert_picker_requested
  end

  def test_a_block_in_a_worktree_without_a_record_opens_there_without_the_picker
    @caller_cwd = @worktree

    _stdout, stderr, status = run_launcher("split")

    assert(status.success?, stderr)
    assert_equal(@worktree, option(first_call("split"), "-c"))
    assert_empty(calls_matching("send-key"))
  end

  def test_a_recorded_worktree_gets_no_picker
    record_worktree

    run_launcher("tab")

    assert_empty(calls_matching("send-key"))
  end

  def test_the_callers_folder_comes_from_the_foreground_process_when_pwd_is_empty
    record_worktree
    File.write(File.join(@root, "pwd-empty"), "1")

    _stdout, stderr, status = run_launcher("split", env: { "REX_STUB_PWD_EMPTY" => "1" })

    assert(status.success?, stderr)
    assert_equal(@worktree, option(first_call("split"), "-c"))
  end

  def test_a_viewer_split_rex_refuses_exits_with_a_warning
    record_worktree

    _stdout, stderr, status = run_launcher("split", env: { "REX_STUB_FAIL" => "split" })

    refute(status.success?)
    assert_match(/worktree-viewer: .*split/, stderr)
  end

  def test_a_missing_viewer_program_exits_with_a_warning_and_opens_nothing
    FileUtils.rm(@program)

    _stdout, stderr, status = run_launcher("split")

    refute(status.success?)
    assert_match(/worktree-viewer: .*viewer/i, stderr)
    assert_empty(calls_matching("split"))
    assert_empty(calls_matching("window"))
  end

  def test_the_launcher_calls_the_rex_named_in_rex_bin_path
    elsewhere = File.join(@root, "elsewhere")
    FileUtils.mkdir_p(elsewhere)
    FileUtils.mv(File.join(@stub_bin, "rex"), File.join(elsewhere, "rex"))
    record_worktree

    _stdout, stderr, status = run_launcher("split", rex_bin_path: File.join(elsewhere, "rex"),
                                                    path: "#{File.dirname(RbConfig.ruby)}:/usr/bin:/bin")

    assert(status.success?, stderr)
    assert_equal(@worktree, option(first_call("split"), "-c"))
  end

  def test_without_rex_the_launcher_exits_with_a_warning_instead_of_a_crash
    ruby_only = File.join(@root, "ruby-only")
    FileUtils.mkdir_p(ruby_only)
    File.symlink(RbConfig.ruby, File.join(ruby_only, "ruby"))

    _stdout, stderr, status = run_launcher("split", path: ruby_only)

    refute(status.success?)
    assert_match(/worktree-viewer: .*rex/i, stderr)
    refute_match(/\.rb:\d+:in /, stderr)
  end

  private

  def run_launcher(argument, rex_bin_path: nil, path: nil, env: {})
    environment = {
      "PATH" => path || "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "REX_BIN_PATH" => rex_bin_path,
      "HOME" => @root,
      "XDG_STATE_HOME" => @state_home,
      "REX_SESSION" => "S1",
      "REX_BLOCK" => "blkA",
      "REX_STUB_CALLS" => calls_file,
      "REX_STUB_CALLER_CWD" => @caller_cwd
    }.merge(env)
    Open3.capture3(environment, "ruby", SCRIPT, argument)
  end

  def record_worktree(path = @worktree)
    directory = File.join(@state_home, "worktree-tools", "agent-worktrees")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "rex_blkA"), JSON.generate({ terminal_id: "", path: path }))
  end

  def option(call, flag)
    call[call.index(flag) + 1]
  end

  def command_after_dashes(call)
    index = call.index("--") || flunk("no command after -- in #{call.inspect}")
    call.drop(index + 1)
  end

  def assert_picker_requested
    keys = calls_matching("send-key")
    assert(keys.any? { |call| call.include?("W") }, "the picker key W was never sent: #{rex_calls.inspect}")
  end

  def calls_file
    File.join(@root, "rex-calls.jsonl")
  end

  def rex_calls
    return [] unless File.exist?(calls_file)

    File.readlines(calls_file, chomp: true).map { |line| JSON.parse(line) }
  end

  def calls_matching(*command)
    rex_calls.select { |call| call.reject { |word| word == "-s" || word == "S1" }.first(command.size) == command }
  end

  def first_call(*command)
    calls_matching(*command).first || flunk("rex #{command.join(' ')} was never called: #{rex_calls.inspect}")
  end

  def create_repository(name)
    path = File.join(@root, name)
    FileUtils.mkdir_p(path)
    git(path, "init", "--quiet", "--initial-branch=main")
    git(path, "commit", "--quiet", "--allow-empty", "-m", "initial")
    File.realpath(path)
  end

  def add_worktree(repository, name)
    path = File.join(repository, ".worktrees", name)
    git(repository, "worktree", "add", "--quiet", path, "-b", name)
    File.realpath(path)
  end

  def git(dir, *arguments)
    system("git", "-C", dir, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test",
           "-c", "user.email=test@example.com", *arguments, exception: true)
  end

  # Answers the pwd method of the caller block with a file:// URL, process when pwd is empty, and a
  # new block id for split and window new.
  def install_rex_stub
    install_executable(File.join(@stub_bin, "rex"), <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("REX_STUB_CALLS"), "a") { |file| file.puts(JSON.generate(ARGV)) }
      words = ARGV.reject { |word| word == "-s" || word == "S1" }
      if ENV["REX_STUB_FAIL"] == words.first
        warn("stub: #{words.first} refused")
        exit(1)
      end

      cwd = ENV.fetch("REX_STUB_CALLER_CWD")
      if ARGV.include?("block.method")
        request = JSON.parse(ARGV[ARGV.index("block.method") + 1])
        case request["method"]
        when "pwd" then puts JSON.generate(ENV["REX_STUB_PWD_EMPTY"] ? {} : { pwd: "file://host#{cwd}" })
        when "process" then puts JSON.generate({ foreground: { name: "claude", cwd: cwd } })
        else puts "{}"
        end
      elsif words.first == "split"
        puts JSON.generate(anchor_id: "blkA", block_ids: [ "blkV" ], split_ids: [ "s1" ], revision: 1)
      elsif words.first(2) == %w[window new]
        puts JSON.generate(window_id: "winT", block_ids: [ "blkT" ])
      end
    RUBY
  end

  def install_executable(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    FileUtils.chmod(0o755, path)
  end
end
