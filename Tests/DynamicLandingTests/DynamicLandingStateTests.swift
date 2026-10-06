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
