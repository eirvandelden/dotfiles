#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require_relative "isolated_git"

# keys.json gives herdr-app a `;` leader: `; t` and its siblings, written once in the `global` section,
# which GPUI applies inside terminals too, so `; space` opens the `picker` mod there as well. The file
# must also work on Linux, where `cmd` is the Super key, and keep herdr-app's own defaults. The tests
# read the tracked file only; CI runs on Linux without herdr-app.
class HerdrAppKeysTest < Minitest::Test
  KEYS = File.expand_path("../herdr-app/.config/herdr-app/keys.json", __dir__)

  ARROWS = %w[left right up down].freeze

  # The intent's phase 3 key map, with the plan's design decisions applied.
  LEADER_MAP = {
    "; ;" => "send:;",
    "; t" => "tab.new",
    "; n" => "tab.next",
    "; p" => "tab.prev",
    "; ]" => "space.next",
    "; [" => "space.prev",
    "; a" => "agent.next",
    "; shift-a" => "agent.prev",
    "; d" => "mod.open:agents-done",
    "; b" => "mod.open:agents-blocked",
    "; v" => "pane.split:right",
    "; -" => "pane.split:down",
    "; x" => "pane.close",
    "; w" => "pane.close",
    "; shift-x" => "tab.close",
    "; z" => "pane.zoom",
    "; shift-b" => "layout.toggle:sidebar",
    "; space" => "mod.open:picker",
    "; shift-n" => "space.new",
    "; shift-w" => "space.rename",
    "; shift-t" => "tab.rename",
    "; shift-d" => "space.close",
    "; f" => "layout.toggle:panel",
    "; shift-f" => { "command" => "tab.new", "args" => { "mod" => "files", "name" => "Files" } },
    "; g" => { "command" => "pane.split", "args" => { "direction" => "right", "argv" => [ "lazygit" ] } },
    "; shift-g" => { "command" => "tab.new", "args" => { "name" => "lazygit", "argv" => [ "lazygit" ] } },
    "; /" => "terminal.search",
    "; shift-p" => "app.palette",
    "; ?" => "app.help",
    "; ," => "app.settings"
  }.merge(
    (1..9).to_h { |index| [ "; #{index}", "tab.select:#{index}" ] },
    (1..9).to_h { |index| [ "; shift-#{index}", "space.select:#{index}" ] },
    ARROWS.to_h { |direction| [ "; #{direction}", "pane.go:#{direction}" ] },
    ARROWS.to_h { |direction| [ "; shift-#{direction}", "pane.swap:#{direction}" ] }
  ).freeze

  # Each ctrl-alt-cmd chord with the leader key it repeats in one keypress.
  CHORD_TWINS = {
    "ctrl-alt-cmd-n" => "; n",
    "ctrl-alt-cmd-p" => "; p",
    "ctrl-alt-cmd-]" => "; ]",
    "ctrl-alt-cmd-[" => "; [",
    "ctrl-alt-cmd-a" => "; a",
    "ctrl-alt-cmd-shift-a" => "; shift-a"
  }.merge(
    ARROWS.to_h { |direction| [ "ctrl-alt-cmd-#{direction}", "; #{direction}" ] },
    ARROWS.to_h { |direction| [ "ctrl-alt-cmd-shift-#{direction}", "; shift-#{direction}" ] }
  ).freeze

  # Each table spelling with the spelling the shifted character produces. macOS matches both to one
  # keypress; Linux needs both.
  SHIFTED_SPELLINGS = {
    "; shift-1" => "; !",
    "; shift-2" => "; @",
    "; shift-3" => "; #",
    "; shift-4" => "; $",
    "; shift-5" => "; %",
    "; shift-6" => "; ^",
    "; shift-7" => "; &",
    "; shift-8" => "; *",
    "; shift-9" => "; (",
    "; ?" => "; shift-/"
  }.freeze

  # herdr-app's own Linux defaults for the actions the leader map leaves out.
  LINUX_GLOBAL_DEFAULTS = {
    "ctrl-=" => "app.zoom_in",
    "ctrl-+" => "app.zoom_in",
    "ctrl--" => "app.zoom_out",
    "ctrl-0" => "app.zoom_reset",
    "ctrl-shift-l" => "layout.switch",
    "ctrl-shift-k" => "mod.open:picker"
  }.freeze

  # macOS app-menu actions with no Linux meaning.
  MACOS_ONLY_ACTIONS = %w[app.quit app.hide app.hide_others].freeze

  # keys.json on origin/main before this change (`git show origin/main:herdr-app/.config/herdr-app/keys.json`).
  ORIGINAL_BINDINGS = {
    "global" => {
      "cmd-q" => "app.quit",
      "cmd-h" => "app.hide",
      "cmd-alt-h" => "app.hide_others",
      "cmd-t" => "tab.new",
      "cmd-w" => "tab.close",
      "ctrl-tab" => "tab.next",
      "ctrl-shift-tab" => "tab.prev",
      "cmd-shift-]" => "tab.next",
      "cmd-shift-[" => "tab.prev",
      "cmd-alt-]" => "space.next",
      "cmd-alt-[" => "space.prev",
      "cmd-]" => "agent.next",
      "cmd-[" => "agent.prev",
      "cmd-shift-l" => "layout.switch",
      "cmd-n" => "space.new",
      "cmd-p" => "mod.open:picker",
      "cmd-shift-p" => "app.palette",
      "cmd-," => "app.settings",
      "cmd-d" => "pane.split:right",
      "cmd-shift-d" => "pane.split:down",
      "cmd-shift-w" => "pane.close",
      "cmd-shift-enter" => "pane.zoom",
      "cmd-alt-left" => "pane.go:left",
      "cmd-alt-right" => "pane.go:right",
      "cmd-alt-up" => "pane.go:up",
      "cmd-alt-down" => "pane.go:down",
      "cmd-alt-shift-left" => "pane.swap:left",
      "cmd-alt-shift-right" => "pane.swap:right",
      "cmd-alt-shift-up" => "pane.swap:up",
      "cmd-alt-shift-down" => "pane.swap:down",
      "f2" => "tab.rename",
      "shift-f2" => "space.rename",
      "cmd-/" => "app.help",
      "cmd-shift-/" => "app.help",
      "cmd-b" => "layout.toggle:sidebar",
      "cmd-=" => "app.zoom_in",
      "cmd-+" => "app.zoom_in",
      "cmd--" => "app.zoom_out",
      "cmd-0" => "app.zoom_reset"
    }.merge(
      (1..9).to_h { |index| [ "cmd-#{index}", "tab.select:#{index}" ] },
      (1..9).to_h { |index| [ "ctrl-#{index}", "space.select:#{index}" ] }
    ),
    "terminal" => {
      "cmd-f" => "terminal.search",
      "cmd-c" => "terminal.copy",
      "cmd-v" => "terminal.paste",
      "ctrl-v" => "terminal.paste_image",
      "alt-left" => "send:\eb",
      "alt-right" => "send:\ef",
      "alt-backspace" => "send:\u0017",
      "cmd-left" => "send:\u0001",
      "cmd-right" => "send:\u0005",
      "cmd-backspace" => "send:\u0015"
    }
  }.freeze

  # Command and argument names from `Herdr commands`, herdr-app 0.1.15 (2026-11-11).
  COMMANDS = {
    "space.new" => %w[name folder tab argv task machine],
    "space.close" => %w[id confirmed],
    "space.rename" => %w[id name],
    "space.move" => %w[id index],
    "tab.new" => %w[name space folder argv task mod props],
    "tab.close" => %w[id confirmed],
    "tab.rename" => %w[id name],
    "tab.move" => %w[id index],
    "pane.split" => %w[direction pane argv mod props],
    "pane.close" => %w[pane],
    "terminal.open" => %w[argv folder place name],
    "terminal.keep" => %w[terminal place],
    "terminal.park" => %w[terminal],
    "terminal.right_click" => %w[to terminal],
    "terminal.pin" => %w[terminal pinned],
    "terminal.kill" => %w[terminal],
    "space.select" => %w[index id],
    "space.next" => [],
    "space.prev" => [],
    "tab.select" => %w[index id],
    "tab.settle" => %w[id],
    "tab.unsettle" => %w[id],
    "tab.next" => [],
    "tab.prev" => [],
    "pane.zoom" => %w[pane],
    "pane.focus" => %w[pane terminal],
    "pane.go" => %w[direction],
    "pane.swap" => %w[direction pane target],
    "terminal.peek" => %w[terminal],
    "terminal.show" => %w[terminal pane],
    "terminal.copy" => [],
    "terminal.scroll" => %w[lines pages to terminal],
    "terminal.paste" => [],
    "terminal.paste_image" => [],
    "terminal.search" => [],
    "agent.focus" => %w[terminal],
    "agent.next" => [],
    "agent.prev" => [],
    "layout.switch" => %w[name],
    "layout.clone" => %w[name as],
    "mod.clone" => %w[name as],
    "layout.set" => %w[layout],
    "layout.toggle" => %w[id],
    "layout.show" => %w[id],
    "layout.hide" => %w[id],
    "layout.resize" => %w[id px weight],
    "layout.select" => %w[stack child],
    "layout.reset" => %w[name],
    "mod.open" => %w[name],
    "overlay.close" => %w[id],
    "app.help" => [],
    "app.welcome" => [],
    "app.whats_new" => [],
    "app.feedback" => %w[message from],
    "app.palette" => [],
    "app.settings" => %w[section],
    "app.check_updates" => [],
    "app.update_core" => [],
    "app.reset" => [],
    "app.theme" => %w[name],
    "app.zoom_in" => [],
    "app.zoom_out" => [],
    "app.zoom_reset" => [],
    "app.update" => [],
    "app.quit" => [],
    "app.hide" => [],
    "app.hide_others" => [],
    "app.show_all" => [],
    "window.close" => [],
    "window.minimize" => [],
    "window.maximize" => []
  }.freeze

  # herdr-app 0.1.15's shipped mods, for `<mod>.<command>` bindings.
  SHIPPED_MODS = %w[
    agents changes confirm files help machine-add menu new-menu pane peek picker prompt spaces tabs
    terminals-bar terminals-pane toast win98 workspace-chrome workspace-status worktree
  ].freeze

  def test_the_leader_map_binds_every_row
    assert_equal(LEADER_MAP, section("global").slice(*LEADER_MAP.keys))
  end

  def test_the_chords_repeat_their_leader_twins
    twins = CHORD_TWINS.transform_values { |leader_key| LEADER_MAP.fetch(leader_key) }

    assert_equal(twins, section("global").slice(*CHORD_TWINS.keys))
  end

  def test_every_action_is_reachable_without_cmd
    assert_equal(LINUX_GLOBAL_DEFAULTS, section("global").slice(*LINUX_GLOBAL_DEFAULTS.keys))

    reachable = terminal_bindings.reject { |key, _action| uses_cmd?(key) }.values
    missing = cmd_actions.reject { |action| reachable.include?(action) }

    assert_empty(missing, "bound only under a cmd key, so Linux needs the Super key")
  end

  def test_object_bindings_name_real_commands_and_arguments
    objects = all_actions.grep(Hash)

    refute_empty(objects, "keys.json has no object bindings")
    objects.each { |action| assert_real_command_and_arguments(action) }
    all_actions.grep(String).each do |action|
      assert(known_string_action?(action), "unknown command in #{action.inspect}")
    end
  end

  def test_semicolon_twice_types_one_semicolon
    assert_equal("send:;", terminal_bindings["; ;"])
    refute(all_keys.any? { |key| key.match?(/\A; (shift-)?enter\z/) }, "`; enter` must stay unbound")
  end

  #: -> void
  def test_space_opens_the_picker_in_a_terminal
    refute(section("terminal").key?("; space"), "a terminal override hides the picker")
    assert_equal("mod.open:picker", terminal_bindings["; space"])
  end

  def test_terminal_copy_and_paste_work_without_super
    assert_equal(
      { "ctrl-shift-c" => "terminal.copy", "ctrl-shift-v" => "terminal.paste" },
      section("terminal").slice("ctrl-shift-c", "ctrl-shift-v")
    )
  end

  def test_shifted_keys_have_both_spellings
    global = section("global")

    SHIFTED_SPELLINGS.each do |table, other|
      action = LEADER_MAP.fetch(table)

      assert_equal([ action, action ], global.values_at(table, other), "#{table} and #{other}")
    end
  end

  def test_the_cmd_defaults_stay
    ORIGINAL_BINDINGS.each do |name, bindings|
      assert_equal(bindings, section(name).slice(*bindings.keys), name)
    end
  end

  private

  #: -> Hash[String, Hash[String, untyped]]
  def keys
    @keys ||= JSON.parse(File.read(KEYS))
  end

  #: (String) -> Hash[String, untyped]
  def section(name)
    keys.fetch(name, {})
  end

  # What a key does with a terminal focused: a terminal binding wins over a global one.
  #: -> Hash[String, untyped]
  def terminal_bindings
    section("global").merge(section("terminal"))
  end

  #: -> Array[String]
  def all_keys
    section("global").keys + section("terminal").keys
  end

  #: -> Array[untyped]
  def all_actions
    section("global").values + section("terminal").values
  end

  # The actions bound under a cmd key, less the macOS app-menu ones and the `send:` of one control
  # byte, such as cmd-left's ctrl-a, which a Linux user types directly.
  #: -> Array[untyped]
  def cmd_actions
    (section("global").to_a + section("terminal").to_a)
      .select { |key, _action| uses_cmd?(key) }
      .map(&:last)
      .uniq
      .reject { |action| MACOS_ONLY_ACTIONS.include?(action) || typed_control_byte?(action) }
  end

  #: (String) -> bool
  def uses_cmd?(key)
    key.split(" ").any? { |stroke| stroke.match?(/(?:\A|-)cmd-/) }
  end

  #: (untyped) -> bool
  def typed_control_byte?(action)
    action.is_a?(String) && action.match?(/\Asend:[\u0000-\u001f]\z/)
  end

  #: (Hash[String, untyped]) -> void
  def assert_real_command_and_arguments(action)
    command = action["command"]

    assert_includes(COMMANDS.keys, command, "unknown command in #{action.inspect}")
    assert_empty(action.fetch("args", {}).keys - COMMANDS.fetch(command), "unknown argument in #{action.inspect}")
  end

  #: (String) -> bool
  def known_string_action?(action)
    command = action.split(":", 2).first
    return true if command == "send" || COMMANDS.key?(command)

    mod, name = command.split(".", 2)
    !name.nil? && mods.include?(mod)
  end

  #: -> Array[String]
  def mods
    SHIPPED_MODS + Dir.children(File.join(File.dirname(KEYS), "mods"))
  end
end
