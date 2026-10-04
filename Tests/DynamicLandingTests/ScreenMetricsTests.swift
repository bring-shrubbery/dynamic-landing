// DynamicLanding — ScreenMetricsTests.swift
import CoreGraphics
import Testing
@testable import DynamicLanding

struct ScreenMetricsTests {
    @Test func aNotchedScreenKnowsItsNotchRect() {
        let m = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)
        #expect(m.hasNotch)
        #expect(m.notchRect == CGRect(x: 656, y: 944, width: 200, height: 38))
    }

    @Test func aNotchlessScreenHasNoNotchRect() {
        let m = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), notchSize: nil, menuBarHeight: 24)
        #expect(!m.hasNotch)
        #expect(m.notchRect == nil)
    }

    @Test func aSecondaryScreenOffsetIsRespected() {
        let m = ScreenMetrics(frame: CGRect(x: -2560, y: 200, width: 2560, height: 1440), notchSize: CGSize(width: 180, height: 32), menuBarHeight: 32)
        #expect(m.notchRect == CGRect(x: -2560 + 1190, y: 200 + 1440 - 32, width: 180, height: 32))
    }

    @Test func configurationDefaultsMatchTheSpec() {
        let c = IslandConfiguration()
        #expect(c.compactHeight == 32 && c.expandedTopInset == 8 && c.pillCornerRadius == 16)
        #expect(c.notchCornerRadii.top == 15 && c.notchCornerRadii.bottom == 20)
        #expect(c.shadow == .none && c.hoverBehavior.isEmpty)
        #expect(c.animationDuration == .milliseconds(350) && c.slotPadding == 8 && c.virtualNotchWidth == 180)
        #expect(c.contentPadding.top == 10 && c.contentPadding.leading == 16 && c.contentPadding.bottom == 12 && c.contentPadding.trailing == 16)
    }
}
