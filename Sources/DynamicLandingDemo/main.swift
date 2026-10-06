// DynamicLanding — DynamicLandingDemo/main.swift
import AppKit
import DynamicLanding
import SwiftUI

@MainActor
final class DemoApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var island = DynamicLanding()
    /// A second island in the same process, ranked urgent: what another app's prompt is.
    private var interrupter: DynamicLanding = {
        var config = IslandConfiguration()
        config.priority = .urgent
        return DynamicLanding(configuration: config)
    }()
    private var seconds = 0
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "DynamicLanding")
        let menu = NSMenu()
        menu.addItem(withTitle: "Compact (waveform · timer)", action: #selector(compact), keyEquivalent: "1")
        menu.addItem(withTitle: "Expanded (card)", action: #selector(expanded), keyEquivalent: "2")
        menu.addItem(withTitle: "Hide", action: #selector(hide), keyEquivalent: "0")
        menu.addItem(withTitle: "Interrupt with an urgent island", action: #selector(interrupt), keyEquivalent: "3")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Style: automatic", action: #selector(styleAuto), keyEquivalent: "")
        menu.addItem(withTitle: "Style: notch", action: #selector(styleNotch), keyEquivalent: "")
        menu.addItem(withTitle: "Style: pill", action: #selector(stylePill), keyEquivalent: "")
        menu.addItem(withTitle: "Toggle shadow", action: #selector(toggleShadow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        // Through `hide()`, so the compact timer stops too and cannot bring the island back.
        island.onTap = { [weak self] in self?.hide() }
        // What an app does when another island takes the notch: pause, and resume after.
        island.onYield = { NSLog("DynamicLandingDemo: yielded the notch") }
        island.onResume = { NSLog("DynamicLandingDemo: back in the notch") }
    }

    /// An urgent island for three seconds. The timer's island yields and comes back after.
    @objc func interrupt() {
        Task {
            await interrupter.show(expanded: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.bubble.fill").font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Another app needs the notch").font(.headline)
                        Text("Urgent priority · gone in 3 s").font(.caption).opacity(0.7)
                    }
                }
            })
            try? await Task.sleep(for: .seconds(3))
            await interrupter.hide()
        }
    }

    @objc func compact() {
        seconds = 0
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // A tick queued before Hide or Expanded must not bring compact back.
                guard let self, self.timer?.isValid == true else { return }
                self.seconds += 1
                self.showCompact()
            }
        }
        // `.common` so it keeps ticking while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        showCompact()
    }

    /// Re-showing compact while it is already up updates the slots in place (no crossfade).
    private func showCompact() {
        let s = seconds
        Task {
            await island.show(compactLeading: { Image(systemName: "waveform").font(.system(size: 14, weight: .semibold)) },
                              trailing: { Text(String(format: "%d:%02d", s / 60, s % 60)).font(.system(size: 12, weight: .medium).monospacedDigit()) })
        }
    }

    @objc func expanded() {
        timer?.invalidate()
        Task {
            await island.show(expanded: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill").font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Listening…").font(.headline)
                        Text("Press the shortcut to stop · Email").font(.caption).opacity(0.7)
                    }
                }
            })
        }
    }

    @objc func hide() { timer?.invalidate(); Task { await island.hide() } }
    @objc func styleAuto() { island.configuration.style = .automatic }
    @objc func styleNotch() { island.configuration.style = .notch(topCornerRadius: 15, bottomCornerRadius: 20) }
    @objc func stylePill() { island.configuration.style = .pill(cornerRadius: 16) }
    @objc func toggleShadow() {
        island.configuration.shadow = island.configuration.shadow == .none ? .soft(radius: 10, opacity: 0.4) : .none
    }
}

// Top-level code is not main-actor isolated here, but it runs on the main thread.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = DemoApp()   // `run()` never returns, so this lives as long as the app
    app.delegate = delegate
    app.run()
}
