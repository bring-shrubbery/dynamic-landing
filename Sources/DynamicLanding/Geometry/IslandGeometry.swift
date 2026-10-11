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
        layout(pose: IslandPose(state), metrics: metrics, configuration: configuration,
               compactSlotSizes: compactSlotSizes, expandedContentSize: expandedContentSize)
    }

    static func layout(
        pose: IslandPose, metrics: ScreenMetrics, configuration: IslandConfiguration,
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
        // On a screen without a notch, `.automatic` sits in the menu bar's own line: a fixed
        // height taller than the menu bar hung below it, as if leaving room for a notch.
        let compactHeight: CGFloat = notch?.height
            ?? (configuration.style == .automatic ? metrics.menuBarHeight : configuration.compactHeight)

        // The expanded size does not depend on the state: content that is not showing is still
        // laid out at the place it has when it shows, so the view can fade it there (IslandView).
        let contentTop: CGFloat = if look == .notch, let n = notch {
            n.height + p.top
        } else {
            metrics.notchSize.map { $0.height + p.top } ?? configuration.expandedTopInset
        }
        let expandedWidth: CGFloat = if look == .notch, let n = notch {
            min(max(n.width, expandedContentSize.width + p.leading + p.trailing) + 2 * radii.top, frame.width / 2)
        } else {
            min(max(expandedContentSize.width + p.leading + p.trailing, metrics.notchSize?.width ?? 0), frame.width / 2)
        }
        let expandedHeight = min(contentTop + expandedContentSize.height + p.bottom, frame.height / 2)

        // The compact island's width, whatever the pose: the slots are always laid out for it.
        let compactWidth: CGFloat = if let n = notch {
            min(n.width + 2 * (radii.top + max(slotWidths.leading, slotWidths.trailing) + 2 * padding), frame.width / 2)
        } else {
            min(slotWidths.leading + slotWidths.trailing + 3 * padding, frame.width / 2)
        }

        var width: CGFloat
        var height: CGFloat

        switch pose {
        case .hidden:
            if look == .notch, let n = metrics.notchSize {
                width = n.width; height = n.height
            } else {
                width = 0; height = 0
            }
        case .compact:
            width = compactWidth
            height = compactHeight
        case .expanded:
            width = expandedWidth
            height = expandedHeight
        case .tucked:
            width = expandedWidth
            height = 0
        }

        // The compact slots, beside the notch (or at the pill's ends), where they sit in the
        // compact island, in every pose: the same size and the same place on screen, so a
        // narrower or taller island covers them or reveals them but never moves or squeezes
        // them. As tall as the compact island, so a slot fading out of a tall island stays put.
        var leading: CGRect
        var trailing: CGRect
        if let n = notch {
            let notchMinX = max(0, (compactWidth - n.width) / 2), notchMaxX = min(compactWidth, notchMinX + n.width)
            let lw = max(0, min(slotWidths.leading, notchMinX - 2 * padding - radii.top))
            let trailingX = notchMaxX + padding
            let tw = max(0, min(slotWidths.trailing, compactWidth - radii.top - padding - trailingX))
            leading = CGRect(x: notchMinX - padding - lw, y: 0, width: lw, height: compactHeight)
            trailing = CGRect(x: trailingX, y: 0, width: tw, height: compactHeight)
        } else {
            let room = max(0, compactWidth - 3 * padding)
            let tw = min(slotWidths.trailing, max(room / 2, room - slotWidths.leading))
            let lw = min(slotWidths.leading, room - tw)
            leading = CGRect(x: padding, y: 0, width: lw, height: compactHeight)
            trailing = CGRect(x: compactWidth - padding - tw, y: 0, width: tw, height: compactHeight)
        }
        // From the compact island's coordinates to this one's, which share a centre.
        let shift = (width - compactWidth) / 2
        leading.origin.x += shift
        trailing.origin.x += shift

        // The expanded content, centred in the island's current width at its expanded place.
        let flares = look == .notch ? 2 * radii.top : 0
        let maxWidth = max(0, expandedWidth - flares - p.leading - p.trailing)
        let w = max(0, min(expandedContentSize.width, maxWidth))
        let h = max(0, min(expandedContentSize.height, expandedHeight - contentTop))
        let content = CGRect(x: (width - w) / 2, y: min(contentTop, expandedHeight), width: w, height: h)

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
