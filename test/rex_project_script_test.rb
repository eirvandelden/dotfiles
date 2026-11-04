#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# rex/.config/rex/project/pick.sh lists git projects from REX_PROJECT_ROOTS as `name<TAB>path` rows for fzf,
# then opens or reuses the picked project's session and selects it. `rex` and `fzf` are stubs on PATH that
# log their calls, one per line. jq is real.
class RexProjectScriptTest < Minitest::Test
  PICK = File.expand_path("../rex/.config/rex/project/pick.sh", __dir__)

  def setup
    @dir = Dir.mktmpdir
    @bin = File.join(@dir, "bin")
    FileUtils.mkdir_p(@bin)
    @root_a = File.join(@dir, "a")
    @root_b = File.join(@dir, "b")
    build_roots
    install_rex_stub
    install_fzf_stub
    answer_rex(sessions: [], select_exit: 0)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_lists_only_folders_with_a_git_entry_from_every_root
    pick("")

    assert_equal(
      [ "dotfiles\t#{@root_a}/dotfiles", "webapp\t#{@root_a}/webapp", "eirvandelden.github.io\t#{@root_b}/eirvandelden.github.io" ],
      fzf_rows.sort_by { |row| [ row.include?(@root_a) ? 0 : 1, row ] }
    )
    assert_equal(%w[--delimiter --with-nth], fzf_argv.select { |arg| arg.start_with?("--d", "--w") }.map { |arg| arg.sub(/=.*/, "") })
  end

  def test_picking_a_new_project_creates_its_session_and_selects_it
    _, stderr, status = pick("dotfiles\t#{@root_a}/dotfiles", client: "client-42")

    assert_predicate(status, :success?, stderr)
    assert_equal(
      [ "ls --json", "new dotfiles -c #{@root_a}/dotfiles --json", "-C client-42 do session.select session_id=new-id" ],
      rex_calls
    )
  end

  def test_picking_an_open_project_only_selects_its_session
    answer_rex(sessions: [ { "label" => "dotfiles", "session_id" => "open-1" } ], select_exit: 0)

    pick("dotfiles\t#{@root_a}/dotfiles", client: "client-42")

    assert_equal([ "ls --json", "-C client-42 do session.select session_id=open-1" ], rex_calls)
  end

  def test_escape_makes_no_rex_call
    _, _, status = pick("")

    assert_equal(0, status.exitstatus)
    assert_empty(rex_calls)
  end

  def test_a_refused_select_keeps_the_session_and_prints_a_hint
    answer_rex(sessions: [], select_exit: 1)

    stdout, _, status = pick("dotfiles\t#{@root_a}/dotfiles", client: "client-42")

    assert_equal(0, status.exitstatus)
    assert_includes(stdout, "Remote Control")
    assert_includes(stdout, "dotfiles")
    assert(rex_calls.any? { |call| call.start_with?("new dotfiles") }, "the session must be created")
    refute(rex_calls.any? { |call| call.start_with?("kill", "rm", "close", "delete") }, "the session must stay")
  end

  def test_nested_repositories_are_not_listed
    pick("")

    refute_empty(fzf_rows)
    refute(fzf_rows.any? { |row| row.include?("nested") || row.include?("inner") }, fzf_rows.inspect)
    refute(fzf_rows.any? { |row| row.start_with?("conductor", "archive") }, fzf_rows.inspect)
  end

  def test_a_pick_makes_at_most_three_rex_calls
    pick("dotfiles\t#{@root_a}/dotfiles")

    assert_operator(rex_calls.size, :<=, 3)
    refute_empty(rex_calls)
  end

  private

  def build_roots
    FileUtils.mkdir_p([ "#{@root_a}/dotfiles/.git", "#{@root_a}/webapp", "#{@root_a}/conductor",
                        "#{@root_a}/nested/inner/.git", "#{@root_b}/eirvandelden.github.io/.git", "#{@root_b}/archive" ])
    File.write("#{@root_a}/webapp/.git", "gitdir: ../elsewhere\n")
  end

  def pick(selection, client: "c1")
    roots = [ @root_a, File.join(@dir, "missing"), @root_b ].join(":")
    Open3.capture3({ "PATH" => "#{@bin}:#{ENV.fetch('PATH')}", "STUB_DIR" => @dir,
                     "REX_PROJECT_ROOTS" => roots, "FZF_SELECTION" => selection },
                   "bash", PICK, client, stdin_data: "\n")
  end

  def rex_calls
    read_log("rex.log")
  end

  def fzf_argv
    read_log("fzf.argv")
  end

  def fzf_rows
    read_log("fzf.stdin")
  end

  def read_log(name)
    path = File.join(@dir, name)
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  def answer_rex(sessions:, select_exit:)
    File.write(File.join(@dir, "ls.json"), "#{JSON.generate({ 'sessions' => sessions })}\n")
    File.write(File.join(@dir, "select_exit"), select_exit.to_s)
  end

  def install_rex_stub
    install_stub("rex", <<~'BASH')
      echo "$*" >> "$STUB_DIR/rex.log"
      case "$1" in
        ls) cat "$STUB_DIR/ls.json" ;;
        new) echo '{"session_id":"new-id","label":"x"}' ;;
        -C) exit "$(cat "$STUB_DIR/select_exit")" ;;
      esac
    BASH
  end

  def install_fzf_stub
    install_stub("fzf", <<~'BASH')
      printf '%s\n' "$@" >> "$STUB_DIR/fzf.argv"
      cat > "$STUB_DIR/fzf.stdin"
      [ -n "$FZF_SELECTION" ] || exit 130
      printf '%s\n' "$FZF_SELECTION"
    BASH
  end

  def install_stub(name, body)
    path = File.join(@bin, name)
    File.write(path, "#!/bin/bash\n#{body}")
    FileUtils.chmod(0o755, path)
  end
end
