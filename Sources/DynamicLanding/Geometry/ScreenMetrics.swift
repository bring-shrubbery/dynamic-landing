// DynamicLanding — ScreenMetrics.swift
import AppKit

/// What the geometry needs to know about a screen: its frame (AppKit coordinates, origin
/// bottom-left), its notch if any, and the menu bar's height.
public struct ScreenMetrics: Equatable, Sendable {
    public var frame: CGRect
    public var notchSize: CGSize?
    public var menuBarHeight: CGFloat

    public init(frame: CGRect, notchSize: CGSize?, menuBarHeight: CGFloat) {
        self.frame = frame
        self.notchSize = notchSize
        self.menuBarHeight = menuBarHeight
    }

    /// Reads a live screen. The notch is the gap between the two auxiliary top areas.
    @MainActor
    public init(screen: NSScreen) {
        let frame = screen.frame
        var notch: CGSize?
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, screen.safeAreaInsets.top > 0 {
            notch = CGSize(width: frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        }
        self.init(frame: frame, notchSize: notch, menuBarHeight: NSStatusBar.system.thickness)
    }

    public var hasNotch: Bool { notchSize != nil }

    /// The notch, in screen coordinates; nil on a notchless screen.
    public var notchRect: CGRect? {
        guard let notchSize else { return nil }
        return CGRect(x: frame.midX - notchSize.width / 2, y: frame.maxY - notchSize.height,
                      width: notchSize.width, height: notchSize.height)
    }
}
