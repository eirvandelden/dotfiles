#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"

# Phase 4 of herdr-app, the look: the sidebar on the right of the cores layout, the Solunized themes, the
# herdr TUI's cards on a frame, and a blue accent for personal spaces and an orange one for work spaces.
# The core-look mod picks the theme pair through pick.js, which imports nothing, so node runs it here.
class HerdrAppLookTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  PACKAGE = File.join(REPO_ROOT, "herdr-app/.config/herdr-app")
  PICK = File.join(PACKAGE, "mods/core-look/pick.js")
  GHOSTTY_THEMES = File.join(REPO_ROOT, "ghostty/.config/ghostty/themes")
  SOLUNIZED_DIR = ENV.fetch("SOLUNIZED_DIR", File.expand_path("~/Developer/solunized"))
  SHIPPED_TABS = File.expand_path("~/.config/herdr-app/mods/tabs")
  PERSONAL_PAIR = { "light" => "solunized-light-blue", "dark" => "solunized-dark-blue" }.freeze
  WORK_PAIR = { "light" => "solunized-light-orange", "dark" => "solunized-dark-orange" }.freeze
  PAIRS = { "personal" => PERSONAL_PAIR, "work" => WORK_PAIR }.freeze
  OWNED_THEMES = (PERSONAL_PAIR.values + WORK_PAIR.values).freeze
  WORK_MARK = "#ea8347".freeze
  SHIPPED_PADDING_TERM = " - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0)".freeze
  CLONED_PADDING = "Math.max(10, (root.traffic_lights[0] + 64) / settings().zoom)".freeze

  def test_the_sidebar_is_the_last_child_of_the_root
    assert_equal(%w[work sidebar], layout.fetch("children").map { |child| child["id"] })
  end

  def test_the_sidebar_keeps_the_spaces_and_agents_lists
    sidebar = find_node(layout, "sidebar")

    refute_nil(sidebar, "cores.json has no sidebar")
    assert_equal(%w[agents spaces-cores], collect_mods(sidebar).intersection(%w[spaces-cores agents]).sort)
  end

  def test_the_root_theme_is_the_personal_pair
    assert_equal(PERSONAL_PAIR, layout["theme"])
  end

  def test_the_core_look_block_names_the_root_pair_as_personal
    block = find_node(find_node(layout, "work"), "core-look")

    refute_nil(block, "the work column of cores.json has no core-look block")
    assert_equal("core-look", block.dig("content", "mod"))
    assert_equal(layout["theme"], block.dig("content", "props", "personal"))
    assert_equal(WORK_PAIR, block.dig("content", "props", "work"))
  end

  def test_the_tabs_bar_shows_the_cloned_tabs_mod
    assert_equal("tabs-cores", find_node(layout, "tabs")&.dig("content", "mod"))
    refute_includes(collect_mods(layout), "tabs")
  end

  def test_panes_are_cards_on_the_frame
    assert_equal(cards_on_a_frame, pane_frame)
    assert_equal("canvas", layout["background"])
    OWNED_THEMES.each do |name|
      colors = owned_theme(name).fetch("colors")

      refute_equal(colors.fetch("canvas"), colors.fetch("background"), "#{name}: cards must stand out from the frame")
      refute_includes(colors.values_at("canvas", "background"), colors.fetch("border"), "#{name}: the border must show")
    end
  end

  def test_settings_leave_the_accent_to_the_theme
    settings = JSON.parse(File.read(File.join(PACKAGE, "settings.json")))

    refute(settings.key?("colors"), "settings.json colors override every theme's accent: #{settings['colors']}")
  end

  def test_each_owned_theme_has_a_theme_file
    OWNED_THEMES.each do |name|
      theme = owned_theme(name)

      assert_equal(16, theme.fetch("ansi").size, name)
      %w[background foreground selection cursor].each { |key| assert_match(/\A#\h{6}\z/, theme.fetch(key), name) }
      assert_kind_of(Hash, theme.fetch("colors"), name)
    end
  end

  def test_the_herdr_app_themes_match_ghosttys_solunized_colors
    OWNED_THEMES.each do |name|
      appearance = name[/\Asolunized-(light|dark)-/, 1]

      assert_equal(ghostty_terminal_colors(appearance), terminal_colors(owned_theme(name)), name)
    end
  end

  def test_the_themes_match_the_solunized_dist
    dist = File.join(SOLUNIZED_DIR, "dist", "herdr-app")
    skip("no Solunized checkout at #{dist}") unless File.directory?(dist)

    OWNED_THEMES.each do |name|
      expected = File.read(File.join(dist, "#{name}.json"))

      assert_equal(expected, File.read(theme_path(name)), "#{name} drifted from #{dist}")
    end
  end

  def test_blue_and_orange_differ_only_in_the_accent
    %w[light dark].each do |appearance|
      blue = owned_theme(PERSONAL_PAIR.fetch(appearance))
      orange = owned_theme(WORK_PAIR.fetch(appearance))

      refute_equal(blue.dig("colors", "accent"), orange.dig("colors", "accent"), appearance)
      assert_equal(without_accent(blue), without_accent(orange), appearance)
    end
  end

  def test_no_focused_space_changes_nothing
    assert_nil(theme_pick(space: nil, shown: PERSONAL_PAIR))
  end

  def test_a_hand_picked_theme_is_left_alone
    assert_nil(theme_pick(space: { machine: "work" }, shown: { light: "paper", dark: "graphite" }))
  end

  def test_a_hand_pick_in_the_other_half_is_left_alone
    assert_nil(theme_pick(space: { machine: "work" }, shown: { light: "solunized-light-blue", dark: "graphite" }))
  end

  def test_a_shown_theme_that_fits_changes_nothing
    assert_nil(theme_pick(space: { machine: "work" }, shown: WORK_PAIR))
  end

  def test_an_owned_theme_that_does_not_fit_is_corrected
    shown = { light: "solunized-light-blue", dark: "solunized-dark-orange" }

    assert_equal(PERSONAL_PAIR, theme_pick(space: { machine: nil }, shown: shown))
  end

  def test_a_work_space_asks_for_the_work_pair
    assert_equal(WORK_PAIR, theme_pick(space: { machine: "work" }, shown: PERSONAL_PAIR))
  end

  def test_a_personal_space_asks_for_the_personal_pair
    assert_equal(PERSONAL_PAIR, theme_pick(space: { machine: nil }, shown: WORK_PAIR))
  end

  def test_core_look_never_edits_the_layout
    sources = %w[main.js pick.js].to_h { |name| [ name, mod_source("core-look", name) ] }

    assert_includes(sources.fetch("main.js"), "app.theme")
    sources.each { |name, source| refute_includes(source, "layout.set", name) }
  end

  def test_work_spaces_share_one_fixed_mark
    source = mod_source("spaces-cores", "main.js")

    assert(source.include?(%(const WORK_MARK = "#{WORK_MARK}";)), "spaces-cores defines no WORK_MARK #{WORK_MARK}")
    assert(source.match?(/const color = w\.machine \? WORK_MARK : \(colors\[w\.id\] \?\? "ansi6"\);/),
           "spaces-cores row() does not draw WORK_MARK for a work space")
  end

  def test_no_personal_mark_is_the_work_orange
    marks = personal_marks

    assert_equal("#d9b02a", marks["ansi3"])
    marks.each do |name, color|
      assert_operator(hue_distance(color, WORK_MARK), :>=, 20, "MARK.#{name} #{color} looks like the work mark")
    end
  end

  def test_the_cloned_tabs_mod_pads_without_the_sidebar_width
    source = mod_source("tabs-cores", "main.js")

    assert_includes(source, CLONED_PADDING)
    refute_includes(source, "sidebar?.size?.px")
  end

  def test_the_cloned_tabs_mod_differs_from_tabs_only_in_the_padding
    shipped_main = File.join(SHIPPED_TABS, "main.js")
    skip("no shipped tabs mod at #{SHIPPED_TABS}") unless File.file?(shipped_main)
    shipped = File.read(shipped_main)

    assert_includes(shipped, SHIPPED_PADDING_TERM, "the shipped tabs mod changed its padding: re-clone it")
    assert_equal(cloned_main(shipped), mod_source("tabs-cores", "main.js"))
    assert_clone_names_tabs_as_its_source
    shipped_assets.each do |path|
      assert_equal(File.binread(path), File.binread(File.join(mod_folder("tabs-cores"), File.basename(path))), path)
    end
  end

  def test_herdr_app_accepts_the_core_look_mod
    assert_herdr_app_accepts("core-look")
  end

  def test_herdr_app_accepts_the_cloned_spaces_mod
    assert_herdr_app_accepts("spaces-cores")
  end

  def test_herdr_app_accepts_the_cloned_tabs_mod
    assert_herdr_app_accepts("tabs-cores")
  end

  private

  def layout
    @layout ||= JSON.parse(File.read(File.join(PACKAGE, "layouts/cores.json")))
  end

  def find_node(node, id)
    case node
    when Hash
      return node if node["id"] == id

      node.each_value.lazy.filter_map { |child| find_node(child, id) }.first
    when Array then node.lazy.filter_map { |child| find_node(child, id) }.first
    end
  end

  def collect_mods(node)
    case node
    when Hash then [ node["mod"] ].grep(String) + node.each_value.flat_map { |child| collect_mods(child) }
    when Array then node.flat_map { |child| collect_mods(child) }
    else []
    end
  end

  def pane_frame
    pane = find_node(layout, "main").dig("content", "pane")
                                    .slice("background", "border", "focus", "radius", "gap", "lone")
    body = find_node(layout, "work-body").slice("padding", "gap")

    { "pane" => pane, "body" => body }
  end

  def cards_on_a_frame
    {
      "pane" => {
        "background" => "background", "border" => { "width" => 1, "color" => "border" },
        "focus" => { "width" => 1, "color" => "accent" }, "radius" => 10, "gap" => 8, "lone" => true
      },
      "body" => { "padding" => 8, "gap" => 8 }
    }
  end

  def theme_path(name)
    File.join(PACKAGE, "themes/#{name}.json")
  end

  def owned_theme(name)
    path = theme_path(name)
    flunk("no theme file #{path}") unless File.file?(path)

    JSON.parse(File.read(path))
  end

  def terminal_colors(theme)
    theme.slice("background", "foreground", "selection", "cursor").merge("ansi" => theme.fetch("ansi"))
         .transform_values { |value| value.is_a?(Array) ? value.map(&:downcase) : value.downcase }
  end

  # Ghostty's solunized theme, named as a herdr-app theme names its terminal colors.
  def ghostty_terminal_colors(appearance)
    settings = File.readlines(File.join(GHOSTTY_THEMES, "solunized-#{appearance}"), chomp: true)
                   .filter_map { |line| line.split(/\s*=\s*/, 2) if line.include?("=") }
    palette = settings.select { |key, _| key == "palette" }.to_h { |_, value| value.split("=", 2) }
    plain = settings.reject { |key, _| key == "palette" }.to_h

    {
      "background" => plain.fetch("background"), "foreground" => plain.fetch("foreground"),
      "selection" => plain.fetch("selection-background"), "cursor" => plain.fetch("cursor-color"),
      "ansi" => (0..15).map { |index| palette.fetch(index.to_s) }
    }.transform_values { |value| value.is_a?(Array) ? value.map(&:downcase) : value.downcase }
  end

  def without_accent(theme)
    theme.merge("colors" => theme.fetch("colors").except("accent"))
  end

  def mod_folder(mod)
    File.join(PACKAGE, "mods", mod)
  end

  def mod_source(mod, name)
    path = File.join(mod_folder(mod), name)
    flunk("no #{path}") unless File.file?(path)

    File.read(path)
  end

  # The shipped tabs main.js as `herdr-app do mod.clone` writes it (asset paths under mods/tabs-cores/),
  # with the one hand edit: the padding drops the sidebar-width term.
  def cloned_main(shipped)
    shipped.gsub("mods/tabs/", "mods/tabs-cores/").sub(SHIPPED_PADDING_TERM, "")
  end

  # mod.clone adds cloned_from to mod.json and changes nothing else in it.
  def assert_clone_names_tabs_as_its_source
    shipped = JSON.parse(File.read(File.join(SHIPPED_TABS, "mod.json")))
    clone = JSON.parse(mod_source("tabs-cores", "mod.json"))

    assert_equal("tabs", clone.dig("cloned_from", "name"))
    assert_equal(shipped, clone.except("cloned_from"))
  end

  # Every file of the shipped tabs mod that the clone keeps unchanged: not main.js, not mod.json (the clone
  # names its source there), and nothing herdr-app generates.
  def shipped_assets
    names = Dir.children(SHIPPED_TABS).reject do |name|
      %w[main.js mod.json jsconfig.json].include?(name) || name.end_with?(".d.ts")
    end
    names.map { |name| File.join(SHIPPED_TABS, name) }
  end

  def personal_marks
    marks = mod_source("spaces-cores", "main.js")[/^const MARK = \{([^}]*)\};/, 1]
    flunk("spaces-cores has no MARK palette") unless marks

    marks.scan(/(\w+): "(#\h{6})"/).to_h
  end

  def hue_distance(first, second)
    distance = (hue(first) - hue(second)).abs % 360
    [ distance, 360 - distance ].min
  end

  def hue(color)
    red, green, blue = color.delete_prefix("#").scan(/\h\h/).map { |pair| pair.to_i(16) / 255.0 }
    min, max = [ red, green, blue ].minmax
    spread = max - min
    return 0.0 if spread.zero?

    60 * sector(red, green, blue, max, spread)
  end

  def sector(red, green, blue, max, spread)
    if max == red then ((green - blue) / spread) % 6
    elsif max == green then ((blue - red) / spread) + 2
    else ((red - green) / spread) + 4
    end
  end

  # Runs pick.js's themePick on the given space and shown halves with the owned pairs. Returns the parsed
  # result; the string "undefined" when themePick returned undefined instead of null.
  def theme_pick(space:, shown:)
    skip("node is not installed") unless installed?("node")
    flunk("no #{PICK}") unless File.file?(PICK)
    script = <<~JS
      const { themePick } = await import(process.argv[1]);
      const result = themePick(JSON.parse(process.argv[2]));
      process.stdout.write(JSON.stringify(result === undefined ? "undefined" : result));
    JS
    input = JSON.generate(space: space, shown: shown, pairs: PAIRS)
    stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, "--", "file://#{PICK}", input)

    assert(status.success?, stderr)
    JSON.parse(stdout)
  end

  def assert_herdr_app_accepts(mod)
    skip("herdr-app is not installed") unless installed?("herdr-app")

    output, status = Dir.mktmpdir("hal", "/tmp") do |home|
      Open3.capture2e({ "HERDR_APP_HOME" => home }, "herdr-app", "check", mod_folder(mod))
    end

    assert(status.success?, output)
  end

  def installed?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end
end
