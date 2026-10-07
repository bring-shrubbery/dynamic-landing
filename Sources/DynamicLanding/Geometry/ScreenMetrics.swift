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

    /// Reads a live screen. The notch is the gap between the two auxiliary top areas, on the
    /// Mac's own display only; the menu bar height is this screen's own.
    ///
    /// The notch is read from the screen, never from the Mac's model: the 14- and 16-inch
    /// MacBook Pro (2021 on) and the 13- and 15-inch MacBook Air (M2, 2022 on) have one; the
    /// M1 MacBook Air, the 13-inch MacBook Pro (M1 and M2), every Intel MacBook, and every
    /// external display do not. macOS reports a top safe-area inset and the two auxiliary areas
    /// only where there is a notch, and it reports them in points at the resolution in use.
    @MainActor
    public init(screen: NSScreen) {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        let notch = Self.notchSize(frameWidth: frame.width,
                                   leftAuxiliaryWidth: screen.auxiliaryTopLeftArea?.width,
                                   rightAuxiliaryWidth: screen.auxiliaryTopRightArea?.width,
                                   topInset: topInset,
                                   isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false)
        let menuBar = Self.menuBarHeight(topInset: topInset, frameMaxY: frame.maxY,
                                         visibleFrameMaxY: screen.visibleFrame.maxY,
                                         fallback: NSStatusBar.system.thickness)
        self.init(frame: frame, notchSize: notch, menuBarHeight: menuBar)
    }

    /// The notch between the two auxiliary top areas, or nil when there is none: the screen must
    /// be the Mac's own display, both areas must exist, the top inset must be positive and the
    /// gap between the areas must be wider than zero.
    static func notchSize(frameWidth: CGFloat, leftAuxiliaryWidth: CGFloat?, rightAuxiliaryWidth: CGFloat?,
                          topInset: CGFloat, isBuiltIn: Bool = true) -> CGSize? {
        guard isBuiltIn, let left = leftAuxiliaryWidth, let right = rightAuxiliaryWidth, topInset > 0 else { return nil }
        let width = frameWidth - left - right
        guard width > 0 else { return nil }
        return CGSize(width: width, height: topInset)
    }

    /// A screen's own menu bar height: the safe-area top inset on a notched screen, else the strip
    /// above the visible frame, else the system status bar's thickness.
    static func menuBarHeight(topInset: CGFloat, frameMaxY: CGFloat, visibleFrameMaxY: CGFloat,
                              fallback: CGFloat) -> CGFloat {
        if topInset > 0 { return topInset }
        let strip = frameMaxY - visibleFrameMaxY
        if strip > 0 { return strip }
        return fallback
    }

    public var hasNotch: Bool { notchSize != nil }

    /// The notch, in screen coordinates; nil on a notchless screen.
    public var notchRect: CGRect? {
        guard let notchSize else { return nil }
        return CGRect(x: frame.midX - notchSize.width / 2, y: frame.maxY - notchSize.height,
                      width: notchSize.width, height: notchSize.height)
    }
}
