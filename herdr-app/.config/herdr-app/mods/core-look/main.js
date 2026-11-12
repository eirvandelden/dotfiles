// Makes the window show the focused space's core: the work pair (orange accent) on a work space, the
// personal pair (blue accent) on a personal space. It draws nothing and leaves a hand-picked theme alone.
// app.theme writes the untracked layouts/.state, never the layout file itself.
// The decision is `themePick`, exported for the node tests, which run it through a mod copy.

import { View, div } from "gpui-kit";
import { spaces, focused, layout, props, run } from "herdr";

// Pair = { light: String, dark: String }

//: (Pair, { personal: Pair, work: Pair }) -> bool
const owned = (shown, pairs) => {
  const names = [pairs.personal, pairs.work].flatMap((pair) => [pair.light, pair.dark]);
  return names.includes(shown.light) && names.includes(shown.dark);
};

//: (Pair, Pair) -> bool
const same = (first, second) => first.light === second.light && first.dark === second.dark;

// Null when no space has focus, when either shown half is a hand pick, or when the shown halves fit already.
//: ({ space: { machine: String? }?, shown: Pair, pairs: { personal: Pair, work: Pair } }) -> Pair?
export function themePick({ space, shown, pairs }) {
  if (!space || !owned(shown, pairs)) return null;
  const wanted = space.machine ? pairs.work : pairs.personal;
  return same(shown, wanted) ? null : wanted;
}

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
