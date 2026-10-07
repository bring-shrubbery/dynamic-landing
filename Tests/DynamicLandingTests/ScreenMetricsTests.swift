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

    @Test func configurationTakesAStyle() {
        #expect(IslandConfiguration(style: .pill(cornerRadius: 9)).style == .pill(cornerRadius: 9))
        #expect(IslandConfiguration().style == .automatic)
    }

    @Test func notchSizeIsTheGapBetweenTheAuxiliaryAreas() {
        #expect(ScreenMetrics.notchSize(frameWidth: 1512, leftAuxiliaryWidth: 656, rightAuxiliaryWidth: 656, topInset: 38) == CGSize(width: 200, height: 38))
    }

    @Test func notchSizeNeedsBothAuxiliaryAreas() {
        #expect(ScreenMetrics.notchSize(frameWidth: 1512, leftAuxiliaryWidth: nil, rightAuxiliaryWidth: nil, topInset: 38) == nil)
        #expect(ScreenMetrics.notchSize(frameWidth: 1512, leftAuxiliaryWidth: 656, rightAuxiliaryWidth: nil, topInset: 38) == nil)
    }

    @Test func onlyTheMacsOwnDisplayHasANotch() {
        #expect(ScreenMetrics.notchSize(frameWidth: 1512, leftAuxiliaryWidth: 656, rightAuxiliaryWidth: 656, topInset: 38, isBuiltIn: false) == nil)
    }

    @Test func notchSizeNeedsATopInset() {
        #expect(ScreenMetrics.notchSize(frameWidth: 1512, leftAuxiliaryWidth: 656, rightAuxiliaryWidth: 656, topInset: 0) == nil)
    }

    @Test func notchSizeNeedsAPositiveGap() {
        #expect(ScreenMetrics.notchSize(frameWidth: 1512, leftAuxiliaryWidth: 756, rightAuxiliaryWidth: 756, topInset: 38) == nil)
    }

    @Test func menuBarHeightIsTheScreensOwn() {
        #expect(ScreenMetrics.menuBarHeight(topInset: 38, frameMaxY: 982, visibleFrameMaxY: 944, fallback: 24) == 38)
        #expect(ScreenMetrics.menuBarHeight(topInset: 0, frameMaxY: 1640, visibleFrameMaxY: 1615, fallback: 24) == 25)
        #expect(ScreenMetrics.menuBarHeight(topInset: 0, frameMaxY: 1440, visibleFrameMaxY: 1440, fallback: 24) == 24)
    }
}
