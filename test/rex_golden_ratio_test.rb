#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require_relative "isolated_git"

# GoldenRatio.plan (rex/.config/rex/golden_ratio.lua) turns a tiled layout and a focused block
# into the resize steps that give that block the golden share. It is pure Lua, so luajit runs it
# here with no `rex` global; the tests skip when luajit is missing.
class RexGoldenRatioTest < Minitest::Test
  LUA_DIR = File.expand_path("../rex/.config/rex", __dir__)
  TARGET = 0.618
  CONFIG = { ratio: TARGET, min_delta: 0.02 }.freeze

  def test_a_ratio_outside_the_allowed_range_is_refused
    layout = pair("a", "b")

    [ 0.04, 0.96, 0, 1.5 ].each do |ratio|
      error = assert_raises(RuntimeError, "ratio #{ratio} was accepted") do
        steps(layout, "a", ratio: ratio)
      end
      assert_match(/ratio/, error.message)
    end
  end

  def test_a_single_pane_needs_no_steps
    assert_empty(steps(leaf("a"), "a"))
  end

  def test_a_missing_block_needs_no_steps
    assert_empty(steps(pair("a", "b"), "zzz"))
  end

  def test_a_settled_layout_needs_no_steps
    assert_empty(steps(pair("a", "b", ratio: TARGET), "a"))
    assert_empty(steps(pair("a", "b", ratio: TARGET - 0.01), "a"))
    assert_empty(steps(pair("a", "b", ratio: 1 - TARGET), "b"))
  end

  def test_a_split_just_outside_min_delta_is_resized
    result = steps(pair("a", "b", ratio: TARGET - 0.05), "a")

    assert_equal(1, result.size)
  end

  def test_two_panes_give_the_focused_one_the_golden_share
    step = steps(pair("a", "b"), "a").fetch(0)

    assert_equal(%w[horizontal a b], step.values_at(:direction, :before, :after))
    assert_in_delta(TARGET, step[:ratio], 0.001)
  end

  def test_the_share_flips_when_the_focused_block_is_on_the_after_side
    step = steps(pair("a", "b"), "b").fetch(0)

    assert_equal(%w[a b], step.values_at(:before, :after))
    assert_in_delta(1 - TARGET, step[:ratio], 0.001)
  end

  def test_a_vertical_split_gives_a_vertical_step
    step = steps(pair("a", "b", direction: "vertical"), "a").fetch(0)

    assert_equal("vertical", step[:direction])
    assert_in_delta(TARGET, step[:ratio], 0.001)
  end

  def test_three_flat_panes_give_the_focused_one_the_golden_width
    layout = split("horizontal", 0.5, leaf("a"), pair("b", "c"))

    result = steps(layout, "b")

    assert_equal(2, result.size)
    assert_in_delta(TARGET, share(result, "b", "horizontal"), 0.001)
  end

  def test_steps_run_outermost_split_first
    layout = split("horizontal", 0.5, leaf("a"), pair("b", "c"))

    result = steps(layout, "b")

    assert_equal(%w[a b], result[0].values_at(:before, :after))
    assert_equal(%w[b c], result[1].values_at(:before, :after))
  end

  def test_a_step_names_the_first_leaf_of_the_sibling_subtree
    layout = split("horizontal", 0.5, leaf("a"), split("vertical", 0.5, leaf("b"), leaf("c")))

    first = steps(layout, "a").fetch(0)

    assert_equal(%w[a b], first.values_at(:before, :after))
  end

  def test_nested_focus_gets_the_golden_share_on_both_axes
    layout = split("horizontal", 0.5, leaf("a"), split("vertical", 0.5, leaf("b"), leaf("c")))

    result = steps(layout, "c")

    assert_in_delta(TARGET, share(result, "c", "horizontal"), 0.001)
    assert_in_delta(TARGET, share(result, "c", "vertical"), 0.001)
  end

  def test_the_shares_on_each_axis_multiply_to_the_target
    layout = split("horizontal", 0.3,
                   split("vertical", 0.7, leaf("a"), split("horizontal", 0.5, leaf("b"), leaf("c"))),
                   split("horizontal", 0.4, leaf("d"), split("vertical", 0.5, leaf("e"), leaf("f"))))

    %w[a b c d e f].each do |focused|
      result = steps(layout, focused)
      %w[horizontal vertical].each do |direction|
        next unless result.any? { |step| step[:direction] == direction }

        assert_in_delta(TARGET, share(result, focused, direction), 0.001, "#{focused} #{direction}")
      end
    end
  end

  def test_a_twenty_deep_path_still_multiplies_to_the_target
    layout = leaf("focus")
    20.times { |depth| layout = split("horizontal", 0.5, layout, leaf("other#{depth}")) }

    result = steps(layout, "focus")

    assert_equal(20, result.size)
    assert_in_delta(TARGET, share(result, "focus", "horizontal"), 0.001)
  end

  def test_plan_runs_without_a_rex_global
    output = run_lua(<<~LUA)
      assert(rawget(_G, "rex") == nil, "rex global is defined")
      local plan = require("golden_ratio").plan
      local layout = #{lua(pair("a", "b"))}
      print(#plan(layout, "a", #{lua(CONFIG)}))
    LUA

    assert_equal(%w[1], output)
  end

  private

  # The focused block's share of the layout on one axis after the steps run.
  def share(steps, focused, direction)
    steps.select { |step| step[:direction] == direction }
         .map { |step| step[:before] == focused ? step[:ratio] : 1 - step[:ratio] }
         .reduce(1.0, :*)
  end

  def leaf(id)
    { rect: [ 0, 0, 1, 1 ], block_id: id }
  end

  def split(direction, ratio, before, after)
    { rect: [ 0, 0, 1, 1 ], split: { split_id: "s#{before.hash.abs}#{after.hash.abs}", direction: direction,
                                     ratio: ratio, before: before, after: after } }
  end

  def pair(before_id, after_id, ratio: 0.5, direction: "horizontal")
    split(direction, ratio, leaf(before_id), leaf(after_id))
  end

  def steps(layout, focused, ratio: TARGET)
    config = CONFIG.merge(ratio: ratio)
    lines = run_lua(<<~LUA)
      local plan = require("golden_ratio").plan
      for _, step in ipairs(plan(#{lua(layout)}, #{focused.dump}, #{lua(config)})) do
        print(table.concat({ step.direction, step.before_block_id, step.after_block_id, string.format("%.6f", step.ratio) }, "\\t"))
      end
    LUA
    lines.map do |line|
      direction, before, after, ratio_text = line.split("\t")
      { direction: direction, before: before, after: after, ratio: ratio_text.to_f }
    end
  end

  def run_lua(body)
    skip("luajit is not on PATH") unless system("command -v luajit >/dev/null 2>&1")
    script = "package.path = \"#{LUA_DIR}/?.lua;\" .. package.path\n#{body}"
    stdout, stderr, status = Open3.capture3("luajit", "-", stdin_data: script)
    raise(stderr.strip.lines.first.to_s.strip) unless status.success?

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
