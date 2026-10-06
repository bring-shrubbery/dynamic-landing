// DynamicLanding — IslandCoordinator.swift
import Foundation

/// One island's side of the agreement over who has the notch.
///
/// The agreement, in full:
///
/// - An island that shows posts a *claim*. Every other island on the same display compares
///   it with its own: a claim with a higher priority wins, between equal priorities the later
///   claim wins, and a tie on both goes to the island id. The loser hides and *waits*.
/// - A holder that outranks a claim it hears answers with *holding*, so the newcomer learns
///   it lost before it has finished appearing. Holders also send *holding* every
///   `heartbeatInterval`, so a late-starting app knows who has the notch.
/// - A holder that hides posts *release*. A waiting island that still wants to show then
///   claims again, after a short delay that grows as its priority shrinks, so the most
///   important one goes first and the rest yield to it.
/// - A holder whose process ends, or whose heartbeat is missed for `staleAfter`, counts as
///   released.
///
/// The coordinator never touches the island itself; `onYield` and `onResume` tell the owner
/// to hide and to show again.
@MainActor
final class IslandCoordinator {
    struct Identity: Sendable {
        var islandID: String
        var pid: Int32
        var bundleID: String
    }

    /// Another island's last word, and when it was heard.
    private struct Known {
        var message: IslandMessage
        var heardAt: Date
    }

    var onYield: (() -> Void)?
    var onResume: (() -> Void)?

    /// True between losing the notch and getting it back; the owner's content is still wanted.
    private(set) var isWaiting = false
    /// True while this island has the notch as far as the others are concerned.
    private(set) var isHolding = false

    let identity: Identity
    private let bus: IslandBus
    private let now: () -> Date
    private let staleAfter: TimeInterval
    private let heartbeatInterval: Duration
    private let resumeDelay: (IslandPriority) -> Duration
    private var subscription: AnyObject?
    private var heartbeat: Task<Void, Never>?
    private var sweeper: Task<Void, Never>?
    private var resumeTask: Task<Void, Never>?
    private var others: [String: Known] = [:]
    private var priority = IslandPriority.normal
    private var displayID: UInt32 = 0
    private var claimedAt: Double = 0

    init(identity: Identity, bus: IslandBus, now: @escaping () -> Date = Date.init,
         staleAfter: TimeInterval = 5, heartbeatInterval: Duration = .seconds(2),
         resumeDelay: @escaping (IslandPriority) -> Duration = IslandCoordinator.defaultResumeDelay) {
        self.identity = identity
        self.bus = bus
        self.now = now
        self.staleAfter = staleAfter
        self.heartbeatInterval = heartbeatInterval
        self.resumeDelay = resumeDelay
        subscription = bus.subscribe { [weak self] event in self?.receive(event) }
    }

    /// The most important waiting island claims first: nothing for `.urgent`, 100 ms for
    /// `.background`, plus a little per-island jitter so equals rarely collide.
    nonisolated static func defaultResumeDelay(for priority: IslandPriority) -> Duration {
        let rank = max(0, min(100, 100 - priority.rawValue))
        return .milliseconds(rank + Int.random(in: 0...30))
    }

    /// The owner wants to show on `displayID` with `priority`. Returns false when a live
    /// island that outranks this one holds that display, in which case this island waits and
    /// `onResume` fires once the display is free.
    @discardableResult
    func claim(priority: IslandPriority, displayID: UInt32) -> Bool {
        resumeTask?.cancel(); resumeTask = nil
        self.priority = priority
        self.displayID = displayID
        prune()
        let mine = message(kind: .claim, claimedAt: now().timeIntervalSince1970)
        if others.values.contains(where: { $0.message.displayID == displayID && mine.isOutranked(by: $0.message) }) {
            isHolding = false
            isWaiting = true
            stopHeartbeat()
            return false
        }
        claimedAt = mine.claimedAt
        isHolding = true
        isWaiting = false
        bus.post(mine)
        // A holder that outranks us may have answered `holding` before the post returned
        // (the in-memory bus delivers synchronously); then we lost before we began.
        guard !isWaiting else { return false }
        startHeartbeat()
        return true
    }

