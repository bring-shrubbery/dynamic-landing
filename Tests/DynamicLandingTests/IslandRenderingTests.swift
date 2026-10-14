import AppKit
import SwiftUI
import Testing
@testable import DynamicLanding

/// Renders the island view itself, pose by pose, and measures the black it draws: the geometry
/// tests say where the island should be, these say where it is.
@MainActor
struct IslandRenderingTests {
    private let notched = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 600, height: 400), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)

    private func model(pose: IslandPose) -> IslandModel {
        let m = IslandModel(configuration: IslandConfiguration(), metrics: notched)
        m.setExpanded(AnyView(Color.clear.frame(width: 260, height: 64)))
        m.setCompact(leading: AnyView(Color.clear.frame(width: 30, height: 14)), trailing: AnyView(Color.clear.frame(width: 40, height: 14)))
        m.contentSize = CGSize(width: 260, height: 64)
        m.leadingSize = CGSize(width: 30, height: 14); m.trailingSize = CGSize(width: 40, height: 14)
        m.setState(pose == .docked ? .hidden : IslandState(pose), pose: pose)
        return m
    }

    /// The bounding box of the opaque pixels, in points from the top-left, of the island drawn
    /// in a panel-sized canvas.
    private func opaqueBounds(pose: IslandPose) throws -> CGRect {
        let canvas = CGSize(width: 300, height: 200)
        let renderer = ImageRenderer(content: IslandView(model: model(pose: pose)).frame(width: canvas.width, height: canvas.height, alignment: .top))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try #require(CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h { for x in 0..<w where data[(y * w + x) * 4 + 3] > 128 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        guard maxX >= 0 else { return .zero }
        // The bitmap's first row is the top of the image.
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    @Test func dockedDrawsABandAsWideAsTheExpandedIslandAndAsTallAsTheNotch() throws {
        let expanded = try opaqueBounds(pose: .expanded)
        let docked = try opaqueBounds(pose: .docked)
        let hidden = try opaqueBounds(pose: .hidden)
        #expect(expanded.minY == 0 && expanded.height == 38 + 10 + 64 + 12)
        #expect(docked.minY == 0, "the band hangs from the top edge")
        #expect(docked.height == 38, "the band is exactly the notch's height, not shorter")
        // The band is the expanded island's body: its flared top corners have slid out of view.
        let body = model(pose: .expanded).layout.rect.width - 2 * 15
        #expect(docked.width == body, "the band is as wide as the expanded island's body")
        #expect(docked.width > hidden.width, "wider than the notch, which the narrowing stage closes")
        #expect(hidden.height == 38 && hidden.width <= 200 && hidden.width >= 170)
        #expect(abs(docked.midX - hidden.midX) < 1 && abs(docked.midX - expanded.midX) < 1)
    }
}

private extension IslandState {
    init(_ pose: IslandPose) {
        switch pose {
        case .hidden: self = .hidden
        case .compact: self = .compact
        case .expanded, .docked: self = .expanded
        }
    }
}
