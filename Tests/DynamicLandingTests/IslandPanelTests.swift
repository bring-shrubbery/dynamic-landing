// DynamicLanding — IslandPanelTests.swift
import AppKit
import Testing
@testable import DynamicLanding

@MainActor
struct IslandPanelTests {
    /// AppKit pushes ordinary windows below the menu bar; the island must stay pinned to the
    /// screen's top edge, or on a notchless display it floats a menu bar's height down.
    @Test func thePanelIsNotPushedBelowTheMenuBar() throws {
        guard let screen = NSScreen.screens.first else { return }   // headless runner without a display
        let frame = screen.frame
        let pinned = NSRect(x: frame.midX - 200, y: frame.maxY - 300, width: 400, height: 300)
        let panel = IslandPanel(contentRect: pinned)
        #expect(panel.constrainFrameRect(pinned, to: screen) == pinned)
    }
}
