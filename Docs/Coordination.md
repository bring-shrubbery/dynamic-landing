# Sharing the notch between apps

Several apps can use DynamicLanding at once. There is one notch, so the islands agree among
themselves on who shows: one island per display at a time, the most important first, and an
island that had to step aside comes back by itself when the notch is free. Nothing is set up
by the app; every `DynamicLanding` instance takes part from the moment it is created.

This document is the agreement in full, with the wire format, so that another implementation
could join it.

## What an app sees

```swift
var config = IslandConfiguration()
config.priority = .urgent          // a permission prompt: holds the notch against a timer
let island = DynamicLanding(configuration: config)

island.onYield = { timer.pause() }      // another app took the notch; the island has hidden
island.onResume = { timer.resume() }    // the notch is free; the island is showing again
```

- `configuration.priority` ranks the island: `.background` (0), `.normal` (50, the default),
  `.high` (75), `.urgent` (100), or any integer. A higher priority wins the notch; between
  equals the island shown last wins. Change it any time; it applies at the next `show`.
- `isYielded` is true while another island has the notch and this one waits. Its content is
  kept, and `show` while yielded only updates that content.
- `onYield` fires once when the island loses the notch, `onResume` once when it shows again.
  A yielded island that the app hides with `hide()` forgets its content and does not come back.
- `configuration.coordination = .none` opts out: the island shows regardless and says
  nothing on the bus.
- Islands on different displays never interact.

## The agreement

Every island has an identity: a random id, its process id and its bundle id. It speaks on a
bus that every process on the machine can reach (below).

1. **Claim.** An island that is asked to show posts a *claim* carrying its identity, display,
   priority and the time of the claim, and shows at once.
2. **Compare.** Every other island on the same display compares the claim with its own
   standing. The one that is *outranked* loses:
   - a lower priority is outranked by a higher one;
   - between equal priorities, the earlier claim is outranked by the later one;
   - between equal priorities and equal times, the smaller island id is outranked.
   The ordering is total, so two islands never both win.
3. **Yield.** A visible island that is outranked hides immediately (no hover wait) and
   *waits*, keeping its content.
4. **Holding.** A visible island that outranks a claim it hears answers with *holding*, so a
   newcomer that did not know about it (its process started later, or the claim raced)
   learns it lost and hides. While it has the notch an island also posts *holding* every
   2 seconds.
5. **Release.** An island that hides on purpose posts *release*.
6. **Resume.** A waiting island that hears a release, or a process ending, or that has not
   heard from a holder for 5 seconds, checks that nothing that outranks it is left on its
   display, waits a short delay, and claims again. The delay is 0 ms for `.urgent` and grows
   to 100 ms for `.background`, plus up to 30 ms of per-island jitter, so the most important
   waiting island claims first and the others yield to it in turn.

A claim is refused locally, without being posted, when the island already knows of a live
holder that outranks it; the island then waits as in step 3 without ever appearing.

## The bus

Messages are macOS distributed notifications (`DistributedNotificationCenter`), named
`com.quassum.dynamic-landing.island`, posted with `deliverImmediately`. Any process can post
and receive them without entitlements, a helper process or an app group. A sandboxed app's
distributed notifications lose their `userInfo`, so the message rides in the notification's
`object` as a JSON string instead.

An island also observes `NSWorkspace.didTerminateApplicationNotification`; a process that
ends counts as having released everything it held.

### Message format

```json
{
  "bundleID": "com.quassum.squish",
  "claimedAt": 1791300000.123,
  "displayID": 1,
  "islandID": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
  "kind": "claim",
  "pid": 4242,
  "priority": 100,
  "version": 1
}
```

| Field | Meaning |
|---|---|
| `version` | Format version; readers ignore messages with a higher version than they know. Currently `1`. |
| `kind` | `claim`, `holding` or `release`. |
| `islandID` | One `DynamicLanding` instance. Two instances in one process are two islands. |
| `pid` | The sender's process id. |
| `bundleID` | The sender's bundle id, or its process name without a bundle. For diagnostics only. |
| `displayID` | The `CGDirectDisplayID` of the island's display. |
| `priority` | The island's priority as an integer. |
| `claimedAt` | Seconds since 1970 of the sender's current claim; the tiebreak between equal priorities. |

Keys are sorted; readers must accept any order. Unknown keys are ignored.

## Limits

- An island that stops responding without its process ending holds the notch for up to
  5 seconds (the heartbeat timeout) before the others move on.
- Two islands of equal priority that claim within the same millisecond on two machines'
  worth of clock skew do not exist: there is one machine and one clock.
- The agreement decides who shows; it does not place two islands side by side or shrink one
  to make room for another. That needs the islands to agree on widths, which is a request
  and a reply rather than a broadcast, and can be added on top of this protocol.
