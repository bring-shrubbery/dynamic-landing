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
