#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require_relative "herdr_app_mod_copy"
require_relative "isolated_git"

# Tests for the herdr-app golden-ratio mod. The pure logic (plan, drifted, planFor) and the debounce logic
# (Controller) are exports of main.js; they run through `node` on a mod copy with module stubs for the
# host modules. The mod's loading is checked by `herdr-app check`.
#
# The contract these tests pin down (plan.md leaves the details open):
#
# - Tab tree node: {type: "row"|"column"|"block", id, children?, size?: {weight}|{px}}. A missing size
#   means weight 1. A block is a pane and its id is the pane id.
# - plan(tree, paneId, {ratio, minDelta}) -> [{id, weight}, ...]. The focused branch gets weight
#   ratio^(1/n) at each container of the focus path; each weighted sibling gets (1 - t) * w / S.
# - Document: {spaces: [{id, machine?, tabs: [{id, root}]}]}.
# - focus: {space, tab, pane}, the shape of `focused()`.
# - panes: [{pane, tab, zoomed, focused}], the shape of PaneInfo.
# - planFor(document, focus, panes, {ratio, minDelta}) -> steps.
# - Controller settings: {ratio, debounce_ms, min_delta}; a missing or invalid value means its default.
# - Controller host: focused() -> focus; panes() -> panes; readDocument() -> Promise of the document, or
#   null when the read failed; run(command, args) with command "layout.resize" and args {id, weight};
#   after(ms, callback) schedules a timer and has no cancel (the controller supersedes by token).
# - controller.onFocus() is synchronous, never throws, and starts the debounce when the focus differs
#   from the last one it saw. The settle run is the timer callback; it may return a promise.
# - The fake clock fires every pending timer on demand, then lets pending promises settle.
module NodeRunner
  include HerdrAppModCopy

  PRELUDE = <<~JS.freeze
    const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
    const leaves = (node) => (node.children ? node.children.flatMap(leaves) : [node.id]);
    const nodes = (node) => [node, ...(node.children || []).flatMap(nodes)];
    const apply = (tree, steps) => {
      for (const step of steps) nodes(tree).find((node) => node.id === step.id).size = { weight: step.weight };
    };
    function harness({ focus, panes, documents, settings }) {
      const state = { focus, runs: [], timers: [], reads: 0, afters: [] };
      const host = {
        focused: () => state.focus,
        panes: () => panes,
        readDocument: async () => {
          const index = Math.min(state.reads, documents.length - 1);
          state.reads += 1;
          return documents[index];
        },
        run: (command, args) => { state.runs.push({ command, args }); return null; },
        after: (ms, callback) => { state.afters.push(ms); state.timers.push(callback); },
      };
      const clock = {
        async fire() {
          const due = state.timers.splice(0);
          for (const callback of due) callback();
          await flush();
        },
      };
      return { state, host, clock, controller: new Controller(host, settings) };
    }
  JS

  #: (String, ?Hash[Symbol, untyped]) -> untyped
  def run_node(body, input = {})
    run_script do |url|
      <<~JS
        import { drifted, plan, planFor, Controller } from "#{url}";
        #{PRELUDE}
        const input = #{JSON.generate(input)};
        const output = await (async () => { #{body} })();
        console.log(JSON.stringify(output));
      JS
    end
  end

  #: (String, ?Hash[Symbol, untyped]) -> untyped
  def run_planner(body, input = {})
    run_script do |url|
      <<~JS
        import { drifted, plan, planFor } from "#{url}";
        #{PRELUDE.lines.first(6).join}
        const input = #{JSON.generate(input)};
        console.log(JSON.stringify((() => { #{body} })()));
      JS
    end
  end

  # Runs the script the block builds from the golden-ratio mod copy's URL.
  #: () { (String) -> String } -> untyped
  def run_script
    stdout, stderr, status = with_mod_copy("golden-ratio") do |url|
      Open3.capture3("node", "--input-type=module", "-e", yield(url))
    end
    flunk("node failed: #{stderr.lines.first(6).join}") unless status.success?

    JSON.parse(stdout)
  end

  def setup
    skip "node is not installed" unless system("node", "--version", out: File::NULL, err: File::NULL)
  end

  def block(id, size = nil)
    { "type" => "block", "id" => id }.merge(size ? { "size" => size } : {})
  end

  def row(id, *children, size: nil)
    { "type" => "row", "id" => id, "children" => children }.merge(size ? { "size" => size } : {})
  end

  def column(id, *children, size: nil)
    { "type" => "column", "id" => id, "children" => children }.merge(size ? { "size" => size } : {})
  end

  def stack(id, *children)
    { "type" => "stack", "id" => id, "children" => children }
  end

  def document(root, machine: nil, tab: "t1")
    space = { "id" => "s1", "tabs" => [ { "id" => tab, "root" => root } ] }
    space["machine"] = machine if machine
    { "spaces" => [ space ] }
  end

  def pane_infos(ids, tab: "t1", zoomed: false, focused: ids.first)
    ids.map { |id| { "pane" => id, "tab" => tab, "zoomed" => zoomed, "focused" => id == focused } }
  end

  def focus_on(pane, tab: "t1")
    { "space" => "s1", "tab" => tab, "pane" => pane }
  end

  def options
    { "ratio" => 0.618, "minDelta" => 0.02 }
  end

  def assert_steps(expected, actual)
    assert_equal(expected.keys.sort, actual.map { |step| step["id"] }.sort)
    actual.each { |step| assert_in_delta(expected.fetch(step["id"]), step["weight"], 0.001, step["id"]) }
  end
end

class HerdrAppGoldenRatioTest < Minitest::Test
  class PlannerTest < Minitest::Test
    include NodeRunner

    def plan_for_tree(tree, pane, opts = options)
      run_planner("return plan(input.tree, input.pane, input.options);", tree: tree, pane: pane, options: opts)
    end

    def test_plan_ignores_a_pane_that_is_not_in_the_tree
      assert_empty(plan_for_tree(row("r", block("a"), block("b")), "ghost"))
    end

    def test_single_pane_gets_no_step
      assert_empty(plan_for_tree(block("a"), "a"))
      assert_empty(plan_for_tree(row("r", block("a")), "a"))
    end

    def test_zoomed_tab_gets_no_step
      document = document(row("r", block("a"), block("b")))
      steps = run_planner(
        "return planFor(input.document, input.focus, input.panes, input.options);",
        document: document, focus: focus_on("a"), panes: pane_infos(%w[a b], zoomed: true), options: options
      )

      assert_empty(steps)
    end

    def test_plan_skips_a_container_whose_siblings_have_no_weight
      tree = row("r", block("a"), block("b", { "weight" => 0 }), block("c", { "weight" => 0 }))

      assert_empty(plan_for_tree(tree, "a"))
    end

    def test_pane_within_min_delta_gets_no_step
      tree = row("r", block("a", { "weight" => 0.62 }), block("b", { "weight" => 0.38 }))

      assert_empty(plan_for_tree(tree, "a"))
    end

    def test_side_by_side_pair_gives_the_focused_pane_the_golden_ratio
      assert_steps({ "a" => 0.618, "b" => 0.382 }, plan_for_tree(row("r", block("a"), block("b")), "a"))
    end

    def test_stacked_pair_gives_the_focused_pane_the_golden_ratio
      assert_steps({ "b" => 0.618, "a" => 0.382 }, plan_for_tree(column("c", block("a"), block("b")), "b"))
    end

    def test_nested_layout_balances_every_shared_axis
      tree = column("c", row("r", block("a"), block("b")), block("d"))

      assert_steps({ "r" => 0.618, "d" => 0.382, "a" => 0.618, "b" => 0.382 }, plan_for_tree(tree, "a"))
    end

    def test_repeated_axis_nesting_multiplies_to_the_golden_ratio
      tree = row("outer", row("inner", block("a"), block("b")), block("d"))
      share = Math.sqrt(0.618)

      assert_steps(
        { "inner" => share, "d" => 1 - share, "a" => share, "b" => 1 - share }, plan_for_tree(tree, "a")
      )
    end

    def test_plan_keeps_the_relative_weights_of_three_siblings
      tree = row("r", block("a"), block("b", { "weight" => 2 }), block("c"))

      assert_steps({ "a" => 0.618, "b" => 0.382 * 2 / 3, "c" => 0.382 / 3 }, plan_for_tree(tree, "a"))
    end

    def test_px_sibling_is_never_in_a_step
      tree = row("r", block("a"), block("p", { "px" => 200 }), block("b"))

      assert_steps({ "a" => 0.618, "b" => 0.382 }, plan_for_tree(tree, "a"))
    end

    def test_plan_returns_only_ids_in_the_tree
      tree = column("c", row("r", block("a"), block("b")), block("d"))
      ids = run_planner("return nodes(input.tree).map((node) => node.id);", tree: tree)

      plan_for_tree(tree, "a").each { |step| assert_includes(ids, step["id"]) }
    end

    def test_plan_is_idempotent
      tree = column("c", row("r", block("a"), block("b", { "weight" => 3 })), block("d"))
      again = run_planner(<<~JS, tree: tree, pane: "a", options: options)
        apply(input.tree, plan(input.tree, input.pane, input.options));
        return plan(input.tree, input.pane, input.options);
      JS

      assert_empty(again)
    end

    def test_drifted_tab_gets_no_step
      document = document(row("r", block("a"), block("b")))
      steps = run_planner(
        "return planFor(input.document, input.focus, input.panes, input.options);",
        document: document, focus: focus_on("a"), panes: pane_infos(%w[a b c]), options: options
      )

      assert_empty(steps)
    end

    def test_plan_for_skips_a_pane_of_another_tab
      document = { "spaces" => [ { "id" => "s1", "tabs" => [
        { "id" => "t1", "root" => row("r1", block("a"), block("b")) },
        { "id" => "t2", "root" => row("r2", block("c"), block("d")) }
      ] } ] }
      panes = pane_infos(%w[c d], tab: "t2")
      call = "return planFor(input.document, input.focus, input.panes, input.options);"
      input = { document: document, panes: panes, options: options }

      assert_steps({ "c" => 0.618, "d" => 0.382 }, run_planner(call, input.merge(focus: focus_on("c", tab: "t2"))))
      assert_empty(run_planner(call, input.merge(focus: focus_on("c", tab: "t1"))))
    end

    def test_plan_for_skips_a_pane_of_a_space_with_a_machine
      call = "return planFor(input.document, input.focus, input.panes, input.options);"
      input = { focus: focus_on("a"), panes: pane_infos(%w[a b]), options: options }
      tree = row("r", block("a"), block("b"))

      assert_steps({ "a" => 0.618, "b" => 0.382 }, run_planner(call, input.merge(document: document(tree))))
      assert_empty(run_planner(call, input.merge(document: document(tree, machine: "laptop"))))
    end

    def test_plan_ignores_a_stack_container
      assert_empty(plan_for_tree(stack("s", block("a"), block("b")), "a"))
      tree = row("r", stack("s", block("a"), block("b")), block("d"))

      assert_steps({ "s" => 0.618, "d" => 0.382 }, plan_for_tree(tree, "a"))
    end

    def test_plan_for_reports_a_tab_missing_from_the_document_as_drift
      call = "return drifted(input.document, input.focus, input.panes);"
      tree = row("r", block("a"), block("b"))
      input = { focus: focus_on("a", tab: "t2"), panes: pane_infos(%w[a b], tab: "t2") }

      assert(run_planner(call, input.merge(document: document(tree, tab: "t1"))), "missing tab")
      assert(run_planner(call, input.merge(document: { "spaces" => [] })), "missing space")
      refute(run_planner(call, input.merge(document: document(tree, tab: "t2"))), "tab present")
      refute(run_planner(call, input.merge(document: document(tree, tab: "t2", machine: "laptop"))), "machine")
    end
  end

  class ControllerTest < Minitest::Test
    include NodeRunner

    def pair_input(**overrides)
      tree = row("r", block("a"), block("b"))
      { focus: focus_on("a"), panes: pane_infos(%w[a b]), documents: [ document(tree) ], settings: {} }.merge(overrides)
    end

    def test_on_focus_ignores_an_unchanged_focus
      timers = run_node(<<~JS, pair_input)
        const h = harness(input);
        h.controller.onFocus();
        h.controller.onFocus();
        return h.state.timers.length;
      JS

      assert_equal(1, timers)
    end

    def test_on_focus_skips_the_last_applied_pair
      runs = run_node(<<~JS, pair_input(focus_b: focus_on("b")))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        const applied = h.state.runs.length;
        h.state.focus = input.focus_b;
        h.controller.onFocus();
        h.state.focus = input.focus;
        h.controller.onFocus();
        await h.clock.fire();
        return { applied, total: h.state.runs.length };
      JS

      assert_equal(2, runs["applied"])
      assert_equal(2, runs["total"])
    end

    def test_on_focus_swallows_a_throwing_host
      outcome = run_node(<<~JS, pair_input)
        const h = harness(input);
        let thrown = false;
        h.host.focused = () => { throw new Error("focused broke"); };
        try { h.controller.onFocus(); } catch (error) { thrown = true; }
        const g = harness(input);
        g.host.run = () => { throw new Error("run broke"); };
        try { g.controller.onFocus(); await g.clock.fire(); } catch (error) { thrown = true; }
        return { thrown };
      JS

      refute(outcome["thrown"])
    end

    def test_rapid_focus_changes_submit_one_batch_for_the_last_pane
      outcome = run_node(<<~JS, pair_input(focus_b: focus_on("b")))
        const h = harness(input);
        h.controller.onFocus();
        h.state.focus = input.focus_b;
        h.controller.onFocus();
        h.state.focus = input.focus;
        h.controller.onFocus();
        const before = h.state.runs.length;
        await h.clock.fire();
        return { before, runs: h.state.runs };
      JS

      assert_equal(0, outcome["before"])
      assert_equal(%w[a b], outcome["runs"].map { |run| run.dig("args", "id") }.sort)
      assert_in_delta(0.618, outcome["runs"].find { |run| run.dig("args", "id") == "a" }.dig("args", "weight"), 0.001)
    end

    def test_settings_change_ratio_debounce_and_min_delta
      outcome = run_node(<<~JS, pair_input(settings: { ratio: 0.7, debounce_ms: 300, min_delta: 0.1 }))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        return { afters: h.state.afters, runs: h.state.runs };
      JS

      assert_equal([ 300 ], outcome["afters"])
      weights = outcome["runs"].to_h { |run| [ run.dig("args", "id"), run.dig("args", "weight") ] }
      assert_in_delta(0.7, weights.fetch("a"), 0.001)
      assert_in_delta(0.3, weights.fetch("b"), 0.001)
    end

    def test_invalid_settings_fall_back_to_defaults
      outcome = run_node(<<~JS, pair_input(settings: { ratio: 2, debounce_ms: -5, min_delta: "wide" }))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        return { afters: h.state.afters, runs: h.state.runs };
      JS

      assert_equal([ 120 ], outcome["afters"])
      weights = outcome["runs"].to_h { |run| [ run.dig("args", "id"), run.dig("args", "weight") ] }
      assert_in_delta(0.618, weights.fetch("a"), 0.001)
    end

    def test_focus_change_during_the_document_read_submits_nothing
      runs = run_node(<<~JS, pair_input(focus_b: focus_on("b")))
        const h = harness(input);
        let release;
        h.host.readDocument = () => new Promise((resolve) => { release = () => resolve(input.documents[0]); });
        h.controller.onFocus();
        await h.clock.fire();
        h.state.focus = input.focus_b;
        h.controller.onFocus();
        release();
        await flush();
        return h.state.runs;
      JS

      assert_empty(runs)
    end

    def test_failed_read_retries_once_then_stays_quiet
      outcome = run_node(<<~JS, pair_input(documents: [ nil, nil, nil ]))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        const retryScheduled = h.state.timers.length;
        await h.clock.fire();
        await h.clock.fire();
        return { retryScheduled, reads: h.state.reads, runs: h.state.runs.length, pending: h.state.timers.length };
      JS

      assert_equal(1, outcome["retryScheduled"])
      assert_equal(2, outcome["reads"])
      assert_equal(0, outcome["runs"])
      assert_equal(0, outcome["pending"])
    end

    def test_document_that_lags_a_split_is_retried
      lagging = document(row("r", block("a")))
      current = document(row("r", block("a"), block("b")))
      outcome = run_node(<<~JS, pair_input(documents: [ lagging, current ]))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        const afterFirst = h.state.runs.length;
        await h.clock.fire();
        return { afterFirst, runs: h.state.runs.length };
      JS

      assert_equal(0, outcome["afterFirst"])
      assert_equal(2, outcome["runs"])
    end

    def test_focus_change_emits_layout_resize_commands_from_the_document
      tree = column("c", row("r", block("a"), block("b")), block("d"))
      input = pair_input(documents: [ document(tree) ], panes: pane_infos(%w[a b d]))
      runs = run_node(<<~JS, input)
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        return h.state.runs;
      JS

      assert(runs.all? { |run| run["command"] == "layout.resize" })
      weights = runs.to_h { |run| [ run.dig("args", "id"), run.dig("args", "weight") ] }
      assert_equal(%w[a b d r], weights.keys.sort)
      assert_in_delta(0.618, weights.fetch("a"), 0.001)
      assert_in_delta(0.618, weights.fetch("r"), 0.001)
    end

    def test_document_missing_the_fresh_tab_is_retried_then_applied
      stale = document(row("r", block("x"), block("y")), tab: "t0")
      current = document(row("r", block("a"), block("b")))
      outcome = run_node(<<~JS, pair_input(documents: [ stale, current ]))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        const afterFirst = { runs: h.state.runs.length, retry: h.state.timers.length };
        await h.clock.fire();
        return { afterFirst, runs: h.state.runs.length, pending: h.state.timers.length };
      JS

      assert_equal({ "runs" => 0, "retry" => 1 }, outcome["afterFirst"])
      assert_equal(2, outcome["runs"])
      assert_equal(0, outcome["pending"])
    end

    def test_machine_space_is_never_retried
      tree = row("r", block("a"), block("b"))
      outcome = run_node(<<~JS, pair_input(documents: [ document(tree, machine: "laptop") ]))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        const retry = h.state.timers.length;
        await h.clock.fire();
        return { retry, reads: h.state.reads, runs: h.state.runs.length };
      JS

      assert_equal({ "retry" => 0, "reads" => 1, "runs" => 0 }, outcome)
    end

    def test_unzooming_the_same_pane_rebalances
      outcome = run_node(<<~JS, pair_input(zoomed: pane_infos(%w[a b], zoomed: true)))
        const h = harness(input);
        const unzoomed = input.panes;
        h.host.panes = () => input.zoomed;
        h.controller.onFocus();
        await h.clock.fire();
        const whileZoomed = h.state.runs.length;
        h.host.panes = () => unzoomed;
        h.controller.onFocus();
        await h.clock.fire();
        return { whileZoomed, runs: h.state.runs.length };
      JS

      assert_equal(0, outcome["whileZoomed"])
      assert_equal(2, outcome["runs"])
    end

    def test_a_no_op_pass_still_marks_the_pair_applied
      tree = row("r", block("a", { "weight" => 0.618 }), block("b", { "weight" => 0.382 }))
      outcome = run_node(<<~JS, pair_input(documents: [ document(tree) ], focus_b: focus_on("b")))
        const h = harness(input);
        h.controller.onFocus();
        await h.clock.fire();
        h.state.focus = input.focus_b;
        h.controller.onFocus();
        h.state.timers.length = 0;
        h.state.focus = input.focus;
        h.controller.onFocus();
        return { timers: h.state.timers.length, runs: h.state.runs.length };
      JS

      assert_equal({ "timers" => 0, "runs" => 0 }, outcome)
    end
  end
end
