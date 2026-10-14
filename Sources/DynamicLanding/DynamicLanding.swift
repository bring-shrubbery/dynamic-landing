// DynamicLanding — DynamicLanding.swift
import AppKit
import SwiftUI

/// A Dynamic Island for one screen. `show` morphs the island into the new state in place;
/// `hide` animates it away. Both return when the animation has run.
///
/// The call that starts last wins: every call applies its effect synchronously, before its
/// first suspension, and a later call supersedes whatever an earlier one is still waiting on.
///
/// Islands share the notch. When another island (in this app or any other) that outranks
/// this one shows on the same display, this one hides and keeps its content; when that
/// island is done, this one shows again by itself. `isYielded`, `onYield` and `onResume`
/// report that; `configuration.priority` decides who outranks whom, and
/// `configuration.coordination = .none` opts out. See `Docs/Coordination.md`.
@MainActor @Observable
public final class DynamicLanding {
    public let model: IslandModel
    @ObservationIgnored private(set) var controller: IslandPanelController?
    @ObservationIgnored private let screen: NSScreen?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let coordinator: IslandCoordinator
    /// What the app last asked for; a yielded island shows this again once the notch is free.
    @ObservationIgnored private var requested: IslandState = .hidden
    /// Tests pin the display an island believes it is on.
    @ObservationIgnored var displayIDOverride: UInt32?

    /// True while another island has the notch and this one waits with its content kept.
    public private(set) var isYielded = false
    /// Another island took the notch and this one has hidden. Pause what it was timing, if anything.
    @ObservationIgnored public var onYield: (() -> Void)?
    /// The notch is free again and this island is showing what it was last asked to show.
    @ObservationIgnored public var onResume: (() -> Void)?

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

