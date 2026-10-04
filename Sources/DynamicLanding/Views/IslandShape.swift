// DynamicLanding — IslandShape.swift
import SwiftUI

/// The island's silhouette. Notch look: the top corners flare outward so the shape meets the
/// menu bar like the real notch; pill look: flat on top, rounded below.
public struct IslandShape: Shape {
    public var look: IslandLook
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public init(look: IslandLook, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.look = look
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set { topCornerRadius = newValue.first; bottomCornerRadius = newValue.second }
    }

    public func path(in rect: CGRect) -> Path {
        switch look {
        case .pill:
            return Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(
                topLeading: 0, bottomLeading: bottomCornerRadius, bottomTrailing: bottomCornerRadius, topTrailing: 0))
        case .notch:
            let top = min(topCornerRadius, rect.width / 4, rect.height / 2)
            let bottom = min(bottomCornerRadius, (rect.width - 2 * top) / 2, max(0, rect.height - top))
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top), control: CGPoint(x: rect.minX + top, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
            p.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY), control: CGPoint(x: rect.minX + top, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom), control: CGPoint(x: rect.maxX - top, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - top, y: rect.minY))
            p.closeSubpath()
            return p
        }
    }
}
