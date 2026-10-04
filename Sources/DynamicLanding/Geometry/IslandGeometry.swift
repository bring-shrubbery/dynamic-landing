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
        let p = configuration.contentPadding
        let slotWidths = (leading: compactSlotSizes.leading.width, trailing: compactSlotSizes.trailing.width)

        // First the island's natural size, then the clamp, then what goes inside it, so that
        // slots and content are always placed in the island that is actually shown.
        var width: CGFloat
        var height: CGFloat
        var contentTop: CGFloat = 0

        switch state {
        case .hidden:
            // The notch itself on a notched screen; nothing at all on a notchless one, whatever
            // the style, so a forced notch never leaves a permanent tab on an external display.
            if look == .notch, let n = metrics.notchSize {
                width = n.width; height = n.height
            } else {
                width = 0; height = 0
            }
        case .compact:
            if let n = notch {
                // Both sides are as wide as the wider slot, so the island stays centred on the
                // notch. A pill around a real notch has the same sides, without the flares.
                let side = max(slotWidths.leading, slotWidths.trailing) + padding
                width = n.width + 2 * (radii.top + side)
                height = n.height
            } else {
                width = slotWidths.leading + slotWidths.trailing + 3 * padding
                height = configuration.compactHeight
            }
        case .expanded:
            if look == .notch, let n = notch {
                width = max(n.width, expandedContentSize.width + p.leading + p.trailing) + 2 * radii.top
                contentTop = n.height + p.top
            } else {
                width = max(expandedContentSize.width + p.leading + p.trailing, metrics.notchSize?.width ?? 0)
                contentTop = metrics.notchSize.map { $0.height + p.top } ?? configuration.expandedTopInset
            }
            height = contentTop + expandedContentSize.height + p.bottom
        }

        // Never more than half the screen.
        width = min(width, frame.width / 2)
        height = min(height, frame.height / 2)

        var leading: CGRect?
        var trailing: CGRect?
        var content: CGRect?

        switch state {
        case .hidden:
            break
        case .compact:
            if let n = notch {
                // Each slot hugs its side of the notch and shrinks to the room left on that side
                // (inside the flares), never into the notch and never past the island's edge.
                let notchMinX = max(0, (width - n.width) / 2), notchMaxX = min(width, notchMinX + n.width)
                let lw = max(0, min(slotWidths.leading, notchMinX - padding - radii.top))
                let trailingX = notchMaxX + padding
                let tw = max(0, min(slotWidths.trailing, width - radii.top - trailingX))
                leading = CGRect(x: notchMinX - padding - lw, y: 0, width: lw, height: height)
                trailing = CGRect(x: trailingX, y: 0, width: tw, height: height)
            } else {
                // A pill: slots at the two ends with a gap between; if they don't fit, the
                // trailing slot keeps up to half the room and the leading slot gets the rest.
                let room = max(0, width - 3 * padding)
                let tw = min(slotWidths.trailing, max(room / 2, room - slotWidths.leading))
                let lw = min(slotWidths.leading, room - tw)
                leading = CGRect(x: padding, y: 0, width: lw, height: height)
                trailing = CGRect(x: width - padding - tw, y: 0, width: tw, height: height)
            }
        case .expanded:
            // The content clips to the visible body: inside the flares and the padding.
            let flares = look == .notch ? 2 * radii.top : 0
            let maxWidth = max(0, width - flares - p.leading - p.trailing)
            let w = max(0, min(expandedContentSize.width, maxWidth))
            let h = max(0, min(expandedContentSize.height, height - contentTop))
            content = CGRect(x: (width - w) / 2, y: min(contentTop, height), width: w, height: h)
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