    /// `screen` nil means the screen the user is working on, followed as they move between
    /// Spaces, apps and displays (see `FocusedScreen`). `presentsPanel: false` is the headless
    /// mode for tests and previews: state and content change, no window appears.
    public init(configuration: IslandConfiguration = IslandConfiguration(), screen: NSScreen? = nil, presentsPanel: Bool = true) {
        let target = screen ?? FocusedScreen.current()
        let metrics = target.map { ScreenMetrics(screen: $0) }
            ?? ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), notchSize: nil, menuBarHeight: 24)
        self.model = IslandModel(configuration: configuration, metrics: metrics)
        self.screen = screen
        self.controller = presentsPanel ? IslandPanelController(model: model) : nil
        self.coordinator = IslandCoordinator(identity: Self.identity(), bus: DistributedIslandBus.shared)
        wireCoordinator()
        controller?.onFocusChange = { [weak self] in self?.followFocus() }
    }

    /// Creates the island's window now, invisible, instead of at the first show. Call it at
    /// launch: the window then joins every Space (desktops and full-screen apps) before it is
    /// first needed. Optional; a show does the same when it has not been done.
    public func prepare() {
        guard let target = screen ?? FocusedScreen.current() else { return }
        controller?.prepare(on: target, metrics: ScreenMetrics(screen: target))
    }

    /// The user moved to another Space or app: an island not pinned to a screen moves to the
    /// one they are using now, and claims the notch there.
    private func followFocus() {
        guard screen == nil, requested != .hidden, !isYielded,
              let target = FocusedScreen.current(), target != controller?.screen else { return }
        let state = requested
        Task { @MainActor in await self.present(state) }
    }

    /// Headless, with explicit metrics and a bus of the caller's choosing (tests).
    init(configuration: IslandConfiguration, metrics: ScreenMetrics, presentsPanel: Bool,
         bus: IslandBus, timing: CoordinationTiming = CoordinationTiming(), identity: IslandCoordinator.Identity? = nil) {
        self.model = IslandModel(configuration: configuration, metrics: metrics)
        self.screen = nil
        self.controller = presentsPanel ? IslandPanelController(model: model) : nil
        self.coordinator = IslandCoordinator(
            identity: identity ?? Self.identity(), bus: bus, staleAfter: timing.staleAfter,
            heartbeatInterval: timing.heartbeatInterval, resumeDelay: timing.resumeDelay
        )
        wireCoordinator()
    }

    struct CoordinationTiming {
        var staleAfter: TimeInterval = 5
        var heartbeatInterval: Duration = .seconds(2)
        var resumeDelay: (IslandPriority) -> Duration = IslandCoordinator.defaultResumeDelay
    }

    var coordinatorIdentity: IslandCoordinator.Identity { coordinator.identity }

    private static func identity() -> IslandCoordinator.Identity {
        IslandCoordinator.Identity(
            islandID: UUID().uuidString,
            pid: ProcessInfo.processInfo.processIdentifier,
            bundleID: Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        )
    }

    private func wireCoordinator() {
        coordinator.onYield = { [weak self] in self?.yieldToOther() }
        coordinator.onResume = { [weak self] in
            guard let self, self.isYielded, self.requested != .hidden else { return }
            let state = self.requested
            Task { @MainActor in await self.present(state) }
        }
    }

    public func show<L: View, T: View>(@ViewBuilder compactLeading: () -> L, @ViewBuilder trailing: () -> T) async {
        model.setCompact(leading: AnyView(compactLeading()), trailing: AnyView(trailing()))
        requested = .compact
        await present(.compact)
    }

    public func show<C: View>(@ViewBuilder expanded: () -> C) async {
        model.setExpanded(AnyView(expanded()))
        requested = .expanded
        await present(.expanded)
    }

    public func hide() async {
        requested = .hidden
        if model.configuration.coordination == .shared { coordinator.release() }
        if isYielded {
            // Hidden already, for another island; only the kept content goes.
            isYielded = false
            model.clearContent()
            controller?.dismiss()
            return
        }
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
            guard await settleHidden(mine, duration: duration) else { return }
            controller?.dismiss()
            model.clearContent()
        }
        hideTask = task
        await task.value
    }

    private func applyHidden() {
        // On a notched screen the expanded island first rises, at its own width, until only a
        // notch's height of it shows; `settleHidden` then narrows that band into the notch. Any
        // other shape is already at the notch's height and narrows into it at once.
        let rises = model.stagesThroughNotch && model.pose == .expanded
        withAnimation(model.configuration.animation) {
            model.setState(.hidden, pose: rises ? .docked : .hidden)
        }
        controller?.refreshMousePassThrough()
    }

    /// Waits for a hide's animation and, when the island rose to the notch's level first,
    /// runs its second stage: narrowing into the notch. False when a later call has taken the
    /// island over, in which case its panel and content are left alone.
    private func settleHidden(_ mine: Int, duration: Duration) async -> Bool {
        try? await Task.sleep(for: duration)
        guard generation == mine, model.state == .hidden else { return false }
        if model.pose == .docked {
            animate { model.setPose(.hidden) }
            try? await Task.sleep(for: duration)
            guard generation == mine, model.state == .hidden else { return false }
        }
        return true
    }

    private func animate(_ change: () -> Void) {
        withAnimation(model.configuration.animation, change)
    }

    // MARK: - Sharing the notch

    /// Shows `state` unless an island that outranks this one holds the display, in which
    /// case this one hides, keeps its content and waits for the notch.
    private func present(_ state: IslandState) async {
        if model.configuration.coordination == .shared,
           !coordinator.claim(priority: model.configuration.priority, displayID: currentDisplayID()) {
            yieldToOther()
            return
        }
        let resuming = isYielded
        isYielded = false
        await transition(to: state)
        if resuming { onResume?() }
    }

    /// Another island won the display: hide at once (no hover wait) and keep the content.
    private func yieldToOther() {
        let wasYielded = isYielded
        isYielded = true
        if model.state != .hidden {
            generation += 1
            let mine = generation
            hideTask?.cancel()
            hideTask = nil
            applyHidden()
            let duration = animationDuration
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard await self.settleHidden(mine, duration: duration) else { return }
                self.controller?.dismiss()
            }
        }
        if !wasYielded { onYield?() }
    }

    private func currentDisplayID() -> UInt32 {
        if let displayIDOverride { return displayIDOverride }
        let target = screen ?? FocusedScreen.current()
        let number = target?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.uint32Value ?? 0
    }

    /// Everything up to the sleep runs synchronously, so the show takes effect the moment it
    /// is called; cancelling the hide task ends a pending hide's wait at once. Presenting the
    /// panel measures the new content first, so the state change animates once, straight to
    /// the size the content needs.
    private func transition(to state: IslandState) async {
        generation += 1
        hideTask?.cancel()
        hideTask = nil
        let mine = generation
        if let controller, let target = screen ?? FocusedScreen.current() {
            controller.present(on: target, metrics: metricsOverride ?? ScreenMetrics(screen: target))
        }
        let from = model.pose
        guard model.stagesThroughNotch, state != .hidden else {
            animate { model.setState(state) }
            controller?.refreshMousePassThrough()
            try? await Task.sleep(for: animationDuration)
            return
        }
        // On a notched screen the notch stays put and the island changes one dimension at a
        // time: at the notch's height it only changes width, above it only height. Every way to
        // or from the expanded shape passes through `.docked`, as wide as the expanded island
        // and as tall as the notch: the notch or the compact island widens into it and it drops
        // down, or the expanded island rises to it and it narrows. So nothing wider than the
        // notch ever shows at less than the notch's height.
        switch (from, state) {
        case (.hidden, .expanded), (.compact, .expanded), (.expanded, .compact):
            animate { model.setState(state, pose: .docked) }
            controller?.refreshMousePassThrough()
            try? await Task.sleep(for: animationDuration)
            guard generation == mine else { return }
            animate { model.setPose(IslandPose(state)) }
        default:
            // The same shape, or from docked (a show interrupting a staged change): one morph.
            animate { model.setState(state) }
        }
        controller?.refreshMousePassThrough()
        try? await Task.sleep(for: animationDuration)
    }

    private var animationDuration: Duration { model.configuration.animationDuration }

    /// Metrics used instead of the screen's own, for tests (a notch on a notchless display).
    var metricsOverride: ScreenMetrics?
}
