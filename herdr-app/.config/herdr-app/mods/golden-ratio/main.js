// Golden ratio: after the focus settles on a pane, resize its tab so the focused pane gets the
// golden ratio of each axis it shares with siblings. No visible output. This file exports the planner
// and the controller for the node tests, which run them through a mod copy without the app.

import { View, div } from "gpui-kit";
import { exec, focused, panes, props, run } from "herdr";

// Pure planner: turns a tab tree into layout.resize steps.

const isContainer = (node) => Array.isArray(node.children);

function pathTo(node, paneId) {
  if (node.id === paneId && !isContainer(node)) return [node];
  for (const child of node.children || []) {
    const rest = pathTo(child, paneId);
    if (rest) return [node, ...rest];
  }
  return null;
}

function leafIds(node) {
  return isContainer(node) ? node.children.flatMap(leafIds) : [node.id];
}

const isAxis = (node) => node.type === "row" || node.type === "column";
const isPx = (node) => node.size && node.size.px !== undefined;
const weightOf = (node) => (node.size && typeof node.size.weight === "number" ? node.size.weight : 1);

function stepsAt(container, focused, target, minDelta) {
  if (isPx(focused)) return [];
  const siblings = container.children.filter((child) => child !== focused && !isPx(child));
  const total = siblings.reduce((sum, child) => sum + weightOf(child), 0);
  if (total <= 0) return [];
  const focusedWeight = weightOf(focused);
  if (Math.abs(focusedWeight / (focusedWeight + total) - target) <= minDelta) return [];
  const rest = siblings.map((child) => ({ id: child.id, weight: ((1 - target) * weightOf(child)) / total }));
  return [{ id: focused.id, weight: target }, ...rest];
}

/** Steps that give the focused pane's branch `ratio` at every container on its focus path. */
//: (Node, String, { ratio: Float, minDelta: Float }) -> Array[Step]
export function plan(tree, paneId, { ratio, minDelta }) {
  const path = pathTo(tree, paneId);
  if (!path) return [];
  const containers = path.slice(0, -1).filter(isAxis);
  const perAxis = {};
  for (const container of containers) perAxis[container.type] = (perAxis[container.type] || 0) + 1;
  return containers.flatMap((container) => {
    const target = Math.pow(ratio, 1 / perAxis[container.type]);
    return stepsAt(container, path[path.indexOf(container) + 1], target, minDelta);
  });
}

function spaceOf(document, focus) {
  return ((document && document.spaces) || []).find((candidate) => candidate.id === focus.space) || null;
}

function tabOf(document, focus) {
  const space = spaceOf(document, focus);
  if (!space || space.machine) return null;
  return space.tabs.find((tab) => tab.id === focus.tab) || null;
}

function tabPanes(panes, focus) {
  return panes.filter((pane) => pane.tab === focus.tab);
}

/** True when the focused tab is missing from the document or its leaf set differs from the live panes. A machine space stays quiet. */
//: (Document?, Focus, Array[PaneInfo]) -> bool
export function drifted(document, focus, panes) {
  const space = spaceOf(document, focus);
  if (space && space.machine) return false;
  const tab = tabOf(document, focus);
  if (!tab) return true;
  const known = leafIds(tab.root).sort();
  const live = tabPanes(panes, focus).map((pane) => pane.pane).sort();
  return known.length !== live.length || known.some((id, index) => id !== live[index]);
}

/** `plan` for the focused pane's tab, or [] when the tab is zoomed, drifted or holds one pane. */
//: (Document?, Focus, Array[PaneInfo], { ratio: Float, minDelta: Float }) -> Array[Step]
export function planFor(document, focus, panes, options) {
  const tab = tabOf(document, focus);
  if (!tab || drifted(document, focus, panes)) return [];
  if (tabPanes(panes, focus).some((pane) => pane.zoomed)) return [];
  return plan(tab.root, focus.pane, options);
}

// Debounce, supersession and retry logic with an injected host.

const DEFAULTS = { ratio: 0.618, debounce_ms: 120, min_delta: 0.02 };
const RANGES = { ratio: [0.05, 0.95], debounce_ms: [0, 2000], min_delta: [0, 0.5] };

function validSetting(name, value) {
  const [low, high] = RANGES[name];
  return typeof value === "number" && Number.isFinite(value) && value >= low && value <= high;
}

function resolveSettings(settings) {
  const given = settings || {};
  const resolved = {};
  for (const name of Object.keys(DEFAULTS)) {
    resolved[name] = validSetting(name, given[name]) ? given[name] : DEFAULTS[name];
  }
  return resolved;
}

const keyOf = (focus) => (focus ? `${focus.space}/${focus.tab}/${focus.pane}` : null);

const zoomedIn = (panes, focus) => panes.some((pane) => pane.tab === focus.tab && pane.zoomed);

export class Controller {
  constructor(host, settings) {
    this.host = host;
    this.settings = resolveSettings(settings);
    this.token = 0;
    this.lastSeen = null;
    this.lastApplied = null;
  }

  stateOf(focus) {
    return focus ? `${keyOf(focus)}/${zoomedIn(this.host.panes(), focus)}` : null;
  }

  onFocus() {
    try {
      const focus = this.host.focused();
      const key = this.stateOf(focus);
      if (key === this.lastSeen) return;
      this.lastSeen = key;
      this.token += 1;
      if (key === null || key === this.lastApplied) return;
      this.schedule(this.token, focus, 0);
    } catch (error) {
      // A focus read must never break rendering.
    }
  }

  schedule(token, focus, attempt) {
    this.host.after(this.settings.debounce_ms, () => this.settle(token, focus, attempt));
  }

  async settle(token, focus, attempt) {
    try {
      if (token !== this.token) return;
      const document = await this.host.readDocument();
      if (token !== this.token || keyOf(this.host.focused()) !== keyOf(focus)) return;
      const panes = this.host.panes();
      if (!document || drifted(document, focus, panes)) {
        if (attempt === 0) this.schedule(token, focus, 1);
        return;
      }
      this.submit(planFor(document, focus, panes, { ratio: this.settings.ratio, minDelta: this.settings.min_delta }));
      this.lastApplied = this.stateOf(focus);
    } catch (error) {
      // A failed settle run leaves the layout as it is; the next focus change tries again.
    }
  }

  submit(steps) {
    for (const step of steps) this.host.run("layout.resize", { id: step.id, weight: step.weight });
  }
}

// `hc connect` stays open until its input ends, so the shell holds stdin open for a second.
const READ_DOCUMENT =
  "( printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"doc.get\",\"params\":{\"name\":\"herdr-app\"}}'; sleep 1 ) | hc connect";

function firstReply(stdout) {
  for (const line of stdout.split("\n")) {
    try {
      const reply = JSON.parse(line);
      if (reply.id === 1) return reply;
    } catch (error) {
      // Not a JSON line; keep looking.
    }
  }
  return null;
}

async function readDocument() {
  try {
    const result = await exec("sh", ["-c", READ_DOCUMENT], { timeout: 5000 });
    return firstReply(result.stdout)?.result?.value ?? null;
  } catch (error) {
    return null;
  }
}

export default class GoldenRatio extends View {
  init(_props, cx) {
    const host = { focused, panes, readDocument, run, after: (ms, callback) => cx.timer.after(ms, callback) };
    this.controller = new Controller(host, props());
  }

  render() {
    this.controller.onFocus();
    return div();
  }
}
