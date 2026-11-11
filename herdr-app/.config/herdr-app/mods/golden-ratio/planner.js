// Pure planner: turns a tab tree into layout.resize steps. No herdr import, so node can load it.

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
export function planFor(document, focus, panes, options) {
  const tab = tabOf(document, focus);
  if (!tab || drifted(document, focus, panes)) return [];
  if (tabPanes(panes, focus).some((pane) => pane.zoomed)) return [];
  return plan(tab.root, focus.pane, options);
}
