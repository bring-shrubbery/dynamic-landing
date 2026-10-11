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
    /// As wide as the expanded island but no height, tucked against the screen's top edge.
    /// On a notched screen the expanded island grows down from here and retracts up into it,
    /// so it only ever changes height.
    case tucked

    init(_ state: IslandState) {
        switch state {
        case .hidden: self = .hidden
        case .compact: self = .compact
        case .expanded: self = .expanded
        }
    }
}
