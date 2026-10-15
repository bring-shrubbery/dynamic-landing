// DynamicLanding — IslandConfiguration.swift
import SwiftUI

/// How the island looks and moves. Defaults are the plain Dynamic Island: black, no shadow,
/// no bounce.
public struct IslandConfiguration: Sendable {
    public var style: IslandStyle = .automatic
    public var animation: Animation = .smooth(duration: 0.35)
    public var shadow: IslandShadow = .none
    public var background: IslandBackground = .black
    public var foreground: Color = .white
    public var contentPadding: EdgeInsets = EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 16)
    /// The compact island's height on a notchless screen with an explicit `.pill` or `.notch`
    /// style. A notched screen uses the notch's height, and `.automatic` on a notchless screen
    /// the menu bar's, so it sits in the menu bar's line.
    public var compactHeight: CGFloat = 32
    /// Space above expanded content on a notchless screen (a notched screen uses the notch's height).
    public var expandedTopInset: CGFloat = 8
    public var notchCornerRadii: (top: CGFloat, bottom: CGFloat) = (top: 15, bottom: 20)
    /// The corner radii of the Mac's own notch, which the hidden island takes on a screen that
    /// has one: the island's corners morph into them as it narrows into the notch and out of
    /// them as it comes out, so the moment it vanishes there is no step between its shape and
    /// the housing. The housing's corners are much tighter than an island's, roughly 4 pt at
    /// the top and 8 pt at the bottom.
    public var physicalNotchCornerRadii: (top: CGFloat, bottom: CGFloat) = (top: 4, bottom: 8)
    public var pillCornerRadius: CGFloat = 16
    /// The small fillets where a pill meets the screen's top edge: the pill's top corners
    /// flare outward by this much, so the join between the edge and the pill's sides is a
    /// curve rather than a right angle. They grow in as the pill appears and shrink away as
    /// it goes (the hidden pose has none). Zero draws the plain flat-topped pill.
    public var pillTopCornerRadius: CGFloat = 6
    public var hoverBehavior: IslandHoverBehavior = []
    /// Padding inside a compact slot, and the gap between the two slots on a pill.
    public var slotPadding: CGFloat = 8
    /// The notch a forced `.notch` style pretends to have on a notchless screen.
    public var virtualNotchWidth: CGFloat = 180
    /// How long `show`/`hide` wait for `animation` to finish (SwiftUI exposes no duration).
    public var animationDuration: Duration = .milliseconds(350)
    /// Whether this island shares the notch with islands in other apps (and other islands in
    /// this app), hiding for one that outranks it and coming back when it is done.
    public var coordination: IslandCoordination = .shared
    /// How this island ranks against others wanting the same notch; see `IslandPriority`.
    public var priority: IslandPriority = .normal

    public init(style: IslandStyle = .automatic) {
        self.style = style
    }
}

/// Whether an island takes part in the agreement between islands; see `Docs/Coordination.md`.
public enum IslandCoordination: Equatable, Sendable {
    /// Take part: one island at a time per display, the most important first.
    case shared
    /// Ignore every other island and show regardless.
    case none
}

public enum IslandStyle: Equatable, Sendable {
    /// Notch look on a notched screen, pill on a notchless one.
    case automatic
    case notch(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat)
    case pill(cornerRadius: CGFloat)
}

public enum IslandShadow: Equatable, Sendable {
    case none
    case soft(radius: CGFloat, opacity: CGFloat)
}

public enum IslandBackground: Sendable {
    case black
    case color(Color)
    case material(NSVisualEffectView.Material)
}

public struct IslandHoverBehavior: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// A pending `hide()` waits while the pointer is over the island.
    public static let keepVisible = IslandHoverBehavior(rawValue: 1 << 0)
    /// The island brightens slightly under the pointer.
    public static let highlight = IslandHoverBehavior(rawValue: 1 << 1)
}
