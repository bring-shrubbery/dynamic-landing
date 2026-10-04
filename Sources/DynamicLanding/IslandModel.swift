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
    /// Bumped on every content change so a same-state replacement still fades.
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

    public func setState(_ new: IslandState) { state = new }

    func setCompact(leading: AnyView, trailing: AnyView) {
        compactLeading = leading; compactTrailing = trailing; contentGeneration += 1
    }

    func setExpanded(_ content: AnyView) {
        expandedContent = content; contentGeneration += 1
    }
}
