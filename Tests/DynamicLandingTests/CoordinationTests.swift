import SwiftUI
import Testing
@testable import DynamicLanding

/// Two or more islands on one in-memory bus, as two apps would be on the distributed one.
@MainActor
struct CoordinationTests {
    private let metrics = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                        notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)

    private func island(on bus: LocalIslandBus, priority: IslandPriority = .normal, display: UInt32 = 1,
                        coordination: IslandCoordination = .shared, pid: Int32? = nil,
                        staleAfter: TimeInterval = 5, heartbeat: Duration = .seconds(2)) -> DynamicLanding {
        var c = IslandConfiguration()
        c.animation = .linear(duration: 0.01)
        c.animationDuration = .milliseconds(10)
        c.priority = priority
        c.coordination = coordination
        var timing = DynamicLanding.CoordinationTiming()
        timing.staleAfter = staleAfter
        timing.heartbeatInterval = heartbeat
        timing.resumeDelay = { _ in .milliseconds(5) }
        let identity = pid.map {
            IslandCoordinator.Identity(islandID: UUID().uuidString, pid: $0, bundleID: "com.example.other")
        }
        let i = DynamicLanding(configuration: c, metrics: metrics, presentsPanel: false, bus: bus, timing: timing, identity: identity)
        i.displayIDOverride = display
        return i
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(60)) }

    @Test func theIslandShownLastTakesTheNotchAndTheOtherComesBackAfterIt() async {
        let bus = LocalIslandBus()
        let a = island(on: bus), b = island(on: bus)
        var yields = 0, resumes = 0
        a.onYield = { yields += 1 }
        a.onResume = { resumes += 1 }

        await a.show(compactLeading: { Text("L") }, trailing: { Text("T") })
        #expect(a.isVisible && !a.isYielded)

        await b.show(expanded: { Text("B") })
        #expect(b.isVisible && !b.isYielded)
        #expect(!a.isVisible && a.isYielded)       // hid at once, content kept
        #expect(a.model.hasContent)
        #expect(yields == 1 && resumes == 0)

        await b.hide()
        await settle()
        #expect(a.isVisible && a.state == .compact && !a.isYielded)
        #expect(resumes == 1)
        #expect(bus.log.map(\.kind) == [.claim, .claim, .release, .claim])
    }

    @Test func aHigherPriorityHolderKeepsTheNotchAgainstALaterClaim() async {
        let bus = LocalIslandBus()
        let prompt = island(on: bus, priority: .urgent), clock = island(on: bus, priority: .background)
        await prompt.show(expanded: { Text("Allow?") })
        await clock.show(compactLeading: { Text("•") }, trailing: { Text("0:01") })
        #expect(prompt.isVisible && !prompt.isYielded)
        #expect(!clock.isVisible && clock.isYielded)
        #expect(clock.model.hasContent)
        #expect(bus.log.map(\.kind) == [.claim])   // the clock never even claimed

        // Re-showing while waiting updates the kept content and stays hidden.
        await clock.show(compactLeading: { Text("•") }, trailing: { Text("0:02") })
        #expect(!clock.isVisible && clock.isYielded)

        await prompt.hide()
        await settle()
        #expect(clock.isVisible && clock.state == .compact)
    }

    @Test func aHigherPriorityClaimTakesTheNotchFromALowerHolder() async {
        let bus = LocalIslandBus()
        let clock = island(on: bus, priority: .background), prompt = island(on: bus, priority: .urgent)
        await clock.show(compactLeading: { Text("•") }, trailing: { Text("0:01") })
        await prompt.show(expanded: { Text("Allow?") })
        #expect(prompt.isVisible && !clock.isVisible && clock.isYielded)
        await prompt.hide()
        await settle()
        #expect(clock.isVisible)
    }

    @Test func aLateClaimThatLosesHearsHoldingAndHides() async {
        let bus = LocalIslandBus()
        let holder = island(on: bus, priority: .high)
        await holder.show(expanded: { Text("H") })
        // A newcomer that did not hear the holder (it was not on the bus yet) claims anyway.
        let newcomer = island(on: bus, priority: .normal)
        await newcomer.show(expanded: { Text("N") })
        #expect(holder.isVisible && !holder.isYielded)
        #expect(!newcomer.isVisible && newcomer.isYielded)
        #expect(bus.log.map(\.kind) == [.claim, .claim, .holding])
    }

    @Test func theMostImportantWaitingIslandResumesFirstAndTheOthersKeepWaiting() async {
        let bus = LocalIslandBus()
        let low = island(on: bus, priority: .background)
        let high = island(on: bus, priority: .high)
        let top = island(on: bus, priority: .urgent)
        await low.show(expanded: { Text("low") })
        await high.show(expanded: { Text("high") })
        await top.show(expanded: { Text("top") })
        #expect(top.isVisible && high.isYielded && low.isYielded)

        await top.hide()
        await settle()
        #expect(high.isVisible && !high.isYielded)
        #expect(!low.isVisible && low.isYielded)

        await high.hide()
        await settle()
        #expect(low.isVisible && !low.isYielded)
    }

    @Test func islandsOnDifferentDisplaysDoNotInteract() async {
        let bus = LocalIslandBus()
        let a = island(on: bus, display: 1), b = island(on: bus, display: 2)
        await a.show(expanded: { Text("A") })
        await b.show(expanded: { Text("B") })
        #expect(a.isVisible && b.isVisible && !a.isYielded && !b.isYielded)
    }

    @Test func optingOutIgnoresEveryOtherIsland() async {
        let bus = LocalIslandBus()
        let loner = island(on: bus, coordination: .none), other = island(on: bus)
        await loner.show(expanded: { Text("A") })
        await other.show(expanded: { Text("B") })
        #expect(loner.isVisible && other.isVisible)
        #expect(bus.log.count == 1)   // the loner never spoke
    }

    @Test func hidingAYieldedIslandDropsItsContentAndItDoesNotComeBack() async {
        let bus = LocalIslandBus()
        let a = island(on: bus), b = island(on: bus)
        await a.show(expanded: { Text("A") })
        await b.show(expanded: { Text("B") })
        #expect(a.isYielded)
        await a.hide()
        #expect(!a.isYielded && !a.model.hasContent)
        await b.hide()
        await settle()
        #expect(!a.isVisible && !a.model.hasContent)
    }

    @Test func aHolderWhoseProcessEndedCountsAsReleased() async {
        let bus = LocalIslandBus()
        let a = island(on: bus), b = island(on: bus, pid: 4242)
        await a.show(expanded: { Text("A") })
        await b.show(expanded: { Text("B") })
        #expect(a.isYielded)
        bus.endProcess(pid: 4242)
        await settle()
        #expect(a.isVisible && !a.isYielded)
    }

    @Test func aHolderThatStopsTalkingIsForgotten() async {
        let bus = LocalIslandBus()
        // `b` heartbeats every 20 ms; `a` forgets a holder silent for 50 ms.
        let a = island(on: bus, staleAfter: 0.05, heartbeat: .milliseconds(20))
        let b = island(on: bus, staleAfter: 0.05, heartbeat: .milliseconds(20))
        await a.show(expanded: { Text("A") })
        await b.show(expanded: { Text("B") })
        #expect(a.isYielded)
        try? await Task.sleep(for: .milliseconds(120))
        #expect(a.isYielded)                       // heartbeats keep `b` alive
        bus.drop(from: b.coordinatorIdentity.islandID)   // `b` froze: no more heartbeats, no release
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!a.isYielded && a.isVisible)
    }

    @Test func messagesRoundTripAndRankingIsTotal() {
        let m = IslandMessage(kind: .claim, islandID: "x", pid: 7, bundleID: "com.example.a", displayID: 3,
                              priority: 50, claimedAt: 1_000)
        #expect(IslandMessage.decode(m.encoded()) == m)
        #expect(IslandMessage.decode("{\"version\":99}") == nil)
        #expect(IslandMessage.decode("nope") == nil)

        var higher = m; higher.islandID = "y"; higher.priority = 60
        var later = m; later.islandID = "y"; later.claimedAt = 1_001
        var twin = m; twin.islandID = "y"
        #expect(m.isOutranked(by: higher) && !higher.isOutranked(by: m))
        #expect(m.isOutranked(by: later) && !later.isOutranked(by: m))
        #expect(m.isOutranked(by: twin) && !twin.isOutranked(by: m))   // id breaks the tie

        #expect(IslandPriority.background < .normal && .normal < .high && .high < .urgent)
        let custom: IslandPriority = 60
        #expect(.normal < custom && custom < .high)
    }
}
