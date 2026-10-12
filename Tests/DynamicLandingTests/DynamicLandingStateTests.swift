import SwiftUI
import Testing
@testable import DynamicLanding

@MainActor
struct DynamicLandingStateTests {
    private func island() -> DynamicLanding {
        let metrics = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)
        var c = IslandConfiguration(); c.animation = .linear(duration: 0.01); c.animationDuration = .milliseconds(10)
        return DynamicLanding(configuration: c, metrics: metrics, presentsPanel: false, bus: LocalIslandBus())
    }

    @Test func showingCompactThenExpandedMorphsInPlace() async {
        let i = island()
        #expect(i.state == .hidden && !i.isVisible)
        await i.show(compactLeading: { Text("L") }, trailing: { Text("T") })
        #expect(i.state == .compact && i.isVisible)
        await i.show(expanded: { Text("Big") })
        #expect(i.state == .expanded)
        await i.hide()
        #expect(i.state == .hidden && !i.isVisible)
    }

    @Test func aShowDuringAHideCancelsTheHide() async {
        let i = island()
        await i.show(expanded: { Text("A") })
        i.configuration.animationDuration = .seconds(1)
        let hiding = Task { await i.hide() }
        while i.isVisible { await Task.yield() }      // the hide is genuinely in flight
        i.configuration.animationDuration = .milliseconds(10)
        let start = ContinuousClock.now
        await i.show(expanded: { Text("B") })
        await hiding.value
        #expect(i.state == .expanded)
        #expect(ContinuousClock.now - start < .milliseconds(500))   // the show ended the hide's wait
    }

    @Test func aHideCalledAfterAShowWinsFromShown() async {
        let i = island()
        await i.show(expanded: { Text("A") })
        let a = Task { await i.show(expanded: { Text("B") }) }
        let b = Task { await i.hide() }
        await a.value
        await b.value
        #expect(i.state == .hidden)
    }

    @Test func aHideCalledAfterAShowWinsFromHidden() async {
        let i = island()
        let a = Task { await i.show(expanded: { Text("B") }) }
        let b = Task { await i.hide() }
        await a.value
        await b.value
        #expect(i.state == .hidden)
    }

    @Test func hidingWhenHiddenIsANoOp() async {
        let i = island()
        await i.hide()
        #expect(i.state == .hidden)
    }

    @Test func replacingContentInTheSameStateKeepsTheGeneration() async {
        let i = island()
        await i.show(expanded: { Text("A") })
        let g = i.model.contentGeneration
        await i.show(expanded: { Text("B") })
        #expect(i.model.contentGeneration == g && i.state == .expanded)
    }

    @Test func aFinishedHideDropsTheContent() async {
        let i = island()
        await i.show(expanded: { Text("A") })
        #expect(i.model.hasContent)
        await i.hide()
        #expect(!i.model.hasContent)
    }

    @Test func aShowDuringAHideKeepsItsContent() async {
        let i = island()
        await i.show(expanded: { Text("A") })
        let hiding = Task { await i.hide() }
        while i.isVisible { await Task.yield() }
        await i.show(expanded: { Text("B") })
        await hiding.value
        #expect(i.model.hasContent && i.state == .expanded)
    }

    @Test func keepVisibleDelaysTheHideWhileHovering() async {
        let i = island()
        i.configuration.hoverBehavior = [.keepVisible]
        await i.show(expanded: { Text("A") })
        i.model.isHovering = true
        let hiding = Task { await i.hide() }
        try? await Task.sleep(for: .milliseconds(150))
        #expect(i.state == .expanded)       // still up while hovered
        i.model.isHovering = false
        await hiding.value
        #expect(i.state == .hidden)
    }

    @Test func aHideUsesTheAnimationDurationFromWhenItWasCalled() async {
        let i = island()
        i.configuration.hoverBehavior = [.keepVisible]
        await i.show(expanded: { Text("A") })
        i.model.isHovering = true
        let hiding = Task { await i.hide() }
        try? await Task.sleep(for: .milliseconds(50))   // the hide is waiting on the hover
        i.configuration.animationDuration = .seconds(2)
        let start = ContinuousClock.now
        i.model.isHovering = false
        await hiding.value
        #expect(i.state == .hidden)
        #expect(ContinuousClock.now - start < .milliseconds(1000))   // slept 10 ms, not 2 s
    }

    @Test func aSecondHideWaitsForTheHideInFlight() async {
        let i = island()
        i.configuration.animationDuration = .milliseconds(200)
        await i.show(expanded: { Text("A") })
        let a = Task { await i.hide() }
        let b = Task { await i.hide() }
        await b.value
        #expect(i.state == .hidden && !i.model.hasContent)   // the hide had finished
        await a.value
        #expect(i.state == .hidden && !i.model.hasContent)
    }

    @Test func twoHidesHeldByTheHoverBothReturnHidden() async {
        let i = island()
        i.configuration.hoverBehavior = [.keepVisible]
        await i.show(expanded: { Text("A") })
        i.model.isHovering = true
        let a = Task { await i.hide() }
        let b = Task { await i.hide() }
        Task { try? await Task.sleep(for: .milliseconds(150)); i.model.isHovering = false }
        await a.value
        #expect(i.state == .hidden && !i.model.hasContent)
        await b.value
        #expect(i.state == .hidden && !i.model.hasContent)
    }

    @Test func aShowStillCancelsAHideThatASecondHideIsWaitingOn() async {
        let i = island()
        i.configuration.animationDuration = .seconds(1)
        await i.show(expanded: { Text("A") })
        let a = Task { await i.hide() }
        let b = Task { await i.hide() }
        while i.isVisible { await Task.yield() }
        await Task.yield()
        i.configuration.animationDuration = .milliseconds(10)
        let start = ContinuousClock.now
        await i.show(expanded: { Text("B") })
        await a.value
        await b.value
        #expect(i.state == .expanded && i.model.hasContent)
        #expect(ContinuousClock.now - start < .milliseconds(500))
    }

    @Test func aHideOverriddenBySetStateDoesNotBlockTheNextHide() async {
        let i = island()
        i.configuration.animationDuration = .milliseconds(200)
        await i.show(expanded: { Text("A") })
        let hiding = Task { await i.hide() }
        while i.isVisible { await Task.yield() }
        i.model.setState(.compact)          // a consumer takes over during the hide's sleep
        await hiding.value
        #expect(i.state == .compact)
        i.configuration.animationDuration = .milliseconds(10)
        await i.hide()
        #expect(i.state == .hidden)
    }

    @Test func mousePassThroughFollowsThePointer() {
        let rect = CGRect(x: 600, y: 900, width: 300, height: 80)
        #expect(MousePassThrough.shouldIgnoreMouse(pointer: CGPoint(x: 100, y: 100), islandRect: rect))
        #expect(!MousePassThrough.shouldIgnoreMouse(pointer: CGPoint(x: 700, y: 950), islandRect: rect))
        #expect(MousePassThrough.shouldIgnoreMouse(pointer: CGPoint(x: 700, y: 950), islandRect: .zero))
    }
}

