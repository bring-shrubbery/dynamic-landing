// DynamicLanding — FocusedScreenTests.swift
import CoreGraphics
import Foundation
import Testing
@testable import DynamicLanding

struct FocusedScreenTests {
    private func window(pid: Int32, layer: Int, _ rect: CGRect) -> [String: Any] {
        [kCGWindowOwnerPID as String: NSNumber(value: pid),
         kCGWindowLayer as String: NSNumber(value: layer),
         kCGWindowBounds as String: rect.dictionaryRepresentation]
    }

    @Test func theFrontmostOrdinaryWindowOfTheAppCounts() {
        let windows = [
            window(pid: 9, layer: 0, CGRect(x: 0, y: 0, width: 800, height: 600)),      // another app, in front
            window(pid: 7, layer: 25, CGRect(x: 0, y: 0, width: 300, height: 24)),     // the app's menu-bar item
            window(pid: 7, layer: 0, CGRect(x: 2000, y: 100, width: 400, height: 300)),
            window(pid: 7, layer: 0, CGRect(x: 0, y: 0, width: 400, height: 300)),
        ]
        #expect(FocusedScreen.frontWindowCenter(pid: 7, windows: windows) == CGPoint(x: 2200, y: 250))
        #expect(FocusedScreen.frontWindowCenter(pid: 3, windows: windows) == nil)
    }

    @Test func aPointBelongsToTheDisplayThatHoldsIt() {
        let displays: [(id: UInt32, bounds: CGRect)] = [
            (1, CGRect(x: 0, y: 0, width: 1512, height: 982)),
            (2, CGRect(x: 1512, y: -200, width: 2560, height: 1440)),
        ]
        #expect(FocusedScreen.display(containing: CGPoint(x: 2200, y: 250), displays: displays) == 2)
        #expect(FocusedScreen.display(containing: CGPoint(x: 100, y: 100), displays: displays) == 1)
        #expect(FocusedScreen.display(containing: CGPoint(x: -50, y: 100), displays: displays) == nil)
    }
}
