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
        // The island is drawn `slide` taller than it shows and shifted up by as much, so while
        // it is on its way in or out of the notch its lower part slides through a window of
        // the shown height: the width never changes and the shape never re-fits.
        let drawn = layout.rect.height + layout.slide
        ZStack(alignment: .top) {
            shape
                .fill(backgroundStyle(config.background))
                .overlay(hoverHighlight(config, layout: layout))
                .islandShadow(config.shadow)
                .frame(width: layout.rect.width, height: drawn, alignment: .top)
                .offset(y: -layout.slide)

            // Clipped to the island's own shape, not its bounding rectangle: while the island
            // grows, new content is laid out for its final size at once, and the parts that fall
            // in the flares or the rounded corners would otherwise show outside the black.
            content(layout: layout)
                .frame(width: layout.rect.width, height: drawn, alignment: .top)
                .clipShape(shape)
                .offset(y: -layout.slide)
        }
        // The whole island is the tap target: buttons in the content take precedence, a tap
        // anywhere else inside the island fires `onTap`.
        .frame(width: layout.rect.width, height: layout.rect.height, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { model.onTap?() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(config.foreground)
        .animation(config.animation, value: layout)
        .animation(config.animation, value: model.isHovering)
    }

    /// The visible content, each piece laid out at its natural size and measured where it
    /// stands; the geometry then sizes the island (and the slot frames) from those sizes.
    /// Every piece stays in the tree in every state and fades in or out where it belongs. A view
    /// removed with a transition is drawn outside its parent's clip for a frame on its way out,
    /// which showed the content beside a closing island.
    ///
    /// Every piece keeps its natural size and is placed by its centre relative to the island's
    /// centre, which the island never moves: while the island grows, shrinks or changes shape,
    /// content stays exactly where and as big as it is when shown, and only the island's shape
    /// (the caller's `clipShape`) covers or reveals it. Pieces are not clipped to their own
    /// frames: those frames animate when the content changes, and clipping to them cut new
    /// content to the old one's size mid-animation, which read as text being squeezed.
    @ViewBuilder
    private func content(layout: IslandLayout) -> some View {
        let centre = layout.rect.width / 2
        ZStack(alignment: .top) {
            if let l = layout.leadingSlot, let t = layout.trailingSlot {
                model.compactLeading
                    .fixedSize().readSize { model.leadingSize = $0 }
                    .id(model.contentEpoch)
                    .frame(width: l.width, height: l.height, alignment: .center)
                    .offset(x: l.midX - centre, y: l.minY)
                    .opacity(model.state == .compact ? 1 : 0)
                model.compactTrailing
                    .fixedSize().readSize { model.trailingSize = $0 }
                    .id(model.contentEpoch)
                    .frame(width: t.width, height: t.height, alignment: .center)
                    .offset(x: t.midX - centre, y: t.minY)
                    .opacity(model.state == .compact ? 1 : 0)
            }
            if let c = layout.contentRect {
                model.expandedContent
                    .fixedSize().readSize { model.contentSize = $0 }
                    .id(model.contentEpoch)
                    .frame(width: c.width, height: c.height, alignment: .top)
                    .offset(x: c.midX - centre, y: c.minY)
                    .opacity(model.state == .expanded ? 1 : 0)
            }
        }
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
