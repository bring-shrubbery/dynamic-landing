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

    /// Hidden, the island's window stays ordered in, transparent and click-through, so it keeps
    /// its place on every Space; ordered out and in again it was not always put on the Space in
    /// front.
    @Test func aHiddenIslandKeepsItsWindowInPlace() {
        guard let screen = NSScreen.screens.first else { return }
        let model = IslandModel(configuration: IslandConfiguration(), metrics: ScreenMetrics(screen: screen))
        let controller = IslandPanelController(model: model)
        controller.prepare(on: screen, metrics: ScreenMetrics(screen: screen))
        #expect(controller.window?.isVisible == true)
        #expect(controller.window?.alphaValue == 0)
        controller.present(on: screen, metrics: ScreenMetrics(screen: screen))
        #expect(controller.window?.alphaValue == 1)
        controller.dismiss()
        #expect(controller.window?.isVisible == true)
        #expect(controller.window?.alphaValue == 0)
        #expect(controller.window?.ignoresMouseEvents == true)
        controller.window?.orderOut(nil)
    }

    /// Above the menu bar, and on every Space including full-screen ones. Making it a floating
    /// panel resets the level to `.floating`, which once undid the level set before it.
    @Test func thePanelSitsAboveTheMenuBarOnEverySpace() {
        let panel = IslandPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
        #expect(panel.level == IslandPanel.islandLevel)
        #expect(panel.level.rawValue > NSWindow.Level.mainMenu.rawValue)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}
