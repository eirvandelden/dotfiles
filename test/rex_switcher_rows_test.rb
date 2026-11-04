#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# SwitcherRows.lines (rex/.config/rex/switcher_rows.lua) turns collected panes into snapshot rows.
# It is pure Lua, so luajit runs it here; the tests skip when luajit is missing.
class RexSwitcherRowsTest < Minitest::Test
  LUA_DIR = File.expand_path("../rex/.config/rex", __dir__)

  def test_every_row_has_eight_fields
    rows = lines([ pane(block_id: "b1", records: [ { state: "working", msg: "x" } ]), pane(block_id: "b2") ])

    assert_equal(2, rows.size)
    rows.each { |row| assert_equal(8, row.split("\t", -1).size, row.inspect) }
  end

  def test_a_pane_without_a_record_is_a_shell
    rows = lines([ pane(records: []), pane(records: nil) ])

    assert_equal(%w[shell shell], rows.map { |row| fields(row)[0] })
  end

  def test_a_blocked_child_record_beats_a_working_root
    records = [ { state: "working", msg: "root busy" }, { state: "blocked", msg: "needs approval" } ]

    row = fields(lines([ pane(records: records) ]).first)

    assert_equal("blocked", row[0])
    assert_equal("needs approval", row[4])
  end

  def test_lines_takes_the_most_urgent_record_and_its_message
    records = [ { state: "idle", msg: "i" }, { state: "working", msg: "w" },
                { state: "done", msg: "d" }, { state: "error", msg: "e" } ]

    row = fields(lines([ pane(records: records) ]).first)

    assert_equal(%w[error e], [ row[0], row[4] ])
  end

  def test_lines_sorts_blocked_error_done_working_idle_shell
    panes = %w[shell idle working done error blocked].map do |state|
      pane(block_id: state, records: state == "shell" ? [] : [ { state: state, msg: "" } ])
    end

    assert_equal(%w[blocked error done working idle shell], lines(panes).map { |row| fields(row)[0] })
  end

  def test_lines_turns_tabs_and_newlines_into_spaces
    row = lines([ pane(session: "a\tb", tab: "c\nd", program: "e\tf", cwd: "/g\nh",
                       records: [ { state: "done", msg: "i\tj\nk" } ]) ]).first
    cells = fields(row)

    assert_equal(8, cells.size)
    assert_equal("a b / c d", cells[1])
    assert_equal("e f", cells[2])
    assert_equal("/g h", cells[3])
    assert_equal("i j k", cells[4])
  end

  def test_session_and_tab_form_field_two_and_ids_close_the_row
    row = fields(lines([ pane(records: []) ]).first)

    assert_equal("Work / Tab 1", row[1])
    assert_equal(%w[s1 w1 b1], row[5..7])
  end

  def test_the_program_comes_from_the_most_urgent_record
    records = [ { state: "working", effective_app: "claude-code" }, { state: "blocked", effective_app: "terraform" } ]

    row = fields(lines([ pane(program: "zsh", records: records) ]).first)

    assert_equal("terraform", row[2])
  end

  def test_a_record_without_an_app_keeps_the_panes_program
    row = fields(lines([ pane(program: "zsh", records: [ { state: "done", msg: "ok" } ]) ]).first)

    assert_equal("zsh", row[2])
  end

  def test_a_file_url_becomes_a_decoded_path
    assert_equal("/Users/etienne/Library/Application Support", path_of("file://host/Users/etienne/Library/Application%20Support"))
    assert_equal("/plain/path", path_of("/plain/path"))
  end

  private

  def path_of(url)
    skip("luajit is not on PATH") unless system("command -v luajit >/dev/null 2>&1")
    script = <<~LUA
      package.path = "#{LUA_DIR}/?.lua;" .. package.path
      print(require("switcher_rows").path(#{url.dump}))
    LUA
    stdout, stderr, status = Open3.capture3("luajit", "-", stdin_data: script)
    assert(status.success?, "luajit failed: #{stderr}")
    stdout.chomp
  end

  def pane(overrides = {})
    { session_id: "s1", session: "Work", window_id: "w1", tab: "Tab 1", block_id: "b1",
      program: "claude", cwd: "/tmp", records: [] }.merge(overrides)
  end

  def fields(row)
    row.split("\t", -1)
  end

  def lines(panes)
    skip("luajit is not on PATH") unless system("command -v luajit >/dev/null 2>&1")
    script = <<~LUA
      package.path = "#{LUA_DIR}/?.lua;" .. package.path
      local R = require("switcher_rows")
      for _, line in ipairs(R.lines(#{lua(panes)})) do print(line) end
    LUA
    stdout, stderr, status = Open3.capture3("luajit", "-", stdin_data: script)
    assert(status.success?, "luajit failed: #{stderr}")
    stdout.lines(chomp: true)
  end

  def lua(value)
    case value
    when Hash then "{ #{value.map { |key, item| "#{key} = #{lua(item)}" }.join(', ')} }"
    when Array then "{ #{value.map { |item| lua(item) }.join(', ')} }"
    when String then value.dump
    when nil then "nil"
    else value.to_s
    end
  end
end
