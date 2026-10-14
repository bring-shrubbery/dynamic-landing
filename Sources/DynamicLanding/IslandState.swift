// DynamicLanding — IslandState.swift
import Foundation

/// What the island is showing.
public enum IslandState: Equatable, Sendable {
    case hidden
    /// A leading and a trailing slot around the notch (or a narrow pill).
    case compact
    /// Rich content below the notch.
    case expanded
}

/// The shape the island is drawn in, which on a notched screen passes through steps a state
/// alone does not name. Internal: callers only ever see `IslandState`.
enum IslandPose: Equatable, Sendable {
    /// The state's own shape: none, compact or expanded (`.hidden` covers the notch exactly).
    case hidden, compact, expanded
    /// As wide as the expanded island and as tall as the notch, at the notch's level. On a
    /// notched screen the island changes one dimension at a time: at the notch's height it
    /// only changes width, above it only height. So it passes through here on every way to
    /// or from the expanded shape: the notch or the compact island widens into it and it drops
    /// down; the expanded island rises back up to it and it narrows away.
    case docked

    init(_ state: IslandState) {
        switch state {
        case .hidden: self = .hidden
        case .compact: self = .compact
        case .expanded: self = .expanded
        }
    }
}
