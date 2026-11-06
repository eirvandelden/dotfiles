#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# rex/.config/rex/init.lua binds keys. herdr owns ctrl+s, so no Rex Lua file binds a ctrl+s key;
# every other binding stays. The files are read as text: Rex is not available to run them. One test is
# the exception: luajit loads init.lua with a stub `rex` that records actions and binds, and it skips without luajit.
# The settings.json hooks are read as text too.
class RexConfigTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  LUA_DIR = File.join(ROOT, "rex/.config/rex")
  INIT = File.join(LUA_DIR, "init.lua")
  SETTINGS = File.join(ROOT, "claude/.claude/settings.json")
  UNBOUND_ACTIONS = %w[
    agent_switcher open_project file_viewer file_viewer_split file_viewer_tab lazygit_split lazygit_tab
  ].freeze
  CTRL_S_KEY = /\Actrl\+s(>|\z)/
  TONE_HOOKS = { "SessionStart" => "ready", "Notification" => "request", "Stop" => "done" }.freeze
  BIND = /^\s*rex\.bind\("(?<key>[^"]+)",\s*"(?<action>[^"]+)"(?:,\s*\{(?<options>.*)\})?\)/

  KEPT = {
    "cmd+k" => [ "com.superlogical.terminal.clear", nil ],
    "ctrl+3" => [ "pane.send_key", 'key = "esc"' ],
    "ctrl+4" => [ "pane.send_key", 'key = "ctrl+\\\\"' ],
    "ctrl+5" => [ "pane.send_key", 'key = "ctrl+]"' ],
    "ctrl+6" => [ "pane.send_key", 'key = "ctrl+shift+6"' ],
    "ctrl+7" => [ "pane.send_key", 'key = "ctrl+shift+-"' ],
    "ctrl+8" => [ "pane.send_key", 'key = "backspace"' ],
    "ctrl+-" => [ "pane.send_key", 'key = "ctrl+shift+-"' ],
    "ctrl+up" => [ "client.prompt.previous", nil ],
    "ctrl+down" => [ "client.prompt.next", nil ]
  }.freeze

  def test_no_lua_file_binds_ctrl_s
    Dir.glob(File.join(LUA_DIR, "*.lua")).each do |file|
      File.readlines(file).filter_map { |line| BIND.match(line) }.each do |match|
        refute_match(CTRL_S_KEY, match[:key], "#{File.basename(file)} binds #{match[:key]}, but herdr owns ctrl+s")
      end
    end
  end

  def test_ctrl_up_and_ctrl_down_move_between_prompts
    assert_equal("client.prompt.previous", bindings.fetch("ctrl+up").first)
    assert_equal("client.prompt.next", bindings.fetch("ctrl+down").first)
  end

  def test_the_switcher_is_required_and_has_no_key_bind
    assert_match(/require\("switcher"\)/, init_text)
    refute_includes(bindings.values.map(&:first), "agent_switcher")
  end

  def test_the_project_action_is_required_and_has_no_key_bind
    assert_match(/require\("project"\)/, init_text)
    refute_includes(bindings.values.map(&:first), "open_project")
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

  def test_the_viewer_launchers_run_worktree_viewer
    launchers = File.read(File.join(LUA_DIR, "launchers.lua"))

    assert_match(/worktree-viewer.{0,40}split/m, launchers)
    assert_match(/worktree-viewer.{0,40}tab/m, launchers)
  end

  def test_the_loaded_config_registers_every_action_and_binds_no_ctrl_s_key
    skip("luajit is not installed") unless system("which luajit > /dev/null 2>&1")

    actions, binds = load_config

    assert_equal(UNBOUND_ACTIONS.sort, (actions & UNBOUND_ACTIONS).sort)
    assert_empty(binds.values & UNBOUND_ACTIONS)
    assert_empty(binds.keys.grep(CTRL_S_KEY))
  end

  def test_settings_json_has_the_rex_session_start_hook
    commands = hook_commands.fetch("SessionStart")

    assert(commands.any? { |command| command.include?("rex __internal session-start --agent claude") }, commands.inspect)
  end

  def test_hooks_play_the_three_tones
    TONE_HOOKS.each do |event, tone|
      commands = hook_commands.fetch(event)

      assert(commands.any? { |command| command.match?(%r{play-tone\.sh #{tone}\b}) }, "#{event}: #{commands.inspect}")
    end
  end

  def test_session_start_plays_its_tone_only_on_startup
    entry = JSON.parse(File.read(SETTINGS)).dig("hooks", "SessionStart")
                .find { |candidate| candidate["hooks"].any? { |hook| hook["command"].include?("play-tone.sh ready") } }

    assert_equal("startup", entry["matcher"])
  end

  private

  def hook_commands
    JSON.parse(File.read(SETTINGS)).fetch("hooks").transform_values do |entries|
      entries.flat_map { |entry| entry["hooks"].map { |hook| hook["command"].to_s } }
    end
  end

  # Loads init.lua and every module it requires under luajit with a `rex` stub that accepts every call
  # and records `rex.action{name=...}` and `rex.bind(key, action)`. Returns the action names and the binds.
  def load_config
    Dir.mktmpdir do |dir|
      script = File.join(dir, "load.lua")
      File.write(script, lua_loader)
      output, error, status = Open3.capture3("luajit", script, LUA_DIR)
      assert(status.success?, error)
      lines = output.lines(chomp: true)
      [ lines.filter_map { |line| line[/\Aaction (\S+)/, 1] },
        lines.filter_map { |line| line.match(/\Abind (\S+) (\S+)/) }.to_h { |match| [ match[1], match[2] ] } ]
    end
  end

  def lua_loader
    <<~LUA
      local dir = arg[1]
      package.path = dir .. "/?.lua;" .. package.path
      local function permissive()
        return setmetatable({}, { __index = function() return permissive() end, __call = function() return permissive() end })
      end
      rex = permissive()
      rex.action = function(spec) print("action " .. tostring(spec.name)) end
      rex.bind = function(key, action) print("bind " .. key .. " " .. tostring(action)) end
      dofile(dir .. "/init.lua")
    LUA
  end

  def init_text
    File.read(INIT)
  end

  def bindings
    init_text.lines.filter_map { |line| BIND.match(line) }
             .to_h { |match| [ match[:key], [ match[:action], match[:options] ] ] }
  end
end
