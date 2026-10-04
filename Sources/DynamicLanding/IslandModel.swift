// DynamicLanding — IslandModel.swift
import SwiftUI

/// The island's state and measured content sizes; the layout is derived from them. The view
/// observes it, the controller drives it. No window here, so tests can use it directly.
@MainActor @Observable
public final class IslandModel {
    public private(set) var state: IslandState = .hidden
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
    public var onTap: (() -> Void)?

    public init(configuration: IslandConfiguration, metrics: ScreenMetrics) {
        self.configuration = configuration
        self.metrics = metrics
    }

    public var layout: IslandLayout {
        IslandGeometry.layout(state: state, metrics: metrics, configuration: configuration,
                              compactSlotSizes: (leadingSize, trailingSize), expandedContentSize: contentSize)
    }

    public func setState(_ new: IslandState) {
        guard new != state else { return }
        state = new
        contentGeneration += 1
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
    }
}
