// DynamicLanding — IslandPanelController.swift
import AppKit
import Observation
import OSLog
import SwiftUI

/// What the island does with its window, for `log show --predicate 'subsystem == "com.quassum.dynamic-landing"'`.
let islandLog = Logger(subsystem: "com.quassum.dynamic-landing", category: "panel")

/// Owns the panel for one screen: sizes it to the top-centre half of the screen, hosts the
/// island view top-aligned inside it, and lets clicks through everywhere but the island.
///
/// While presented, pass-through and hover are refreshed on every mouse event the monitors
/// see, on every layout change, and by a 100 ms poll of the pointer (a never-key panel does
/// not reliably receive mouse-moved events), so they never go stale.
@MainActor
final class IslandPanelController {
    private let model: IslandModel
    private var panel: IslandPanel?
    private var mouseMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var focusObservers: [NSObjectProtocol] = []
    /// Called while presented when the user moves to another Space or app, so the owner can
    /// put the island on the screen they are now using.
    var onFocusChange: (() -> Void)?
    private var pollTask: Task<Void, Never>?
    private var isPresented = false
    /// Bumped on every present and dismiss; a layout-observation chain re-arms only while
    /// the epoch it started in is current, so a dismiss→present cycle never leaves two.
    private var epoch = 0
    private(set) var screen: NSScreen?
    /// The island's window, for tests.
    var window: NSWindow? { panel }

    init(model: IslandModel) {
        self.model = model
    }

    /// Puts the panel on `screen`, with the island laid out for `metrics`.
    func present(on screen: NSScreen, metrics: ScreenMetrics) {
        self.screen = screen
        epoch += 1
        let target = Self.panelFrame(for: screen)
        if let panel {
            // The target screen may have changed since the last show.
            moveInstantly(panel, to: target, metrics: metrics)
        } else {
            createPanel(on: screen, metrics: metrics)
        }
        panel?.alphaValue = 1
        if !isPresented {
            isPresented = true
            installMouseMonitors()
            startPolling()
            observeScreenChanges()
            observeFocusChanges()
        }
        // The old chain (if any) is stale now; this one replaces it.
        observeLayout()
        panel?.orderFrontRegardless()
        measureContent()
        logWindow("present")
    }

    /// Creates the panel on `screen`, ordered in but fully transparent, so it is already on
    /// every Space before the first show. Does nothing once the panel exists.
    func prepare(on screen: NSScreen, metrics: ScreenMetrics) {
        guard panel == nil else { return }
        createPanel(on: screen, metrics: metrics)
        panel?.alphaValue = 0
        logWindow("prepare")
    }

    private func createPanel(on screen: NSScreen, metrics: ScreenMetrics) {
        let target = Self.panelFrame(for: screen)
        do {
            model.metrics = metrics
            let panel = IslandPanel(contentRect: target)
            let hosting = NSHostingView(rootView: IslandView(model: model).ignoresSafeArea())
            // The island sits under the notch on purpose: no safe-area inset may push it down.
            hosting.safeAreaRegions = []
            hosting.frame = NSRect(origin: .zero, size: target.size)
            hosting.autoresizingMask = [.width, .height]
            // The panel is sized by `panelFrame`, never by the island's content: without this the
            // hosting view rewrites the window's min/max sizes on every layout change.
            hosting.sizingOptions = []
            panel.contentView = hosting
            self.panel = panel
            // Lay out the hidden island and put the panel on screen now, before the caller sets
            // the new state inside `withAnimation`, so the very first grow animates from the
            // hidden layout instead of appearing at full size.
            hosting.layoutSubtreeIfNeeded()
            panel.orderFrontRegardless()
        }
    }

    private func logWindow(_ event: String) {
        guard let panel else { return }
        let display = screen.flatMap(Self.displayNumber)?.stringValue ?? "?"
        islandLog.info("\(event, privacy: .public): display \(display, privacy: .public) frame \(NSStringFromRect(panel.frame), privacy: .public) visible \(panel.isVisible) onActiveSpace \(panel.isOnActiveSpace) occlusionVisible \(panel.occlusionState.contains(.visible)) alpha \(panel.alphaValue) level \(panel.level.rawValue) state \(String(describing: self.model.state), privacy: .public)")
    }

