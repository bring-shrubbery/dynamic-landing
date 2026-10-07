# Changelog

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