/// On a notched screen the notch stays put and the island goes in and out of it.
@MainActor
struct NotchStagingTests {
    private let notched = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)
    private let notchless = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), notchSize: nil, menuBarHeight: 24)

    private func island(_ metrics: ScreenMetrics) -> DynamicLanding {
        var c = IslandConfiguration(); c.animation = .linear(duration: 0.01); c.animationDuration = .milliseconds(20)
        return DynamicLanding(configuration: c, metrics: metrics, presentsPanel: false, bus: LocalIslandBus())
    }

    /// Records every pose the island is drawn in from now on.
    private final class Poses { var seen: [IslandPose] = [] }
    private func poses(of island: DynamicLanding) -> () -> [IslandPose] {
        let poses = Poses()
        island.model.onPoseChange = { poses.seen.append($0) }
        return { poses.seen }
    }

    @Test func theExpandedIslandOnlyChangesHeight() {
        let config = IslandConfiguration()
        let size = (leading: CGSize(width: 30, height: 14), trailing: CGSize(width: 40, height: 14))
        let content = CGSize(width: 260, height: 64)
        let expanded = IslandGeometry.layout(pose: .expanded, metrics: notched, configuration: config, compactSlotSizes: size, expandedContentSize: content)
        let tucked = IslandGeometry.layout(pose: .tucked, metrics: notched, configuration: config, compactSlotSizes: size, expandedContentSize: content)
        #expect(tucked.rect.width == expanded.rect.width)
        #expect(tucked.rect.midX == expanded.rect.midX)
        #expect(tucked.rect.height == 0 && tucked.rect.maxY == expanded.rect.maxY)
        #expect(tucked.contentRect == expanded.contentRect)
        // Tucked, the island is drawn at its expanded height and shifted up out of view, so
        // between the two poses it slides at a constant drawn height, never re-fitting its shape.
        #expect(tucked.slide == expanded.rect.height && expanded.slide == 0)
        for pose in [IslandPose.hidden, .compact] {
            let other = IslandGeometry.layout(pose: pose, metrics: notched, configuration: config, compactSlotSizes: size, expandedContentSize: content)
            #expect(other.slide == 0)
        }
    }

    @Test func showingAndHidingTheExpandedIslandGoesThroughTheTuckedPose() async {
        let i = island(notched)
        await i.show(expanded: { Text("A") })
        #expect(i.state == .expanded && i.model.pose == .expanded)
        await i.hide()
        #expect(i.state == .hidden && i.model.pose == .tucked)
        // Shown again from there, it starts tucked and grows down.
        await i.show(expanded: { Text("B") })
        #expect(i.model.pose == .expanded)
    }

    @Test func compactAndExpandedPassThroughTheNotch() async {
        let i = island(notched)
        await i.show(compactLeading: { Text("L") }, trailing: { Text("T") })
        let seen = poses(of: i)
        await i.show(expanded: { Text("Big") })
        await Task.yield()
        #expect(i.state == .expanded && i.model.pose == .expanded)
        #expect(seen() == [.hidden, .tucked, .expanded])

        let back = poses(of: i)
        await i.show(compactLeading: { Text("L") }, trailing: { Text("T") })
        await Task.yield()
        #expect(i.model.pose == .compact)
        #expect(back() == [.tucked, .hidden, .compact])
    }

    @Test func theStateChangesTheMomentAShowIsCalled() async {
        let i = island(notched)
        await i.show(compactLeading: { Text("L") }, trailing: { Text("T") })
        let showing = Task { await i.show(expanded: { Text("Big") }) }
        await Task.yield()
        #expect(i.state == .expanded)
        await showing.value
    }

    @Test func withoutANotchEveryChangeIsOneMorph() async {
        let i = island(notchless)
        await i.show(compactLeading: { Text("L") }, trailing: { Text("T") })
        let seen = poses(of: i)
        await i.show(expanded: { Text("Big") })
        await Task.yield()
        #expect(seen() == [.expanded])
        await i.hide()
        #expect(i.model.pose == .hidden)
    }
}
