// Golden ratio: after the focus settles on a pane, resize its tab so the focused pane gets the
// golden ratio of each axis it shares with siblings. No visible output. The logic lives in
// planner.js and controller.js, which node tests load without the app.

import { View, div } from "gpui-kit";
import { exec, focused, panes, props, run } from "herdr";
import { Controller } from "./controller.js";

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
