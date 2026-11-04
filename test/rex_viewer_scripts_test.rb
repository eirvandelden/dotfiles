#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# The viewer scripts (rex/.config/rex/viewer/{base,list,preview,pick}.sh) run against real temporary git
# repositories. `fzf`, `glow`, `delta` and `bat` are stubs on PATH. Each stub appends one tab-separated
# line to tools.log (its name, then its arguments); `delta` also keeps its stdin, and `fzf` keeps its
# arguments, its environment and its stdin. A test reads those logs to see which renderer ran.
class RexViewerScriptsTest < Minitest::Test
  VIEWER = File.expand_path("../rex/.config/rex/viewer", __dir__)
  BASE = File.join(VIEWER, "base.sh")
  LIST = File.join(VIEWER, "list.sh")
  PREVIEW = File.join(VIEWER, "preview.sh")
  PICK = File.join(VIEWER, "pick.sh")
  BASH = `command -v bash`.strip
  LEAN_COMMANDS = %w[git cat env dirname basename sort sed awk grep tr cut head tail mkdir rm uname readlink pwd].freeze
  CHANGED_ROWS = [
    "A\tdocs/changes/x/plan.md",
    "A\tlib/committed.rb",
    "M\tlib/dirty.rb",
    "D\tlib/gone.rb",
    "?\tlib/untracked.rb"
  ].freeze

  def setup
    @dir = Dir.mktmpdir
    @bin = File.join(@dir, "bin")
    FileUtils.mkdir_p(@bin)
    install_tool_stubs
    build_repo
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_base_prints_the_root_and_the_merge_base_inside_a_repository
    stdout, stderr, status = run_script(BASE, File.join(@repo, "lib"))

    assert(status.success?, stderr)
    assert_equal("#{@repo}\t#{@branch_point}\n", stdout)
  end

  def test_base_exits_1_outside_a_repository
    outside = File.join(@dir, "outside")
    FileUtils.mkdir_p(outside)

    stdout, stderr, status = run_script(BASE, outside)

    assert_equal(1, status.exitstatus)
    assert_empty(stdout)
    assert_includes(stderr, "Not a git repository")
  end

  def test_base_falls_back_to_head_with_no_base_branch
    trunk = new_repository("trunk-repo", branch: "trunk")
    head = git("rev-parse", "HEAD", dir: trunk).strip

    stdout, stderr, status = run_script(BASE, trunk)

    assert(status.success?, stderr)
    assert_equal("#{trunk}\t#{head}\n", stdout)
  end

  def test_base_prefers_origin_head_over_main
    git("checkout", "-q", "main")
    commit_file("lib/later.rb", "later\n", "later on main")
    git("checkout", "-q", "feature")
    git("update-ref", "refs/remotes/origin/develop", @branch_point)
    git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/develop")

    stdout, stderr, status = run_script(BASE, @repo)

    assert(status.success?, stderr)
    assert_equal("#{@repo}\t#{@branch_point}\n", stdout)
  end

  def test_a_commit_on_main_after_the_branch_point_is_not_listed
    git("checkout", "-q", "main")
    commit_file("lib/main_only.rb", "main only\n", "main moves on")
    git("checkout", "-q", "feature")

    stdout, stderr, status = run_script(BASE, @repo)
    assert(status.success?, stderr)
    assert_equal("#{@repo}\t#{@branch_point}\n", stdout)

    assert_equal(CHANGED_ROWS, list_rows)
  end

  def test_list_has_committed_uncommitted_and_untracked_files
    assert_equal(CHANGED_ROWS, list_rows)
  end

  def test_list_marks_a_deleted_file
    assert_includes(list_rows, "D\tlib/gone.rb")
  end

  def test_list_prints_nothing_for_a_clean_repository
    clean = new_repository("clean-repo", branch: "main")
    head = git("rev-parse", "HEAD", dir: clean).strip

    stdout, stderr, status = run_script(LIST, clean, head)

    assert(status.success?, stderr)
    assert_empty(stdout)
  end

  def test_default_view_renders_markdown_with_glow
    stdout, stderr, status = preview("default", "A", "docs/changes/x/plan.md")

    assert(status.success?, stderr)
    assert_equal("GLOW", stdout.strip)
    assert_equal([ "-s", "auto", "-w", "80", "./docs/changes/x/plan.md" ], tool_args("glow"))
    assert_empty(tool_calls("delta"))
  end

  def test_default_view_shows_code_as_a_diff
    stdout, stderr, status = preview("default", "M", "lib/dirty.rb")

    assert(status.success?, stderr)
    assert_equal("DELTA", stdout.strip)
    assert_includes(delta_stdin, "diff --git a/lib/dirty.rb b/lib/dirty.rb")
    assert_includes(delta_stdin, "+changed = true")
    assert_empty(tool_calls("bat"))
    assert_empty(tool_calls("glow"))
  end

  def test_default_view_shows_an_untracked_file_with_bat
    stdout, stderr, status = preview("default", "?", "lib/untracked.rb")

    assert(status.success?, stderr)
    assert_equal("BAT", stdout.strip)
    assert_equal("./lib/untracked.rb", tool_args("bat").last)
    assert_empty(tool_calls("delta"))
  end

  def test_alternate_view_shows_code_with_bat
    stdout, stderr, status = preview("alternate", "M", "lib/dirty.rb")

    assert(status.success?, stderr)
    assert_equal("BAT", stdout.strip)
    assert_equal("./lib/dirty.rb", tool_args("bat").last)
    assert_empty(tool_calls("delta"))
  end

  def test_alternate_view_shows_tracked_markdown_as_a_diff
    stdout, stderr, status = preview("alternate", "A", "docs/changes/x/plan.md")

    assert(status.success?, stderr)
    assert_equal("DELTA", stdout.strip)
    assert_includes(delta_stdin, "docs/changes/x/plan.md")
    assert_empty(tool_calls("glow"))
  end

  def test_an_untracked_markdown_file_renders_with_glow_and_alternates_to_bat
    File.write(File.join(@repo, "notes.md"), "# Notes\n")

    default_out, = preview("default", "?", "notes.md")
    alternate_out, = preview("alternate", "?", "notes.md")

    assert_equal("GLOW", default_out.strip)
    assert_equal("BAT", alternate_out.strip)
    assert_equal("./notes.md", tool_args("glow").last)
    assert_equal("./notes.md", tool_args("bat").last)
  end

  def test_a_deleted_file_is_a_diff_in_both_views
    %w[default alternate].each do |view|
      reset_logs
      stdout, stderr, status = preview(view, "D", "lib/gone.rb")

      assert(status.success?, "#{view}: #{stderr}")
      assert_equal("DELTA", stdout.strip, view)
      assert_includes(delta_stdin, "deleted file mode", view)
      assert_empty(tool_calls("bat"), view)
    end
  end

  def test_a_missing_tool_falls_back_to_cat_or_a_plain_git_diff
    diff, = preview("default", "M", "lib/dirty.rb", path_dirs: lean_path)
    content, = preview("alternate", "M", "lib/dirty.rb", path_dirs: lean_path)
    markdown, = preview("default", "A", "docs/changes/x/plan.md", path_dirs: lean_path)

    assert_includes(diff, "diff --git a/lib/dirty.rb b/lib/dirty.rb")
    assert_includes(content, "changed = true")
    assert_includes(markdown, "# Plan")
    assert_empty(tool_calls("delta") + tool_calls("bat") + tool_calls("glow"))
  end

  def test_a_path_with_a_space_or_a_leading_dash_reaches_the_preview
    File.write(File.join(@repo, "my file.rb"), "spaced = 2\n")
    File.write(File.join(@repo, "-lead.rb"), "dashed = 2\n")
    File.write(File.join(@repo, "-fresh.rb"), "fresh = 1\n")
    File.write(File.join(@repo, "new file.rb"), "fresh = 2\n")
    rows = list_rows
    assert_includes(rows, "M\tmy file.rb")
    assert_includes(rows, "M\t-lead.rb")
    start_pick

    rows.each { |row| run_pick_preview(row) if row.match?(/my file|-lead|-fresh|new file/) }

    assert_includes(delta_stdin, "+spaced = 2")
    assert_includes(delta_stdin, "+dashed = 2")
    assert_equal([ "./-fresh.rb", "./new file.rb" ], tool_calls("bat").map(&:last))
  end

  def test_pick_starts_fzf_with_the_changed_files_as_rows
    _, stderr, status = run_script(PICK, @repo)

    assert(status.success?, stderr)
    assert_equal(CHANGED_ROWS, fzf_stdin.map { |line| line.split("\t", -1).first(2).join("\t") })
    assert_includes(fzf_argv, "--disabled")
  end

  def test_the_binds_move_scroll_toggle_and_close
    start_pick

    assert_includes(binds, "j:down")
    assert_includes(binds, "k:up")
    assert_includes(binds, "ctrl-d:preview-half-page-down")
    assert_includes(binds, "ctrl-u:preview-half-page-up")
    assert(binds.any? { |bind| bind.start_with?("v:transform(") }, binds.inspect)
  end

  def test_ctrl_d_and_ctrl_u_scroll_the_preview
    start_pick

    assert_equal(1, binds.count { |bind| bind.start_with?("ctrl-d:") })
    assert_includes(binds, "ctrl-d:preview-half-page-down")
    assert_equal(1, binds.count { |bind| bind.start_with?("ctrl-u:") })
    assert_includes(binds, "ctrl-u:preview-half-page-up")
  end

  def test_esc_and_q_abort_fzf
    start_pick

    assert_includes(binds, "q:abort")
    assert_includes(binds, "esc:abort")
  end

  def test_the_binds_and_the_preview_hold_no_path
    start_pick

    pieces = fzf_argv.join("\n")
    refute_includes(pieces, @repo)
    refute_includes(pieces, VIEWER)
    refute_includes(pieces, @dir)
  end

  def test_toggle_flips_the_view_both_ways
    start_pick

    to_alternate = toggle("default> ")
    to_default = toggle("alternate> ")

    assert_match(/\Achange-prompt\(alternate> \)\+change-preview\(.+\)\z/m, to_alternate)
    assert_match(/\Achange-prompt\(default> \)\+change-preview\(.+\)\z/m, to_default)
    assert_match(/\balternate\b/, toggled_command(to_alternate))
    assert_match(/\bdefault\b/, toggled_command(to_default))
    refute_match(/\bdefault\b/, toggled_command(to_alternate))
  end

  def test_the_toggled_preview_command_renders_the_other_view
    start_pick

    run_toggled_preview(toggle("default> "), "A\tdocs/changes/x/plan.md")
    assert_equal(1, tool_calls("delta").size)
    assert_empty(tool_calls("glow"))

    reset_logs
    run_toggled_preview(toggle("alternate> "), "A\tdocs/changes/x/plan.md")
    assert_equal(1, tool_calls("glow").size)
    assert_empty(tool_calls("delta"))
  end

  def test_no_changes_shows_a_notice_and_never_starts_fzf
    clean = new_repository("clean-repo", branch: "main")

    stdout, stderr, status = run_script(PICK, clean, stdin: "x")

    assert(status.success?, stderr)
    assert_includes(stdout, "No changed files")
    refute_path_exists(File.join(@dir, "fzf.argv"))
  end

  def test_outside_a_repository_shows_a_notice_and_never_starts_fzf
    outside = File.join(@dir, "outside")
    FileUtils.mkdir_p(outside)

    stdout, stderr, status = run_script(PICK, outside, stdin: "x")

    assert(status.success?, stderr)
    assert_includes(stdout, "Not a git repository")
    refute_path_exists(File.join(@dir, "fzf.argv"))
  end

  def test_an_empty_directory_argument_shows_the_not_a_repository_notice
    stdout, stderr, status = run_script(PICK, "", stdin: "x")

    assert(status.success?, stderr)
    assert_includes(stdout, "Not a git repository")
    refute_path_exists(File.join(@dir, "fzf.argv"))
  end

  def test_notice_waits_for_one_key
    Open3.popen3(script_environment, BASH, PICK, "notice", "No changed files") do |stdin, stdout, _stderr, thread|
      assert_nil(thread.join(0.5), "notice returned before a key")
      stdin.write("x")
      stdin.flush
      assert(thread.join(5), "notice did not return after a key")
      assert_includes(stdout.read, "No changed files")
    end
    refute_path_exists(File.join(@dir, "fzf.argv"))
  end

  def test_each_script_prints_its_usage_without_arguments
    { BASE => "base.sh <dir>", LIST => "list.sh <root> <base>",
      PREVIEW => "preview.sh <root> <base> <view> <status> <path>", PICK => "pick.sh <dir>" }.each do |script, usage|
      stdout, stderr, status = run_script(script)

      refute(status.success?, usage)
      assert_includes(stdout + stderr, usage)
    end
  end

  def test_the_viewer_leaves_the_repository_unchanged
    before = repository_state

    list_rows
    CHANGED_ROWS.each { |row| %w[default alternate].each { |view| preview(view, *row.split("\t")) } }
    run_script(BASE, @repo)
    run_script(PICK, @repo)

    assert_equal(before, repository_state)
  end

  private

  #: (String script, *String arguments, ?env: Hash[String, String], ?stdin: String) -> [String, String, Process::Status]
  def run_script(script, *arguments, env: {}, stdin: "")
    Open3.capture3(script_environment.merge(env), BASH, script, *arguments, stdin_data: stdin)
  end

  #: () -> Hash[String, String]
  def script_environment
    { "PATH" => "#{@bin}:#{ENV.fetch('PATH')}", "STUB_DIR" => @dir }
  end

  #: () -> Array[String]
  def list_rows
    stdout, stderr, status = run_script(LIST, @repo, @branch_point)
    assert(status.success?, "list.sh failed: #{stderr}")
    stdout.lines(chomp: true)
  end

  #: (String view, String status, String path, ?path_dirs: String?) -> [String, String, Process::Status]
  def preview(view, status, path, path_dirs: nil)
    env = { "FZF_PREVIEW_COLUMNS" => "80" }
    env["PATH"] = path_dirs if path_dirs
    run_script(PREVIEW, @repo, @branch_point, view, status, path, env: env)
  end

  # A PATH holding only git and the plain tools, so glow, delta and bat are missing.
  #: () -> String
  def lean_path
    lean = File.join(@dir, "lean")
    FileUtils.mkdir_p(lean)
    LEAN_COMMANDS.each do |name|
      found = `command -v #{name}`.strip
      FileUtils.ln_sf(found, File.join(lean, name)) unless found.empty? || found.start_with?("alias")
    end
    lean
  end

  #: () -> void
  def start_pick
    _, stderr, status = run_script(PICK, @repo)
    assert(status.success?, stderr)
  end

  # Runs one row's preview as fzf would: the preview command through a shell, placeholders filled in,
  # with pick.sh's exported environment.
  #: (String row) -> [String, String, Process::Status]
  def run_pick_preview(row)
    run_fzf_command(fzf_preview_command, row)
  end

  #: (String prompt) -> String
  def toggle(prompt)
    command = binds.find { |bind| bind.start_with?("v:transform(") }.delete_prefix("v:transform(").delete_suffix(")")
    stdout, stderr, status = Open3.capture3(bind_environment.merge("FZF_PROMPT" => prompt), "bash", "-c", command)
    assert(status.success?, "toggle failed: #{stderr}")
    stdout.chomp
  end

  #: (String action) -> String
  def toggled_command(action)
    action[/change-preview\((.*)\)\z/m, 1]
  end

  #: (String action, String row) -> [String, String, Process::Status]
  def run_toggled_preview(action, row)
    run_fzf_command(toggled_command(action), row)
  end

  #: (String command, String row) -> [String, String, Process::Status]
  def run_fzf_command(command, row)
    marker, path = row.split("\t", 2)
    filled = command.gsub("{1}", fzf_quote(marker)).gsub("{2}", fzf_quote(path))
    Open3.capture3(bind_environment.merge("FZF_PREVIEW_COLUMNS" => "80"), "bash", "-c", filled, chdir: @dir)
  end

  #: (String value) -> String
  def fzf_quote(value)
    "'#{value.gsub("'", "'\\\\''")}'"
  end

  #: () -> String
  def fzf_preview_command
    argv = fzf_argv
    flagged = argv.each_cons(2).find { |flag, _| flag == "--preview" }&.last
    flagged || argv.find { |value| value.start_with?("--preview=") }.delete_prefix("--preview=")
  end

  #: () -> Array[String]
  def binds
    argv = fzf_argv
    argv.each_cons(2).filter_map { |flag, value| value if flag == "--bind" } +
      argv.filter_map { |value| value.delete_prefix("--bind=") if value.start_with?("--bind=") }
  end

  #: () -> Hash[String, String]
  def bind_environment
    script_environment.merge(fzf_env)
  end

  #: () -> Array[String]
  def fzf_argv
    read_log("fzf.argv")
  end

  #: () -> Hash[String, String]
  def fzf_env
    read_log("fzf.env").grep(/\A\w+=/).to_h { |line| line.split("=", 2) }
  end

  #: () -> Array[String]
  def fzf_stdin
    read_log("fzf.stdin")
  end

  #: () -> String
  def delta_stdin
    path = File.join(@dir, "delta.stdin")
    File.exist?(path) ? File.read(path) : ""
  end

  # One entry per call of the named tool: its arguments.
  #: (String name) -> Array[Array[String]]
  def tool_calls(name)
    read_log("tools.log").map { |line| line.split("\t", -1) }.select { |fields| fields.first == name }
                         .map { |fields| fields.drop(1) }
  end

  #: (String name) -> Array[String]
  def tool_args(name)
    calls = tool_calls(name)
    assert_equal(1, calls.size, "#{name} was called #{calls.size} times")
    calls.first
  end

  #: () -> void
  def reset_logs
    FileUtils.rm_f(Dir.glob(File.join(@dir, "{tools.log,delta.stdin}")))
  end

  #: (String name) -> Array[String]
  def read_log(name)
    path = File.join(@dir, name)
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  # Everything the viewer must not touch: the index bytes, the work tree status, HEAD and every ref.
  #: () -> Hash[Symbol, String]
  def repository_state
    {
      index: File.binread(File.join(@repo, ".git", "index")),
      status: git("--no-optional-locks", "status", "--porcelain=v1", "-uall"),
      refs: git("for-each-ref"),
      head: git("rev-parse", "HEAD")
    }
  end

  #: () -> void
  def build_repo
    @repo = new_repository("repo (odd)", branch: "main", files: base_files)
    @branch_point = git("rev-parse", "HEAD").strip
    git("checkout", "-q", "-b", "feature")
    commit_file("docs/changes/x/plan.md", "# Plan\n\n- one\n", "plan")
    commit_file("lib/committed.rb", "committed = true\n", "committed")
    File.write(File.join(@repo, "lib/dirty.rb"), "dirty = 1\nchanged = true\n")
    FileUtils.rm(File.join(@repo, "lib/gone.rb"))
    File.write(File.join(@repo, "lib/untracked.rb"), "untracked = true\n")
  end

  #: () -> Hash[String, String]
  def base_files
    { "README.md" => "base\n", "lib/keep.rb" => "keep = 1\n", "lib/dirty.rb" => "dirty = 1\n",
      "lib/gone.rb" => "gone = 1\n", "my file.rb" => "spaced = 1\n", "-lead.rb" => "dashed = 1\n" }
  end

  # A repository with one commit on <branch>. Returns its real path.
  #: (String name, branch: String, ?files: Hash[String, String]) -> String
  def new_repository(name, branch:, files: { "README.md" => "base\n" })
    path = File.join(@dir, name)
    FileUtils.mkdir_p(path)
    path = File.realpath(path)
    git("init", "-q", "-b", branch, dir: path)
    git("config", "user.name", "Test", dir: path)
    git("config", "user.email", "test@example.com", dir: path)
    files.each { |file, content| write_file(path, file, content) }
    git("add", "-A", dir: path)
    git("commit", "-q", "-m", "base", dir: path)
    path
  end

  #: (String path, String content, String message) -> void
  def commit_file(path, content, message)
    write_file(@repo, path, content)
    git("add", "--", path)
    git("commit", "-q", "-m", message)
  end

  #: (String root, String path, String content) -> void
  def write_file(root, path, content)
    full = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  #: (*String arguments, ?dir: String?) -> String
  def git(*arguments, dir: nil)
    stdout, stderr, status = Open3.capture3("git", *arguments, chdir: dir || @repo)
    assert(status.success?, "git #{arguments.join(' ')} failed: #{stderr}")
    stdout
  end

  #: () -> void
  def install_tool_stubs
    install_stub("glow", 'log_call "$@"; echo GLOW')
    install_stub("bat", 'log_call "$@"; echo BAT')
    install_stub("delta", 'log_call "$@"; cat >> "$STUB_DIR/delta.stdin"; echo DELTA')
    install_stub("fzf", <<~'BASH')
      printf '%s\n' "$@" >> "$STUB_DIR/fzf.argv"
      env >> "$STUB_DIR/fzf.env"
      cat > "$STUB_DIR/fzf.stdin"
    BASH
  end

  #: (String name, String body) -> void
  def install_stub(name, body)
    path = File.join(@bin, name)
    prelude = <<~'BASH'
      log_call() {
        { printf '%s' "$(basename "$0")"; printf '\t%s' "$@"; printf '\n'; } >> "$STUB_DIR/tools.log"
      }
    BASH
    File.write(path, "#!/bin/bash\n#{prelude}#{body}\n")
    FileUtils.chmod(0o755, path)
  end
end
