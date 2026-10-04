// DynamicLanding — IslandView.swift
import SwiftUI

/// Draws the island from the model's layout. Every container is top-aligned and the shape's
/// frame comes from the geometry, so growth is always downward from the top edge and
/// symmetric about the centre — on any screen.
struct IslandView: View {
    let model: IslandModel

    var body: some View {
        let layout = model.layout
        let config = model.configuration
        let shape = IslandShape(look: layout.look, topCornerRadius: layout.topCornerRadius, bottomCornerRadius: layout.bottomCornerRadius)
        ZStack(alignment: .top) {
            shape
                .fill(backgroundStyle(config.background))
                .overlay(hoverHighlight(config, layout: layout))
                .islandShadow(config.shadow)
                .frame(width: layout.rect.width, height: layout.rect.height, alignment: .top)

            content(layout: layout)
                .frame(width: layout.rect.width, height: layout.rect.height, alignment: .topLeading)
                .clipped()
        }
        // The whole island is the tap target: buttons in the content take precedence, a tap
        // anywhere else inside the shape fires `onTap`, and outside the shape nothing is hit.
        .frame(width: layout.rect.width, height: layout.rect.height, alignment: .top)
        .contentShape(shape)
        .onTapGesture { model.onTap?() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(config.foreground)
        .animation(config.animation, value: layout)
        .animation(config.animation, value: model.isHovering)
    }

    /// The visible content, each piece laid out at its natural size and measured where it
    /// stands; the geometry then sizes the island (and the slot frames) from those sizes.
    @ViewBuilder
    private func content(layout: IslandLayout) -> some View {
        ZStack(alignment: .topLeading) {
            if model.state == .compact, let l = layout.leadingSlot, let t = layout.trailingSlot {
                model.compactLeading
                    .fixedSize().readSize { model.leadingSize = $0 }
                    .frame(width: l.width, height: l.height, alignment: .center)
                    .clipped()
                    .offset(x: l.minX, y: l.minY)
                model.compactTrailing
                    .fixedSize().readSize { model.trailingSize = $0 }
                    .frame(width: t.width, height: t.height, alignment: .center)
                    .clipped()
                    .offset(x: t.minX, y: t.minY)
            }
            if model.state == .expanded, let c = layout.contentRect {
                model.expandedContent
                    .fixedSize().readSize { model.contentSize = $0 }
                    .frame(width: c.width, height: c.height, alignment: .topLeading)
                    .clipped()
                    .offset(x: c.minX, y: c.minY)
            }
        }
        .id(model.contentGeneration)
        .transition(.opacity)
    }

    private func backgroundStyle(_ background: IslandBackground) -> AnyShapeStyle {
        switch background {
        case .black: AnyShapeStyle(Color.black)
        case .color(let color): AnyShapeStyle(color)
        case .material: AnyShapeStyle(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func hoverHighlight(_ config: IslandConfiguration, layout: IslandLayout) -> some View {
        if config.hoverBehavior.contains(.highlight), model.isHovering {
            IslandShape(look: layout.look, topCornerRadius: layout.topCornerRadius, bottomCornerRadius: layout.bottomCornerRadius)
                .fill(Color.white.opacity(0.08))
        }
    }
}

private extension View {
    /// A shadow only when one is configured, so the default island pays nothing for it.
    @ViewBuilder
    func islandShadow(_ shadow: IslandShadow) -> some View {
        switch shadow {
        case .none: self
        case .soft(let radius, let opacity): self.shadow(color: .black.opacity(opacity), radius: radius)
        }
    }
}