    /// Lays the island out now, which measures content set since the last pass at once (the
    /// size readers report during the pass). Called before every state change is animated: the
    /// island's size comes from those measurements, and without this the change animated toward
    /// the previous content's size and was re-aimed a frame later, when the new size arrived —
    /// a two-step resize that read as a wobble.
    func measureContent() {
        panel?.contentView?.layoutSubtreeIfNeeded()
    }

    /// Hides the panel and stops watching the mouse and the screen until the next `present`.
    /// The panel stays ordered in, transparent and click-through: a window ordered out and in
    /// again for every show was not always put on the Space in front (other desktops, full-screen
    /// apps), while one that stays in joins every Space once and keeps them.
    func dismiss() {
        epoch += 1
        panel?.alphaValue = 0
        isPresented = false
        for monitor in mouseMonitors { NSEvent.removeMonitor(monitor) }
        mouseMonitors.removeAll()
        pollTask?.cancel(); pollTask = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        for observer in focusObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        focusObservers.removeAll()
        panel?.ignoresMouseEvents = true
        if model.isHovering { model.isHovering = false }
    }

    /// Pass-through follows the pointer and the island. While the island is hiding (state
    /// hidden, panel still up) it ignores the mouse entirely.
    func refreshMousePassThrough() {
        guard let panel else { return }
        let inside = model.state != .hidden
            && !MousePassThrough.shouldIgnoreMouse(pointer: NSEvent.mouseLocation, islandRect: model.layout.rect)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        if model.isHovering != inside { model.isHovering = inside }
    }

    private static func displayNumber(of screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }

    private static func panelFrame(for screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let size = NSSize(width: frame.width / 2, height: frame.height / 2)
        return NSRect(origin: NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height), size: size)
    }

    private func installMouseMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in self?.refreshMousePassThrough() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in handler(event); return event }) {
            mouseMonitors.append(local)
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // A freed controller ends the loop rather than polling forever.
                guard let self else { return }
                self.refreshMousePassThrough()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    /// Re-armed after each change while presented (observation tracking fires once).
    private func observeLayout() {
        guard isPresented else { return }
        let token = epoch
        withObservationTracking {
            _ = model.layout
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.epoch == token else { return }
                self.refreshMousePassThrough()
                self.observeLayout()
            }
        }
    }

    /// A display added, removed or rearranged: re-read the metrics and move the panel.
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.screenParametersChanged() }
        }
    }

    /// Another Space, or another app in front: the island follows to that screen. Spaces are
    /// covered by the panel's collection behaviour too; the panel is brought to the front again
    /// there in any case.
    private func observeFocusChanges() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            focusObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isPresented else { return }
                    self.panel?.orderFrontRegardless()
                    self.panel?.display()
                    self.onFocusChange?()
                    self.logWindow(name == NSWorkspace.activeSpaceDidChangeNotification ? "space changed" : "app activated")
                }
            })
        }
    }

    private func screenParametersChanged() {
        guard isPresented else { return }
        // NSScreen objects are recreated on a reconfiguration; the display number is stable.
        let current = screen.flatMap(Self.displayNumber).flatMap { number in
            NSScreen.screens.first { Self.displayNumber(of: $0) == number }
        } ?? FocusedScreen.current()
        guard let current else { return }
        screen = current
        if let panel {
            moveInstantly(panel, to: Self.panelFrame(for: current), metrics: ScreenMetrics(screen: current))
        } else {
            model.metrics = ScreenMetrics(screen: current)
        }
        refreshMousePassThrough()
    }

    /// Moves the panel to another screen (or resizes it for a changed one) with no animation.
    /// The island's layout animates every change, and a new screen changes it too: animated,
    /// the island slid across from where it sat on the old screen. Nothing happens when the
    /// screen is the same, so content changes there still animate.
    private func moveInstantly(_ panel: IslandPanel, to frame: NSRect, metrics: ScreenMetrics) {
        guard panel.frame != frame || model.metrics != metrics else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            model.metrics = metrics
            if panel.frame != frame { panel.setFrame(frame, display: false) }
            panel.contentView?.layoutSubtreeIfNeeded()
        }
    }
}
