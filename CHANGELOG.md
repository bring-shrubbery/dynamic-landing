# Changelog

## 0.2.7

- The expanded island slides into and out of the notch at a constant width. It used to shrink
  in height, and as it got shorter than its flared top corners the shape re-fitted: the body
  widened to the full flare width in the last pixels, which looked like it spreading sideways
  out of the notch before vanishing. It is now drawn at its full height and shifted up behind
  the screen's top edge (`IslandLayout.slide`), so only its lower part shows through a window
  of the current height and nothing re-fits. Its narrow bottom edge is what shows last.

## 0.2.6

- Content is never squeezed or moved while the island changes size. Each piece keeps its
  natural size and its place relative to the island's centre, and only the island's shape
  covers or reveals it. Pieces were also clipped to their own frames, which animate when the
  content changes, so new content was cut to the old one's size mid-animation and slid
  sideways; they are not any more. The compact slots stay where they sit in the compact island
  in every pose, so collapsing into the notch covers them instead of pulling them inward.

## 0.2.5

- On a screen with a notch the notch stays put and the island goes in and out of it. The
  expanded island drops down from the screen's top edge at its own width and retracts straight
  up, changing only its height; compact and expanded pass through the notch on the way to each
  other: the compact island shrinks into the notch, then the expanded one drops down, and the
  reverse. Screens without a notch, and forced notch or pill styles there, morph as before.

## 0.2.4

- Showing again right after a hide no longer opens a narrow, empty island. The hide cleared the
  content and its measured sizes, and content of the same kind set before the cleared island
  was drawn looked unchanged to SwiftUI, so its size was never reported again. Content set
  after a clear now has a new identity and is measured.
- The island's window stays ordered in when the island hides, transparent and click-through,
  instead of being ordered out and in for every show; it keeps its place on every Space,
  full-screen apps included. `prepare()` creates it ahead of the first show (call it at launch).
- The window's moves are logged under the subsystem `com.quassum.dynamic-landing`.

## 0.2.3

- The island no longer slides in from the side after moving to another screen. The screen's
  metrics and the panel's frame changed in the same update as the show, and the layout's
  animation moved the island across from its place on the old screen. A screen change is now
  applied at once, without animation, before the show animates; on the same screen nothing
  changes, so content updates still animate.

## 0.2.2

- The island is above the menu bar, as intended. Making the panel a floating panel reset its
  level to `.floating`, below the menu bar and full-screen apps, and that came after the level
  was set. On a notchless screen the menu bar covered the island's top, so it looked pushed
  down; full-screen Spaces did not show it.
- An island without a fixed screen shows on the screen you are using — the one holding the
  frontmost app's window, else the one under the pointer — and moves there when you switch
  Space or app. It used to stay on `NSScreen.main`, which for an app with no key window is the
  first display.

## 0.2.1

- No wobble when the island changes size. A state change animated toward the previous
  content's size (zero after a hide) and was re-aimed a frame later, when the new content had
  been measured. The panel now lays the island out before every change, so the content is
  measured first and the island moves once, straight to the size it needs.
- On a screen without a notch, the `.automatic` compact island is as tall as the menu bar
  instead of 32 pt, so it sits in the menu bar's line rather than hanging below it as if there
  were a notch. Explicit `.pill` and `.notch` styles keep `compactHeight`.
- A notch is read only on the Mac's built-in display; an external display never gets one.

## 0.2.0

Islands share the notch. Every `DynamicLanding` on the machine, in any app, now takes part in
one agreement: one island per display at a time, the most important first, and an island that
stepped aside shows itself again when the notch is free. Nothing to set up; existing code
behaves the same until a second island appears. [Docs/Coordination.md](Docs/Coordination.md)
has the agreement and the message format.

- `IslandConfiguration.priority` (`IslandPriority`: `.background`, `.normal`, `.high`,
  `.urgent` or any integer) ranks the island. A higher priority wins the notch; between equals
  the island shown last wins.
- `IslandConfiguration.coordination` (`.shared`, the default, or `.none` to opt out).
- `DynamicLanding.isYielded`, `onYield` and `onResume` report losing and regaining the notch.
  A yielded island keeps its content; `show` while yielded updates it; `hide` drops it.
- `IslandMessage` is the public wire format, carried as JSON in a distributed notification
  named `com.quassum.dynamic-landing.island`.
- The demo's "Interrupt with an urgent island" (⌘3) shows the hand-off in one process.

Minor version bump: the API grows (nothing existing changed), and the default behaviour changes
when more than one island exists.

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
