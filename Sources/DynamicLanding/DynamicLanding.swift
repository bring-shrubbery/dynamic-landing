// DynamicLanding — DynamicLanding.swift
import AppKit
import SwiftUI

/// A Dynamic Island for one screen. `show` morphs the island into the new state in place;
/// `hide` animates it away. Both return when the animation has run.
///
/// Calls take effect in the order they were scheduled on the main actor: `show` first yields,
/// so a `hide` already queued (say, `Task { await island.hide() }` just before a `show`)
/// starts first and is then cancelled by the show, instead of hiding the island the show
/// has just put up.
@MainActor @Observable
public final class DynamicLanding {
    public let model: IslandModel
    private let controller: IslandPanelController?
    private var screen: NSScreen?
    private var hideTask: Task<Void, Never>?
    private var generation = 0

    public var state: IslandState { model.state }
    public var isVisible: Bool { model.state != .hidden }
    public var configuration: IslandConfiguration {
        get { model.configuration }
        set { model.configuration = newValue }
    }
    public var onTap: (() -> Void)? {
        get { model.onTap }
        set { model.onTap = newValue }
    }

    /// `screen` nil means `NSScreen.main` at each show. `presentsPanel: false` is the headless
    /// mode for tests and previews: state and content change, no window appears.
    public init(configuration: IslandConfiguration = IslandConfiguration(), screen: NSScreen? = nil, presentsPanel: Bool = true) {
        let target = screen ?? NSScreen.main
        let metrics = target.map { ScreenMetrics(screen: $0) }
            ?? ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), notchSize: nil, menuBarHeight: 24)
        self.model = IslandModel(configuration: configuration, metrics: metrics)
        self.screen = screen
        self.controller = presentsPanel ? IslandPanelController(model: model) : nil
    }

    /// Headless, with explicit metrics (tests).
    init(configuration: IslandConfiguration, metrics: ScreenMetrics, presentsPanel: Bool) {
        self.model = IslandModel(configuration: configuration, metrics: metrics)
        self.controller = presentsPanel ? IslandPanelController(model: model) : nil
    }

    public func show<L: View, T: View>(@ViewBuilder compactLeading: () -> L, @ViewBuilder trailing: () -> T) async {
        let leading = AnyView(compactLeading()), trailing = AnyView(trailing())
        await Task.yield()
        model.setCompact(leading: leading, trailing: trailing)
        await transition(to: .compact)
    }

    public func show<C: View>(@ViewBuilder expanded: () -> C) async {
        let content = AnyView(expanded())
        await Task.yield()
        model.setExpanded(content)
        await transition(to: .expanded)
    }

    public func hide() async {
        guard model.state != .hidden else { return }
        generation += 1
        let mine = generation
        hideTask?.cancel()
        let task = Task { @MainActor in
            // A show that ran before this task started owns the island; this hide is stale.
            guard generation == mine else { return }
            // `.keepVisible`: wait (up to 10 s) while the pointer is over the island.
            if model.configuration.hoverBehavior.contains(.keepVisible) {
                var waited = 0
                while model.isHovering, waited < 100, generation == mine {
                    try? await Task.sleep(for: .milliseconds(100)); waited += 1
                }
                guard generation == mine else { return }
            }
            withAnimation(model.configuration.animation) { model.setState(.hidden) }
            controller?.refreshMousePassThrough()
            try? await Task.sleep(for: animationDuration)
            // A show that started meanwhile owns the island now; leave its panel and content alone.
            if generation == mine, model.state == .hidden {
                controller?.dismiss()
                model.clearContent()
            }
        }
        hideTask = task
        await task.value
    }

    private func transition(to state: IslandState) async {
        generation += 1
        hideTask?.cancel()
        hideTask = nil
        if let controller {
            let target = screen ?? NSScreen.main
            if let target {
                model.metrics = ScreenMetrics(screen: target)
                controller.present(on: target)
            }
        }
        withAnimation(model.configuration.animation) { model.setState(state) }
        controller?.refreshMousePassThrough()
        try? await Task.sleep(for: animationDuration)
    }

    private var animationDuration: Duration { model.configuration.animationDuration }
}
