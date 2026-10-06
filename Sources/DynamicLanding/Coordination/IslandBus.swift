// DynamicLanding — IslandBus.swift
import AppKit
import Foundation

/// What a coordinator hears from the bus.
enum IslandBusEvent: Equatable, Sendable {
    case message(IslandMessage)
    /// A process ended; everything it held is released, whether or not it said so.
    case processEnded(pid: Int32)
}

/// Carries `IslandMessage`s between every island on the machine. The production bus is
/// distributed notifications; tests use an in-memory one shared by several islands.
@MainActor
protocol IslandBus: AnyObject {
    func post(_ message: IslandMessage)
    /// Delivers every event, including the caller's own messages, on the main actor. The
    /// returned token keeps the subscription alive.
    func subscribe(_ handler: @escaping @MainActor @Sendable (IslandBusEvent) -> Void) -> AnyObject
}

/// The system-wide bus: a distributed notification per message, which every process on the
/// machine can post and receive without entitlements, a helper or any setup. Also reports
/// processes ending, so a crashed app's island does not hold the notch until its heartbeat
/// is missed.
@MainActor
final class DistributedIslandBus: IslandBus {
    static let shared = DistributedIslandBus()

    private final class Token {
        let observers: [NSObjectProtocol]
        init(observers: [NSObjectProtocol]) { self.observers = observers }
        deinit {
            for observer in observers {
                DistributedNotificationCenter.default().removeObserver(observer)
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
        }
    }

    private init() {}

    func post(_ message: IslandMessage) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(IslandMessage.notificationName), object: message.encoded(), userInfo: nil,
            deliverImmediately: true
        )
    }

    func subscribe(_ handler: @escaping @MainActor @Sendable (IslandBusEvent) -> Void) -> AnyObject {
        let messages = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(IslandMessage.notificationName), object: nil, queue: .main
        ) { notification in
            guard let string = notification.object as? String, let message = IslandMessage.decode(string) else { return }
            MainActor.assumeIsolated { handler(.message(message)) }
        }
        let ended = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { handler(.processEnded(pid: pid)) }
        }
        return Token(observers: [messages, ended])
    }
}

/// An in-memory bus for tests and previews: every island given the same instance hears the
/// others. Delivery is synchronous, in order.
@MainActor
final class LocalIslandBus: IslandBus {
    private final class Subscription {
        let handler: @MainActor @Sendable (IslandBusEvent) -> Void
        init(handler: @escaping @MainActor @Sendable (IslandBusEvent) -> Void) { self.handler = handler }
    }

    private var subscriptions: [WeakBox] = []
    private var dropped: Set<String> = []
    private(set) var log: [IslandMessage] = []

    private struct WeakBox { weak var subscription: Subscription? }

    init() {}

    func post(_ message: IslandMessage) {
        guard !dropped.contains(message.islandID) else { return }
        log.append(message)
        deliver(.message(message))
    }

    /// Swallow everything this island posts from now on: the app froze or lost the bus.
    func drop(from islandID: String) {
        dropped.insert(islandID)
    }

    /// Pretend a process died.
    func endProcess(pid: Int32) {
        deliver(.processEnded(pid: pid))
    }

    func subscribe(_ handler: @escaping @MainActor @Sendable (IslandBusEvent) -> Void) -> AnyObject {
        let subscription = Subscription(handler: handler)
        subscriptions.append(WeakBox(subscription: subscription))
        return subscription
    }

    private func deliver(_ event: IslandBusEvent) {
        subscriptions.removeAll { $0.subscription == nil }
        for box in subscriptions {
            box.subscription?.handler(event)
        }
    }
}
