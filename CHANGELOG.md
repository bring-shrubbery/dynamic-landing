# Changelog

## 0.1.4

- No content shows outside a closing island. On a state change the old content was removed
  with a fade, and SwiftUI draws a view on its way out outside its parent's clip for a frame.
  Every piece now stays in the tree in every state and fades in place; the layout gives the
  compact slots and the expanded content a place in every state, so the island's growth
  reveals the card where it ends up.

## 0.1.3

- Content is clipped to the island's shape, not its bounding rectangle. While the island grew,
  content in the notch flares or the pill's rounded corners showed outside the black.

## 0.1.2

- On a display without a notch the island hangs from the very top of the screen. macOS was
  pushing it a menu bar's height down.

## 0.1.1

- Compact views on the notch look get padding at the outer edge, so the bottom corner never clips
  them.
- The island's very first appearance animates.
- `hide()` keeps working after the island's state was changed in the middle of a hide.

## 0.1.0

- First release: hidden, compact and expanded states; notch and pill looks; top-anchored, centred
  geometry with tests; click pass-through around the island; the call made last wins; a menu-bar
  demo.
