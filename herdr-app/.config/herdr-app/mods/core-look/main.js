// Makes the window show the focused space's core: the work pair (orange accent) on a work space, the
// personal pair (blue accent) on a personal space. It draws nothing and leaves a hand-picked theme alone.
// app.theme writes the untracked layouts/.state, never the layout file itself.

import { View, div } from "gpui-kit";
import { spaces, focused, layout, props, run } from "herdr";
import { themePick } from "./pick.js";

// The focused space, else the active one while nothing has focus yet.
//: () -> SpaceInfo?
function focusedSpace() {
  const list = spaces();
  const id = focused()?.space;
  return list.find((space) => space.id === id) ?? list.find((space) => space.active) ?? null;
}

// Sets each half of the wanted pair that the window does not show yet.
//: (Pair, Pair) -> void
function apply(wanted, shown) {
  for (const half of ["light", "dark"]) {
    if (shown[half] !== wanted[half]) run("app.theme", { name: wanted[half] });
  }
}

// Asks for the wanted pair and sets it. Does nothing outside a layout that names both pairs and a theme.
//: ({ personal: Pair?, work: Pair? }, Pair?) -> void
function fit({ personal, work }, shown) {
  if (!personal || !work || !shown) return;
  const wanted = themePick({ space: focusedSpace(), shown, pairs: { personal, work } });
  if (wanted) apply(wanted, shown);
}

export default class CoreLook extends View {
  //: () -> Element
  render() {
    fit(props() ?? {}, layout()?.theme);
    return div();
  }
}
