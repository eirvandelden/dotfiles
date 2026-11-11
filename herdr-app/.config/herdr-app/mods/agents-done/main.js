// A list of the running agents of one status. `mod.json`'s overlay props name the status ("done" or
// "blocked") and the title. Up/down and Enter show an agent, Esc leaves. agents-blocked/main.js is a
// symlink to this file.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { agents, theme, run, props, closeOverlay } from "herdr";

export default class AgentList extends View {
  init(_props, cx) {
    this.at = 0;
    this.handle = cx.focus_handle();
    this.handle.focus();
    cx.timer.after(600, () => this.handle.focus());
  }

  close() {
    closeOverlay(props()?.overlay);
  }

  rows() {
    const status = props()?.status;
    if (!status) return [];
    return agents().filter((a) => a.status === status);
  }

  go(row) {
    if (!row) return;
    this.close();
    run("agent.focus", { terminal: row.address });
  }

  render() {
    const t = theme();
    const status = props()?.status;
    const rows = this.rows();
    this.at = rows.length ? Math.min(this.at, rows.length - 1) : 0;
    const empty = status ? `No ${status} agents` : 'Set "overlay.props.status" in mod.json';
    const line = (a, i) =>
      h_flex()
        .id(`al-${a.address}`)
        .mx(4)
        .px(10)
        .h(32)
        .rounded(7)
        .gap(10)
        .items_center()
        .cursor_pointer()
        .when(i === this.at, (el) => el.bg(t.hover))
        .hover((s) => s.bg(t.hover))
        .on_click(() => this.go(a))
        .child(div().flex_1().truncate().text_color(t.foreground).child(a.tab_name))
        .child(div().text_size(11).text_color(t.dim).child(`${a.space_name} · ${a.app ?? "agent"}`));

    return v_flex()
      .id("agent-list")
      .track_focus(this.handle)
      .w_full()
      .min_h(0)
      .p(18)
      .gap(10)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "escape") return this.close();
        if (k === "enter") this.go(rows[this.at]);
        else if (k === "down" && rows.length) this.at = (this.at + 1) % rows.length;
        else if (k === "up" && rows.length) this.at = (this.at + rows.length - 1) % rows.length;
        else if (k !== "down" && k !== "up") return;
        cx.stop_propagation();
        cx.notify();
      })
      .child(
        h_flex()
          .items_center()
          .child(div().flex_1().text_size(15).font_semibold().text_color(t.foreground).child(props()?.title ?? "Agents"))
          .child(div().id("agent-list-esc").px(6).py(2).rounded(5).text_size(11).text_color(t.dim).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click(() => this.close()).child("Esc")),
      )
      .child(v_flex().id("al-rows").mb(6).children(rows.length ? rows.map(line) : [div().px(10).py(6).text_color(t.dim).child(empty)]));
  }
}
