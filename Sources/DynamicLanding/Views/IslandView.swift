// DynamicLanding — IslandView.swift
import SwiftUI

/// Draws the island from the model's layout. Every container is top-aligned and the shape's
/// frame comes from the geometry, so growth is always downward from the top edge and
/// symmetric about the centre — on any screen.
struct IslandView: View {
    @Bindable var model: IslandModel

    var body: some View {
        let layout = model.layout
        let config = model.configuration
        ZStack(alignment: .top) {
            IslandShape(look: layout.look, topCornerRadius: layout.topCornerRadius, bottomCornerRadius: layout.bottomCornerRadius)
                .fill(backgroundStyle(config.background))
                .overlay(hoverHighlight(config))
                .shadow(color: shadowColor(config.shadow), radius: shadowRadius(config.shadow))
                .frame(width: layout.rect.width, height: layout.rect.height, alignment: .top)
                .contentShape(IslandShape(look: layout.look, topCornerRadius: layout.topCornerRadius, bottomCornerRadius: layout.bottomCornerRadius))
                .onTapGesture { model.onTap?() }

            content(layout: layout)
                .frame(width: layout.rect.width, height: layout.rect.height, alignment: .topLeading)
                .clipped()
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(config.foreground)
        .animation(config.animation, value: layout)
        .animation(config.animation, value: model.isHovering)
        // Measure the content where it is laid out at its natural size; the shape follows.
        .background(measurers)
    }

    @ViewBuilder
    private func content(layout: IslandLayout) -> some View {
        ZStack(alignment: .topLeading) {
            if model.state == .compact, let l = layout.leadingSlot, let t = layout.trailingSlot {
                model.compactLeading.frame(width: l.width, height: l.height).offset(x: l.minX, y: l.minY)
                model.compactTrailing.frame(width: t.width, height: t.height).offset(x: t.minX, y: t.minY)
            }
            if model.state == .expanded, let c = layout.contentRect {
                model.expandedContent.frame(width: c.width, height: c.height, alignment: .topLeading).offset(x: c.minX, y: c.minY)
            }
        }
        .id(model.contentGeneration)
        .transition(.opacity)
    }

    /// Hidden copies at natural size, measured so the geometry knows the content's size before
    /// the visible copy is constrained to it.
    private var measurers: some View {
        ZStack(alignment: .topLeading) {
            model.compactLeading.fixedSize().readSize { model.leadingSize = $0 }
            model.compactTrailing.fixedSize().readSize { model.trailingSize = $0 }
            model.expandedContent.fixedSize().readSize { model.contentSize = $0 }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func backgroundStyle(_ background: IslandBackground) -> AnyShapeStyle {
        switch background {
        case .black: AnyShapeStyle(Color.black)
        case .color(let color): AnyShapeStyle(color)
        case .material: AnyShapeStyle(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func hoverHighlight(_ config: IslandConfiguration) -> some View {
        if config.hoverBehavior.contains(.highlight), model.isHovering {
            IslandShape(look: model.layout.look, topCornerRadius: model.layout.topCornerRadius, bottomCornerRadius: model.layout.bottomCornerRadius)
                .fill(Color.white.opacity(0.08))
        }
    }

    private func shadowColor(_ shadow: IslandShadow) -> Color {
        if case .soft(_, let opacity) = shadow { return .black.opacity(opacity) }
        return .clear
    }

    private func shadowRadius(_ shadow: IslandShadow) -> CGFloat {
        if case .soft(let radius, _) = shadow { return radius }
        return 0
    }
}
