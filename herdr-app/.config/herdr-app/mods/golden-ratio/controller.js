// Debounce, supersession and retry logic with an injected host. No herdr import, so node can load it.
import { drifted, planFor } from "./planner.js";

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

export class Controller {
  constructor(host, settings) {
    this.host = host;
    this.settings = resolveSettings(settings);
    this.token = 0;
    this.lastSeen = null;
    this.lastApplied = null;
  }

  onFocus() {
    try {
      const focus = this.host.focused();
      const key = keyOf(focus);
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
      this.lastApplied = keyOf(focus);
    } catch (error) {
      // A failed settle run leaves the layout as it is; the next focus change tries again.
    }
  }

  submit(steps) {
    for (const step of steps) this.host.run("layout.resize", { id: step.id, weight: step.weight });
  }
}
