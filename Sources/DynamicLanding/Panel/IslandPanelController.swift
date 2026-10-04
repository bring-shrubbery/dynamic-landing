// DynamicLanding — IslandPanelController.swift
import AppKit
import SwiftUI

/// Owns the panel for one screen: sizes it to the top-centre half of the screen, hosts the
/// island view top-aligned inside it, and lets clicks through everywhere but the island.
@MainActor
final class IslandPanelController {
    private let model: IslandModel
    private var panel: IslandPanel?
    private var mouseMonitors: [Any] = []
    private(set) var screen: NSScreen?

    init(model: IslandModel) {
        self.model = model
    }

    func present(on screen: NSScreen) {
        self.screen = screen
        let frame = screen.frame
        let size = NSSize(width: frame.width / 2, height: frame.height / 2)
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height)
        let target = NSRect(origin: origin, size: size)
        if let panel {
            // The target screen may have changed since the last show.
            if panel.frame != target { panel.setFrame(target, display: false) }
        } else {
            let panel = IslandPanel(contentRect: target)
            let hosting = NSHostingView(rootView: IslandView(model: model))
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            self.panel = panel
        }
        if mouseMonitors.isEmpty { installMouseMonitors() }
        panel?.orderFrontRegardless()
    }

    /// Hides the panel and stops watching the mouse until the next `present`.
    func dismiss() {
        panel?.orderOut(nil)
        removeMouseMonitors()
        model.isHovering = false
    }

    /// Called whenever the layout changes: pass-through follows the pointer and the island.
    func refreshMousePassThrough() {
        guard let panel else { return }
        let pointer = NSEvent.mouseLocation
        let inside = !MousePassThrough.shouldIgnoreMouse(pointer: pointer, islandRect: model.layout.rect)
        panel.ignoresMouseEvents = !inside
        if model.isHovering != inside { model.isHovering = inside }
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

    private func removeMouseMonitors() {
        for monitor in mouseMonitors { NSEvent.removeMonitor(monitor) }
        mouseMonitors.removeAll()
    }
}
