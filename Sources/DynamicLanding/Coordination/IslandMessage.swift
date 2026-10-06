// DynamicLanding — IslandMessage.swift
import Foundation

/// How important an island's content is when two apps want the same notch. A higher
/// priority holds the notch against a lower one; between equals, the island shown last wins.
///
/// Use the named levels or any integer: `IslandPriority(rawValue: 60)` sits between
/// `.normal` and `.high`.
public struct IslandPriority: RawRepresentable, Hashable, Comparable, Sendable, ExpressibleByIntegerLiteral {
    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(integerLiteral value: Int) { self.rawValue = value }

    /// Passive status that anything may replace: a clock, a quiet "listening" pill.
    public static let background = IslandPriority(rawValue: 0)
    /// The default.
    public static let normal = IslandPriority(rawValue: 50)
    /// Something the user is in the middle of: a recording, a running timer they started.
    public static let high = IslandPriority(rawValue: 75)
    /// Something that needs the user now: a permission prompt, a question.
    public static let urgent = IslandPriority(rawValue: 100)

    public static func < (lhs: IslandPriority, rhs: IslandPriority) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One message on the bus that islands in different apps share. Encoded as JSON and sent as
/// the `object` string of a distributed notification named `IslandMessage.notificationName`,
/// so that sandboxed apps, whose distributed notifications lose their `userInfo`, take part
/// like any other.
///
/// The format is public so that other implementations can join the same agreement; see
/// `Docs/Coordination.md`.
public struct IslandMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// The sender is showing its island now.
        case claim
        /// The sender is still showing its island (sent every `heartbeatInterval` while it
        /// holds the notch, and in reply to a claim it outranks).
        case holding
        /// The sender has hidden its island; the notch is free.
        case release
    }

    /// The format this library writes. Readers ignore messages with a higher version.
    public static let currentVersion = 1
    public static let notificationName = "com.quassum.dynamic-landing.island"

    public var version: Int
    public var kind: Kind
    /// Identifies one `DynamicLanding` instance; two in one process are two islands.
    public var islandID: String
    public var pid: Int32
    public var bundleID: String
    /// The display the island is on (`CGDirectDisplayID`); islands on different displays never
    /// interact.
    public var displayID: UInt32
    public var priority: Int
    /// Seconds since 1970 when the sender last claimed; the tiebreak between equal priorities.
    public var claimedAt: Double

    public init(version: Int = IslandMessage.currentVersion, kind: Kind, islandID: String, pid: Int32, bundleID: String,
                displayID: UInt32, priority: Int, claimedAt: Double) {
        self.version = version
        self.kind = kind
        self.islandID = islandID
        self.pid = pid
        self.bundleID = bundleID
        self.displayID = displayID
        self.priority = priority
        self.claimedAt = claimedAt
    }

    public func encoded() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: (try? encoder.encode(self)) ?? Data(), as: UTF8.self)
    }

    /// Nil for anything that is not a message this version understands.
    public static func decode(_ string: String) -> IslandMessage? {
        guard let message = try? JSONDecoder().decode(IslandMessage.self, from: Data(string.utf8)),
              message.version <= currentVersion else { return nil }
        return message
    }

    /// Whether `other` outranks this sender's claim: a higher priority, or the same priority
    /// claimed later. Ties on both fall to the island id, so two islands never both win.
    public func isOutranked(by other: IslandMessage) -> Bool {
        if other.priority != priority { return other.priority > priority }
        if other.claimedAt != claimedAt { return other.claimedAt > claimedAt }
        return other.islandID > islandID
    }
}
