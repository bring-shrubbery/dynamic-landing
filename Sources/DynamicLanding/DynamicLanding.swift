// DynamicLanding — DynamicLanding.swift
import AppKit
import SwiftUI

/// A Dynamic Island for one screen. `show` morphs the island into the new state in place;
/// `hide` animates it away. Both return when the animation has run.
///
/// The call that starts last wins: every call applies its effect synchronously, before its
/// first suspension, and a later call supersedes whatever an earlier one is still waiting on.
@MainActor @Observable
public final class DynamicLanding {
    public let model: IslandModel
    @ObservationIgnored private let controller: IslandPanelController?
    @ObservationIgnored private let screen: NSScreen?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

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
        self.screen = nil
        self.controller = presentsPanel ? IslandPanelController(model: model) : nil
    }

    public func show<L: View, T: View>(@ViewBuilder compactLeading: () -> L, @ViewBuilder trailing: () -> T) async {
        model.setCompact(leading: AnyView(compactLeading()), trailing: AnyView(trailing()))
        await transition(to: .compact)
    }

    public func show<C: View>(@ViewBuilder expanded: () -> C) async {
        model.setExpanded(AnyView(expanded()))
        await transition(to: .expanded)
    }

    public func hide() async {
        // A hide already in flight: wait for it instead of starting over. A show clears
        // `hideTask`, so this never waits on a hide that a later show has superseded.
        if let hideTask {
            await hideTask.value
            return
        }
        guard model.state != .hidden else { return }
        generation += 1
        let mine = generation
        // The duration in force when the hide was called, not when its sleep starts.
        let duration = animationDuration
        // `.keepVisible`: while the pointer is over the island, the hide waits for it to leave.
        let held = model.configuration.hoverBehavior.contains(.keepVisible) && model.isHovering
        if !held { applyHidden() }
        let task = Task { @MainActor in
            // However this task ends, it is no longer a hide in flight for later calls to wait on.
            defer { if generation == mine { hideTask = nil } }
            if held {
                var waited = 0   // at most 10 s
                while model.isHovering, waited < 100, generation == mine, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100)); waited += 1
                }
                guard generation == mine else { return }
                applyHidden()
            }
            try? await Task.sleep(for: duration)
            // A later call owns the island now; leave its panel and content alone.
            guard generation == mine, model.state == .hidden else { return }
            controller?.dismiss()
            model.clearContent()
        }
        hideTask = task
        await task.value
    }

    private func applyHidden() {
        withAnimation(model.configuration.animation) { model.setState(.hidden) }
        controller?.refreshMousePassThrough()
    }

    /// Everything up to the sleep runs synchronously, so the show takes effect the moment it
    /// is called; cancelling the hide task ends a pending hide's wait at once.
    private func transition(to state: IslandState) async {
        generation += 1
        hideTask?.cancel()
        hideTask = nil
        if let controller, let target = screen ?? NSScreen.main {
            model.metrics = ScreenMetrics(screen: target)
            controller.present(on: target)
        }
        withAnimation(model.configuration.animation) { model.setState(state) }
        controller?.refreshMousePassThrough()
        try? await Task.sleep(for: animationDuration)
    }

    private var animationDuration: Duration { model.configuration.animationDuration }
}
