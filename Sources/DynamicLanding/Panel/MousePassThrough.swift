// DynamicLanding — MousePassThrough.swift
import CoreGraphics

/// The host panel is far larger than the island, so it must not swallow clicks around it: it
/// ignores the mouse unless the pointer is over the island's rect (screen coordinates).
enum MousePassThrough {
    static func shouldIgnoreMouse(pointer: CGPoint, islandRect: CGRect) -> Bool {
        guard !islandRect.isEmpty else { return true }
        return !islandRect.contains(pointer)
    }
}
