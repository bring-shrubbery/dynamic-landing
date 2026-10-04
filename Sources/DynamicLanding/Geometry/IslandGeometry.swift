// DynamicLanding — IslandGeometry.swift
import CoreGraphics

/// Which silhouette the island has.
public enum IslandLook: Equatable, Sendable {
    /// Flush with the notch: flared top corners, the body never narrower than the notch.
    case notch
    /// A rounded pill hanging from the top edge.
    case pill
}

/// Where everything goes for one state. `rect` is in screen coordinates (AppKit, origin
/// bottom-left); the slots and the content rect are island-local with a top-left origin.
public struct IslandLayout: Equatable, Sendable {
    public var rect: CGRect
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat
    public var leadingSlot: CGRect?
    public var trailingSlot: CGRect?
    public var contentRect: CGRect?
    public var look: IslandLook
}

/// The island's layout maths. Pure: the same inputs always give the same layout, so the two
/// invariants that matter — top edge pinned to the screen's top, centred on the screen — are
/// tested rather than hoped for.
public enum IslandGeometry {

    public static func resolvedLook(style: IslandStyle, metrics: ScreenMetrics) -> IslandLook {
        switch style {
        case .automatic: metrics.hasNotch ? .notch : .pill
        case .notch: .notch
        case .pill: .pill
        }
    }

    public static func layout(
        state: IslandState, metrics: ScreenMetrics, configuration: IslandConfiguration,
        compactSlotSizes: (leading: CGSize, trailing: CGSize), expandedContentSize: CGSize
    ) -> IslandLayout {
        let look = resolvedLook(style: configuration.style, metrics: metrics)
        let radii = cornerRadii(for: look, style: configuration.style, configuration: configuration)
        let padding = configuration.slotPadding
        let frame = metrics.frame

        // The notch the island must cover: the real one, or a virtual one for a forced notch look.
        let notch: CGSize? = metrics.notchSize ?? (look == .notch
            ? CGSize(width: configuration.virtualNotchWidth, height: configuration.compactHeight) : nil)

        var width: CGFloat
        var height: CGFloat
        var leading: CGRect?
        var trailing: CGRect?
        var content: CGRect?

        switch (state, look) {
        case (.hidden, .notch):
            // The notch itself (a forced notch look adds the flares so the shape reads as a notch).
            let n = notch!
            width = metrics.hasNotch ? n.width : n.width + 2 * radii.top
            height = n.height
        case (.hidden, .pill):
            width = 0; height = 0
        case (.compact, .notch):
            // Both sides are as wide as the wider slot, so the island stays centred on the notch;
            // each slot hugs its side of the notch.
            let n = notch!
            height = n.height
            let side = max(compactSlotSizes.leading.width, compactSlotSizes.trailing.width) + padding
            width = n.width + 2 * (radii.top + side)
            let notchMinX = (width - n.width) / 2, notchMaxX = notchMinX + n.width
            leading = CGRect(x: notchMinX - padding - compactSlotSizes.leading.width, y: 0,
                             width: compactSlotSizes.leading.width, height: height)
            trailing = CGRect(x: notchMaxX + padding, y: 0, width: compactSlotSizes.trailing.width, height: height)
        case (.compact, .pill):
            height = max(configuration.compactHeight, metrics.notchSize?.height ?? 0)
            width = compactSlotSizes.leading.width + compactSlotSizes.trailing.width + 3 * padding
            width = max(width, metrics.notchSize?.width ?? 0)
            leading = CGRect(x: padding, y: 0, width: compactSlotSizes.leading.width, height: height)
            trailing = CGRect(x: width - padding - compactSlotSizes.trailing.width, y: 0,
                              width: compactSlotSizes.trailing.width, height: height)
        case (.expanded, .notch):
            let n = notch!
            let p = configuration.contentPadding
            let body = max(n.width, expandedContentSize.width + p.leading + p.trailing)
            width = body + 2 * radii.top
            height = n.height + p.top + expandedContentSize.height + p.bottom
            content = CGRect(x: (width - expandedContentSize.width) / 2, y: n.height + p.top,
                             width: expandedContentSize.width, height: expandedContentSize.height)
        case (.expanded, .pill):
            let p = configuration.contentPadding
            width = max(expandedContentSize.width + p.leading + p.trailing, metrics.notchSize?.width ?? 0)
            height = configuration.expandedTopInset + expandedContentSize.height + p.bottom
            if let n = metrics.notchSize { height = max(height, n.height) }
            content = CGRect(x: (width - expandedContentSize.width) / 2, y: configuration.expandedTopInset,
                             width: expandedContentSize.width, height: expandedContentSize.height)
        }

        // Never more than half the screen; the content clips.
        width = min(width, frame.width / 2)
        height = min(height, frame.height / 2)
        if var c = content {
            c.size.width = min(c.size.width, width); c.origin.x = (width - c.size.width) / 2
            c.size.height = max(0, min(c.size.height, height - c.origin.y)); content = c
        }

        let rect = CGRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height)
        return IslandLayout(rect: rect, topCornerRadius: radii.top, bottomCornerRadius: radii.bottom,
                            leadingSlot: leading, trailingSlot: trailing, contentRect: content, look: look)
    }

    private static func cornerRadii(for look: IslandLook, style: IslandStyle, configuration: IslandConfiguration) -> (top: CGFloat, bottom: CGFloat) {
        switch (look, style) {
        case (.notch, .notch(let top, let bottom)): (top, bottom)
        case (.notch, _): configuration.notchCornerRadii
        case (.pill, .pill(let radius)): (0, radius)
        case (.pill, _): (0, configuration.pillCornerRadius)
        }
    }
}
