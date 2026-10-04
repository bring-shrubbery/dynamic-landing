# Changelog

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
