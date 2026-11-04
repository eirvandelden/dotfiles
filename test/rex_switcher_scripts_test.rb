#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# The switcher scripts (rex/.config/rex/switcher/{rows,jump,pick}.sh) read a snapshot of tab-separated rows:
# state, "session / tab", program, cwd, message, session_id, window_id, block_id. `rex` and `fzf` are
# stubs on PATH that log their arguments, one call per line, so a test sees the call order. jq, awk and
# `fzf --filter` are real.
class RexSwitcherScriptsTest < Minitest::Test
  SWITCHER = File.expand_path("../rex/.config/rex/switcher", __dir__)
  ROWS = File.join(SWITCHER, "rows.sh")
  JUMP = File.join(SWITCHER, "jump.sh")
  PICK = File.join(SWITCHER, "pick.sh")
  GONE = "change-header(Pane no longer exists)".freeze
  SNAPSHOT_ROWS = [
    [ "blocked", "Work / API", "claude", "/src/api", "waiting for Caren", "s1", "w1", "b1" ],
    [ "working", "Work / API", "codex", "/src/api", "blocked on nothing", "s1", "w1", "b2" ],
    [ "done", "Home / Infra", "claude", "/src/infra", "finished", "s2", "w2", "b3" ],
    [ "idle", "Home / Infra", "claude", "/src/infra", "", "s2", "w2", "b4" ],
    [ "shell", "Home / Notes", "zsh", "/home/etienne", "", "caren-session", "w3", "b5" ],
    [ "shell", "Home / Notes", "zsh", "/home", "", "s3", "w3", "b6" ]
  ].freeze

  def setup
    @dir = Dir.mktmpdir
    @bin = File.join(@dir, "bin")
    FileUtils.mkdir_p(@bin)
    @snapshot = File.join(@dir, "snapshot.tsv")
    File.write(@snapshot, SNAPSHOT_ROWS.map { |row| "#{row.join("\t")}\n" }.join)
    install_rex_stub
    install_fzf_stub
    answer_rex(block_ls: %w[b1], select_exit: 0, focus_exit: 0)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_rows_for_b_keep_only_blocked_panes
    assert_equal([ "b1" ], block_ids(rows("b")))
    assert_equal([ "blocked" ], states(rows("b")))
  end

  def test_rows_for_w_keep_only_working_panes
    assert_equal([ "working" ], states(rows("w")))
  end

  def test_rows_for_d_keep_only_done_panes
    assert_equal([ "done" ], states(rows("d")))
  end

  def test_rows_for_a_keep_every_pane
    assert_equal(SNAPSHOT_ROWS, rows("a").map { |line| line.split("\t", -1) })
  end

  def test_a_message_that_says_blocked_does_not_match_b
    File.write(@snapshot, "#{SNAPSHOT_ROWS[1].join("\t")}\n")

    assert_equal([ "" ] * 4 + [ "No panes match" ] + [ "" ] * 3, rows("b").first.split("\t", -1))
  end

  def test_no_match_prints_the_sentinel_row
    File.write(@snapshot, "#{SNAPSHOT_ROWS[3].join("\t")}\n")

    lines = rows("d")

    assert_equal(1, lines.size)
    assert_equal([ "", "", "", "", "No panes match", "", "", "" ], lines.first.split("\t", -1))
  end

  def test_rows_for_an_unknown_filter_exit_1
    _, _, status = run_script(ROWS, "x", @snapshot)

    assert_equal(1, status.exitstatus)
  end

  def test_rows_never_call_rex
    %w[w b d a].each { |filter| rows(filter) }

    assert_empty(rex_calls)
  end

  def test_search_matches_any_visible_column
    skip("fzf is not on PATH") unless system("command -v fzf >/dev/null 2>&1")
    stdout, _, status = Open3.capture3("fzf", "--filter", "caren", "--delimiter", '\t', "--with-nth", "1..5",
                                       stdin_data: rows("a").map { |line| "#{line}\n" }.join)

    assert(status.success?)
    assert_equal([ "b1" ], block_ids(stdout.lines(chomp: true)), "a hidden-field match must not count")
  end

  def test_jump_selects_the_session_and_window_then_focuses_the_pane
    stdout, = jump("c1", "s1", "w1", "b1")

    assert_equal(
      [ "block ls -s s1 --json", "-C c1 do session.select session_id=s1 window_id=w1", "focus -s s1 b1" ],
      rex_calls
    )
    assert_equal("abort", stdout.strip)
  end

  def test_jump_to_a_gone_pane_says_so_and_stays_open
    answer_rex(block_ls: %w[other])

    stdout, _, status = jump("c1", "s1", "w1", "b1")

    assert_equal(0, status.exitstatus)
    assert_equal(GONE, stdout.strip)
    assert_equal([ "block ls -s s1 --json" ], rex_calls)
  end

  def test_jump_refused_by_session_select_keeps_the_panel_open
    answer_rex(block_ls: %w[b1], select_exit: 1)

    stdout, _, status = jump("c1", "s1", "w1", "b1")

    assert_equal(0, status.exitstatus)
    assert_match(/\Achange-header\(.*Remote Control.*\)\z/, stdout.strip)
    assert_equal(1, stdout.strip.lines.size)
    refute_includes(rex_calls.join("\n"), "focus")
    refute_includes(stdout, "abort")
  end

  def test_jump_when_focus_fails_stays_open
    answer_rex(block_ls: %w[b1], focus_exit: 1)

    stdout, _, status = jump("c1", "s1", "w1", "b1")

    assert_equal(0, status.exitstatus)
    assert_equal(GONE, stdout.strip)
    assert_equal(3, rex_calls.size)
  end

  def test_jump_aborts_only_after_focus_succeeds
    stdout, = jump("c1", "s1", "w1", "b1")

    assert_equal("focus -s s1 b1", rex_calls.last)
    assert_equal("abort", stdout.strip)
  end

  def test_jump_on_the_sentinel_row_makes_no_rex_call
    stdout, _, status = jump("c1", "", "", "")

    assert_equal(0, status.exitstatus)
    assert_empty(stdout.strip)
    assert_empty(rex_calls)
  end

  def test_pick_passes_the_binds_for_w_b_d_a_slash_esc_and_enter_to_fzf
    _, stderr, status = run_script(PICK, @snapshot, "client-42")

    assert(status.success?, stderr)
    argv = fzf_argv
    assert_includes(argv, "--disabled")
    binds = argv.each_cons(2).filter_map { |flag, value| value if flag == "--bind" }
    binds += argv.filter_map { |value| value.delete_prefix("--bind=") if value.start_with?("--bind=") }
    [ "w:reload(", "b:reload(", "d:reload(", "a:reload(", "/:transform(",
      "esc:transform(", "enter:transform(" ].each do |prefix|
      assert(binds.any? { |bind| bind.start_with?(prefix) }, "no bind starts with #{prefix}: #{binds.inspect}")
    end
    enter = binds.find { |bind| bind.start_with?("enter:transform(") }
    assert_equal("client-42", fzf_env["SWITCHER_CLIENT"])
    assert_includes(enter, "{6} {7} {8}")
  end

  def test_the_enter_bind_keeps_an_empty_client_as_an_empty_first_argument
    answer_rex(block_ls: %w[b9])
    _, stderr, status = run_script(PICK, @snapshot, "")
    assert(status.success?, stderr)

    run_bind("enter:transform(", { "{6}" => "s9", "{7}" => "w9", "{8}" => "b9" })

    assert_equal([ "block ls -s s9 --json", "-C  do session.select session_id=s9 window_id=w9",
                   "focus -s s9 b9" ], rex_calls)
  end

  def test_the_binds_survive_a_script_and_snapshot_path_with_spaces
    spaced = File.join(@dir, "with space", "(odd, path)")
    FileUtils.mkdir_p(spaced)
    FileUtils.cp_r(SWITCHER, spaced)
    snapshot = File.join(spaced, "snap shot.tsv")
    FileUtils.cp(@snapshot, snapshot)
    _, stderr, status = run_script(File.join(spaced, "switcher", "pick.sh"), snapshot, "client-42")
    assert(status.success?, stderr)
    FileUtils.cp(@snapshot, snapshot) # pick.sh removed it on exit; fzf would run the binds while it ran

    start_rows = run_bind("start:reload(")
    filter_rows = run_bind("b:reload(")

    assert_equal(SNAPSHOT_ROWS, start_rows.lines(chomp: true).map { |line| line.split("\t", -1) })
    assert_equal([ "blocked" ], states(filter_rows.lines(chomp: true)))
  end

  def test_pick_removes_the_snapshot_on_exit
    run_script(PICK, @snapshot, "client-42")

    refute_path_exists(@snapshot)
  end

  def test_esc_in_search_mode_leaves_search_and_reloads_the_rows_of_the_same_filter
    stdout, _, status = run_script(PICK, "esc", env: { "FZF_PROMPT" => "/b " })

    assert(status.success?)
    assert_equal("disable-search+clear-query+rebind(w,b,d,a,j,k,/)" \
                 '+reload("$SWITCHER_DIR"/rows.sh b "$SWITCHER_SNAPSHOT")+change-prompt(b> )', stdout.chomp)
  end

  def test_esc_in_list_mode_aborts
    stdout, _, status = run_script(PICK, "esc", env: { "FZF_PROMPT" => "b> " })

    assert(status.success?)
    assert_equal("abort", stdout.chomp)
  end

  def test_slash_enters_search_mode_and_remembers_the_filter_in_the_prompt
    stdout, _, status = run_script(PICK, "slash", env: { "FZF_PROMPT" => "w> " })

    assert(status.success?)
    assert_equal("enable-search+unbind(w,b,d,a,j,k,/)+change-prompt(/w )", stdout.chomp)
  end

  def test_the_list_puts_the_most_urgent_row_at_the_top
    _, stderr, status = run_script(PICK, @snapshot, "client-42")

    assert(status.success?, stderr)
    assert_includes(fzf_argv, "--layout=reverse")
  end

  private

  def run_script(script, *arguments, env: {})
    Open3.capture3({ "PATH" => "#{@bin}:#{ENV.fetch('PATH')}", "STUB_DIR" => @dir }.merge(env),
                   "bash", script, *arguments)
  end

  def rows(filter)
    stdout, stderr, status = run_script(ROWS, filter, @snapshot)
    assert(status.success?, "rows.sh #{filter} failed: #{stderr}")
    stdout.lines(chomp: true)
  end

  def jump(*arguments)
    run_script(JUMP, *arguments)
  end

  def states(lines)
    lines.map { |line| line.split("\t", -1)[0] }
  end

  def block_ids(lines)
    lines.map { |line| line.split("\t", -1)[7] }
  end

  def rex_calls
    read_log("rex.log")
  end

  def fzf_argv
    read_log("fzf.argv")
  end

  def fzf_env
    read_log("fzf.env").to_h { |line| line.split("=", 2) }
  end

  # Runs the shell command inside one of the binds that pick.sh gave fzf, as fzf would: through a shell,
  # with pick.sh's environment, after fzf has put its placeholders' values in. Returns its stdout.
  def run_bind(prefix, placeholders = {})
    argv = fzf_argv
    bind = argv.each_cons(2).filter_map { |flag, value| value if flag == "--bind" }.find { |value| value.start_with?(prefix) }
    command = bind.delete_prefix(prefix).sub(/\)(\+change-header\(.*\))?\z/, "")
    placeholders.each { |placeholder, value| command = command.gsub(placeholder, "'#{value}'") }
    stdout, stderr, status = Open3.capture3(bind_environment, "bash", "-c", command)
    assert(status.success?, "bind #{prefix} failed: #{stderr}")
    stdout
  end

  def bind_environment
    { "PATH" => "#{@bin}:#{ENV.fetch('PATH')}", "STUB_DIR" => @dir }.merge(fzf_env)
  end

  def read_log(name)
    path = File.join(@dir, name)
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  def answer_rex(block_ls:, select_exit: 0, focus_exit: 0)
    listing = { "blocks" => block_ls.map { |id| { "block_id" => id } } }
    File.write(File.join(@dir, "block_ls.json"), "#{JSON.generate(listing)}\n")
    File.write(File.join(@dir, "select_exit"), select_exit.to_s)
    File.write(File.join(@dir, "focus_exit"), focus_exit.to_s)
  end

  def install_rex_stub
    install_stub("rex", <<~'BASH')
      echo "$*" >> "$STUB_DIR/rex.log"
      case "$1" in
        block) cat "$STUB_DIR/block_ls.json" ;;
        -C) exit "$(cat "$STUB_DIR/select_exit")" ;;
        focus) exit "$(cat "$STUB_DIR/focus_exit")" ;;
      esac
    BASH
  end

  def install_fzf_stub
    install_stub("fzf", <<~'BASH')
      printf '%s\n' "$@" >> "$STUB_DIR/fzf.argv"
      env | grep '^SWITCHER_' >> "$STUB_DIR/fzf.env"
      cat > "$STUB_DIR/fzf.stdin"
    BASH
  end

  def install_stub(name, body)
    path = File.join(@bin, name)
    File.write(path, "#!/bin/bash\n#{body}")
    FileUtils.chmod(0o755, path)
  end
end
