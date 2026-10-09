// DynamicLanding — IslandPanel.swift
import AppKit

/// A non-activating, borderless panel above the menu bar that joins every Space and never
/// takes keyboard focus.
final class IslandPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // `isFloatingPanel` sets the level to `.floating` (3), below the menu bar and full-screen
        // windows, so it must come first: set after the level, it silently undid it.
        isFloatingPanel = true
        level = Self.islandLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
    }

    /// AppKit keeps ordinary windows below the menu bar by moving them down; the island is
    /// pinned to the screen's top edge on purpose (over the menu bar on a notchless display).
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// Above the menu bar, so the island covers it on a notchless screen and shows over
    /// full-screen apps.
    static let islandLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
