#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# rex/.config/rex/init.lua binds keys. The switcher replaces only ctrl+s>space; every other
# binding stays. The file is read as text: Rex is not available to run it.
class RexConfigTest < Minitest::Test
  INIT = File.expand_path("../rex/.config/rex/init.lua", __dir__)
  BIND = /^\s*rex\.bind\("(?<key>[^"]+)",\s*"(?<action>[^"]+)"(?:,\s*\{(?<options>.*)\})?\)/

  KEPT = {
    "cmd+k" => [ "com.superlogical.terminal.clear", nil ],
    "ctrl+s>ctrl+s" => [ "pane.send_key", 'key = "ctrl+s"' ],
    "ctrl+s>left" => [ "pane.focus", 'direction = "left"' ],
    "ctrl+s>down" => [ "pane.focus", 'direction = "down"' ],
    "ctrl+s>up" => [ "pane.focus", 'direction = "up"' ],
    "ctrl+s>right" => [ "pane.focus", 'direction = "right"' ],
    "ctrl+3" => [ "pane.send_key", 'key = "esc"' ],
    "ctrl+4" => [ "pane.send_key", 'key = "ctrl+\\\\"' ],
    "ctrl+5" => [ "pane.send_key", 'key = "ctrl+]"' ],
    "ctrl+6" => [ "pane.send_key", 'key = "ctrl+shift+6"' ],
    "ctrl+7" => [ "pane.send_key", 'key = "ctrl+shift+-"' ],
    "ctrl+8" => [ "pane.send_key", 'key = "backspace"' ],
    "ctrl+-" => [ "pane.send_key", 'key = "ctrl+shift+-"' ]
  }.freeze

  def test_ctrl_s_space_opens_the_switcher
    assert_equal("agent_switcher", bindings.fetch("ctrl+s>space").first)
    assert_match(/require\("switcher"\)/, init_text)
  end

  def test_ctrl_s_o_opens_the_project_picker
    assert_equal("open_project", bindings.fetch("ctrl+s>o").first)
    assert_match(/require\("project"\)/, init_text)
  end

  def test_the_file_viewer_is_required_and_has_no_key_bind
    assert_match(/require\("viewer"\)/, init_text)
    refute_includes(bindings.values.map(&:first), "file_viewer")
  end

  def test_shift_cmd_k_keeps_session_switch
    assert_equal("session.switch", bindings.fetch("shift+cmd+k").first)
  end

  def test_every_other_current_binding_is_kept
    KEPT.each do |key, (action, options)|
      found_action, found_options = bindings.fetch(key) { flunk("binding #{key} is missing") }

      assert_equal(action, found_action, key)
      if options.nil?
        assert_nil(found_options&.strip, key)
      else
        assert_equal(options, found_options&.strip, key)
      end
    end
  end

  private

  def init_text
    File.read(INIT)
  end

  def bindings
    init_text.lines.filter_map { |line| BIND.match(line) }
             .to_h { |match| [ match[:key], [ match[:action], match[:options] ] ] }
  end
end
