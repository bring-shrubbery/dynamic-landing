// DynamicLanding — IslandModel.swift
import SwiftUI

/// The island's state and measured content sizes; the layout is derived from them. The view
/// observes it, the controller drives it. No window here, so tests can use it directly.
@MainActor @Observable
public final class IslandModel {
    public private(set) var state: IslandState = .hidden
    /// The shape drawn now; the state's own, except during a staged change on a notched screen.
    private(set) var pose: IslandPose = .hidden {
        didSet {
            guard pose != oldValue else { return }
            islandLog.info("pose \(String(describing: self.pose), privacy: .public) for state \(String(describing: self.state), privacy: .public)")
            onPoseChange?(pose)
        }
    }
    /// Every pose as it is set, for tests.
    @ObservationIgnored var onPoseChange: ((IslandPose) -> Void)?
    public var metrics: ScreenMetrics
    public var configuration: IslandConfiguration
    var compactLeading: AnyView = AnyView(EmptyView())
    var compactTrailing: AnyView = AnyView(EmptyView())
    var expandedContent: AnyView = AnyView(EmptyView())
    var leadingSize: CGSize = .zero
    var trailingSize: CGSize = .zero
    var contentSize: CGSize = .zero
    var isHovering = false
    /// Whether any content has been set since the last `clearContent()`.
    private(set) var hasContent = false
    /// The content's identity. Bumped only when the state changes, so the change fades
    /// (with the state's own animation); content replaced within the same state is an
    /// in-place update that keeps its identity and `@State`, so live content (a ticking
    /// timer re-shown every second) never crossfades.
    var contentGeneration = 0
    /// Bumped by `clearContent()`. The view gives content this identity, so content set after a
    /// clear is new to SwiftUI and measured again. Without it, a show right after a hide (the
    /// same kind of content, set before the cleared island was ever drawn) looked unchanged to
    /// SwiftUI, its size was never reported again, and the island opened as a narrow empty bar.
    private(set) var contentEpoch = 0
    public var onTap: (() -> Void)?

    public init(configuration: IslandConfiguration, metrics: ScreenMetrics) {
        self.configuration = configuration
        self.metrics = metrics
    }

    public var layout: IslandLayout {
        IslandGeometry.layout(pose: pose, metrics: metrics, configuration: configuration,
                              compactSlotSizes: (leadingSize, trailingSize), expandedContentSize: contentSize)
    }

    public func setState(_ new: IslandState) {
        setState(new, pose: IslandPose(new))
    }

    /// Changes the state and draws it in `pose` (a step of a staged change, or its own shape).
    func setState(_ new: IslandState, pose newPose: IslandPose) {
        pose = newPose
        guard new != state else { return }
        state = new
        contentGeneration += 1
    }

    /// Draws the island in `pose` without changing its state (a step of a staged change).
    func setPose(_ new: IslandPose) {
        pose = new
    }

    /// Whether changes go by way of the notch: the island has the notch look on a screen with
    /// a real notch. Elsewhere every change is one direct morph.
    var stagesThroughNotch: Bool {
        metrics.hasNotch && IslandGeometry.resolvedLook(style: configuration.style, metrics: metrics) == .notch
    }

    func setCompact(leading: AnyView, trailing: AnyView) {
        compactLeading = leading; compactTrailing = trailing; hasContent = true
    }

    func setExpanded(_ content: AnyView) {
        expandedContent = content; hasContent = true
    }

    /// Drops the content and its measured sizes. The controller calls this once a hide has
    /// finished animating (the model cannot wait for the animation itself), so the content
    /// stays on screen while the island shrinks away.
    func clearContent() {
        compactLeading = AnyView(EmptyView())
        compactTrailing = AnyView(EmptyView())
        expandedContent = AnyView(EmptyView())
        leadingSize = .zero; trailingSize = .zero; contentSize = .zero
        hasContent = false
        contentEpoch += 1
    }
}
