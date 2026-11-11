// The theme pair the window should show for the focused space: the work pair on a work space (one with a
// machine), the personal pair on a personal space. Imports nothing and keeps no state, so node can test it.

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
