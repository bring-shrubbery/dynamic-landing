// DynamicLanding — IslandPanelController.swift
import AppKit
import Observation
import SwiftUI

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

    init(model: IslandModel) {
        self.model = model
    }

    func present(on screen: NSScreen) {
        self.screen = screen
        epoch += 1
        let target = Self.panelFrame(for: screen)
        if let panel {
            // The target screen may have changed since the last show.
            if panel.frame != target { panel.setFrame(target, display: false) }
        } else {
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
    func dismiss() {
        epoch += 1
        panel?.orderOut(nil)
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
                    self.onFocusChange?()
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
        model.metrics = ScreenMetrics(screen: current)
        let target = Self.panelFrame(for: current)
        if let panel, panel.frame != target { panel.setFrame(target, display: false) }
        refreshMousePassThrough()
    }
}