    /// The owner hid its island on purpose: the notch is free and this island wants nothing.
    func release() {
        resumeTask?.cancel(); resumeTask = nil
        let wasHolding = isHolding
        isHolding = false
        isWaiting = false
        stopHeartbeat()
        if wasHolding { bus.post(message(kind: .release, claimedAt: claimedAt)) }
    }

    // MARK: - Receiving

    private func receive(_ event: IslandBusEvent) {
        switch event {
        case let .message(message):
            guard message.islandID != identity.islandID else { return }
            receive(message)
        case let .processEnded(pid):
            guard pid != identity.pid else { return }
            let gone = others.filter { $0.value.message.pid == pid }.map(\.key)
            guard !gone.isEmpty else { return }
            for id in gone { others.removeValue(forKey: id) }
            resumeIfFree()
        }
    }

    private func receive(_ message: IslandMessage) {
        switch message.kind {
        case .claim, .holding:
            others[message.islandID] = Known(message: message, heardAt: now())
            guard message.displayID == displayID else { return }
            if isHolding {
                let mine = self.message(kind: .holding, claimedAt: claimedAt)
                if mine.isOutranked(by: message) {
                    yield()
                } else if message.kind == .claim {
                    // The newcomer lost; tell it so it hides before it has fully appeared.
                    bus.post(mine)
                }
            } else if isWaiting {
                // A holder is still there; keep waiting, but a claim may have been scheduled
                // for a display that turns out to be taken after all.
                resumeTask?.cancel(); resumeTask = nil
            }
        case .release:
            others.removeValue(forKey: message.islandID)
            resumeIfFree()
        }
    }

    private func yield() {
        isHolding = false
        isWaiting = true
        stopHeartbeat()
        onYield?()
    }

    /// Nothing that outranks a fresh claim of ours is left on our display: claim again, after
    /// the priority-ranked delay.
    private func resumeIfFree() {
        guard isWaiting, resumeTask == nil else { return }
        prune()
        let probe = message(kind: .claim, claimedAt: now().timeIntervalSince1970)
        let blocked = others.values.contains { $0.message.displayID == displayID && probe.isOutranked(by: $0.message) }
        guard !blocked else { return }
        let delay = resumeDelay(priority)
        resumeTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, self.isWaiting else { return }
            self.resumeTask = nil
            self.onResume?()
        }
    }

    // MARK: - Heartbeat and staleness

    private func startHeartbeat() {
        stopHeartbeat()
        let interval = heartbeatInterval
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled, self.isHolding else { return }
                self.bus.post(self.message(kind: .holding, claimedAt: self.claimedAt))
            }
        }
        sweeper?.cancel()
        sweeper = nil
    }

    private func stopHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
        // While not holding, watch for holders that stop talking.
        if sweeper == nil {
            let interval = heartbeatInterval
            sweeper = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard let self, !Task.isCancelled else { return }
                    if self.prune() { self.resumeIfFree() }
                }
            }
        }
    }

    /// Forgets islands not heard from for `staleAfter`; true when any were.
    @discardableResult
    private func prune() -> Bool {
        let cutoff = now().addingTimeInterval(-staleAfter)
        let stale = others.filter { $0.value.heardAt < cutoff }.map(\.key)
        for id in stale { others.removeValue(forKey: id) }
        return !stale.isEmpty
    }

    private func message(kind: IslandMessage.Kind, claimedAt: Double) -> IslandMessage {
        IslandMessage(kind: kind, islandID: identity.islandID, pid: identity.pid, bundleID: identity.bundleID,
                      displayID: displayID, priority: priority.rawValue, claimedAt: claimedAt)
    }
}
