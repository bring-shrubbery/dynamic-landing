// DynamicLanding — FocusedScreen.swift
import AppKit

/// The screen the user is working on: the one holding the frontmost app's frontmost window,
/// else the one under the pointer, else `NSScreen.main`. `NSScreen.main` alone is the screen of
/// this app's key window, and an app showing an island usually has none, so it stayed on the
/// first display whatever the user had in front.
enum FocusedScreen {
    @MainActor
    static func current() -> NSScreen? {
        let screens = NSScreen.screens
        let displays: [(id: UInt32, bounds: CGRect)] = screens.compactMap { screen in
            guard let id = displayID(of: screen) else { return nil }
            return (id, CGDisplayBounds(id))
        }
        if let app = NSWorkspace.shared.frontmostApplication,
           let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
           let center = frontWindowCenter(pid: app.processIdentifier, windows: list),
           let id = display(containing: center, displays: displays),
           let screen = screens.first(where: { displayID(of: $0) == id }) {
            return screen
        }
        let mouse = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    static func displayID(of screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// The centre of `pid`'s frontmost ordinary window (layer 0) in a window list ordered front
    /// to back, in global display coordinates (top-left origin); nil when it has none on screen.
    static func frontWindowCenter(pid: pid_t, windows: [[String: Any]]) -> CGPoint? {
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                  bounds.width > 1, bounds.height > 1 else { continue }
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }
        return nil
    }

    /// The display whose bounds hold `point` (global display coordinates).
    static func display(containing point: CGPoint, displays: [(id: UInt32, bounds: CGRect)]) -> UInt32? {
        displays.first { $0.bounds.contains(point) }?.id
    }
}
