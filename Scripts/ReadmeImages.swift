// Documentation-only renderer. Compiled alongside the real library sources by
// generate-readme-images.sh, never included in the package's targets or products.
import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

private enum Theme: String, CaseIterable {
    case light, dark
    var isDark: Bool { self == .dark }
    var scheme: ColorScheme { isDark ? .dark : .light }
    var paper: Color { Color(hex: isDark ? 0x0D1117 : 0xF6F8FA) }
    var ink: Color { Color(hex: isDark ? 0xE6EDF3 : 0x182331) }
    var secondary: Color { Color(hex: isDark ? 0x99A8BA : 0x59697D) }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

// Deterministic, procedural wallpaper: no external assets, text, or trademarks.
private struct Wallpaper: View {
    let theme: Theme
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LinearGradient(colors: theme.isDark
                    ? [Color(hex: 0x132F45), Color(hex: 0x38475C), Color(hex: 0xA17D79)]
                    : [Color(hex: 0xBCDAD9), Color(hex: 0xD3DEE0), Color(hex: 0xF0D6C7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Path { p in
                    p.move(to: CGPoint(x: -w * 0.1, y: h * 0.88))
                    p.addCurve(to: CGPoint(x: w * 1.1, y: h * 0.18),
                               control1: CGPoint(x: w * 0.3, y: -h * 0.1),
                               control2: CGPoint(x: w * 0.68, y: h * 1.08))
                    p.addLine(to: CGPoint(x: w * 1.1, y: h))
                    p.addLine(to: CGPoint(x: -w * 0.1, y: h))
                    p.closeSubpath()
                }.fill(LinearGradient(colors: theme.isDark
                    ? [Color(hex: 0x41697A), Color(hex: 0x1D354F)]
                    : [Color(hex: 0x8AB8BF), Color(hex: 0x538799)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Path { p in
                    p.move(to: CGPoint(x: -w * 0.1, y: h * 0.65))
                    p.addCurve(to: CGPoint(x: w * 1.1, y: h * 0.85),
                               control1: CGPoint(x: w * 0.35, y: h * 1.25),
                               control2: CGPoint(x: w * 0.62, y: h * 0.1))
                    p.addLine(to: CGPoint(x: w * 1.1, y: h * 1.1))
                    p.addLine(to: CGPoint(x: -w * 0.1, y: h * 1.1))
                    p.closeSubpath()
                }.fill(LinearGradient(colors: theme.isDark
                    ? [Color(hex: 0x142D40), Color(hex: 0x2B5260)]
                    : [Color(hex: 0x467888), Color(hex: 0x96B7BC)],
                    startPoint: .leading, endPoint: .trailing))
            }
        }.clipped()
    }
}

private struct ListeningCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Color(hex: 0x79DDD1))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text("Listening…").font(.system(size: 17, weight: .semibold))
                Text("Click to stop").font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0x79DDD1)).frame(width: 10, height: 10)
        }
        .foregroundStyle(.white)
        .frame(width: 220, height: 48)
    }
}

@MainActor
private func measuredSize<V: View>(_ view: V) -> CGSize {
    let renderer = ImageRenderer(content: view.fixedSize())
    var size = CGSize.zero
    renderer.render { renderedSize, _ in size = renderedSize }
    precondition(size.width > 0 && size.height > 0, "Content measurement failed")
    return size
}

@MainActor
private func makeModel(_ state: IslandState, notched: Bool) -> IslandModel {
    let metrics = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        notchSize: notched ? CGSize(width: 185, height: 32) : nil,
        menuBarHeight: notched ? 32 : 24)
    let model = IslandModel(configuration: IslandConfiguration(), metrics: metrics)
    let leading = Image(systemName: "waveform")
        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0x79DDD1))
    let trailing = Text("0:12").font(.system(size: 12, weight: .medium)).monospacedDigit()
    let card = ListeningCard()
    model.setCompact(leading: AnyView(leading), trailing: AnyView(trailing))
    model.setExpanded(AnyView(card))
    // ImageRenderer does not run a window's layout cycle. Seed the exact measured
    // content sizes that IslandView's SizeReader would normally report on screen.
    model.leadingSize = measuredSize(leading)
    model.trailingSize = measuredSize(trailing)
    model.contentSize = measuredSize(card)
    model.setState(state)
    precondition(model.layout.rect.maxY == metrics.frame.maxY)
    precondition(model.layout.rect.midX == metrics.frame.midX)
    return model
}

private struct MenuBar: View {
    let theme: Theme
    let height: CGFloat
    let full: Bool
    var body: some View {
        HStack(spacing: 19) {
            if full {
                Text("Finder").fontWeight(.semibold)
                Text("File")
                Text("Edit")
                Text("View")
            }
            Spacer()
            if full {
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
                Text("Mon 9:41")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(theme.isDark ? .white.opacity(0.88) : Color(hex: 0x233D47))
        .padding(.horizontal, 22)
        .frame(height: height)
        .background(theme.isDark ? Color.black.opacity(0.18) : Color.white.opacity(0.34))
    }
}

@MainActor
private struct ScreenStrip: View {
    let model: IslandModel
    let theme: Theme
    let width: CGFloat
    let height: CGFloat
    var fullMenu = false

    var body: some View {
        // A centre crop of a synthetic 1512 pt display, at native point size.
        // Only the surrounding presentation is drawn here. The complete island,
        // including its hidden notch silhouette, is the unmodified IslandView.
        ZStack(alignment: .top) {
            Wallpaper(theme: theme)
                .frame(width: 1512, height: 280)
            MenuBar(theme: theme, height: model.metrics.menuBarHeight, full: fullMenu)
                .frame(width: width)
            IslandView(model: model)
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
                .environment(\.colorScheme, .dark)
        }
        .frame(width: width, height: height, alignment: .top)
        .clipped()
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
        // The 5 pt bezel is outside the screen. Island and screen share y = 0.
        .padding(.top, 5)
        .padding(.horizontal, 5)
        .background(UnevenRoundedRectangle(topLeadingRadius: 17, topTrailingRadius: 17)
            .fill(Color(hex: 0x20252B)))
    }
}

@MainActor
private struct Hero: View {
    let theme: Theme
    private let model = makeModel(.expanded, notched: true)
    var body: some View {
        ScreenStrip(model: model, theme: theme,
                    width: 1046, height: 240, fullMenu: true)
            .padding(24)
            .background(theme.paper)
    }
}

@MainActor
private struct States: View {
    let theme: Theme
    private let hidden = makeModel(.hidden, notched: true)
    private let compact = makeModel(.compact, notched: true)
    private let expanded = makeModel(.expanded, notched: true)
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            state(hidden, name: "Hidden", caption: "Just the notch.")
            state(compact, name: "Compact", caption: "A glanceable status.")
            state(expanded, name: "Expanded", caption: "Room for your SwiftUI content.")
        }
        .padding(24)
        .background(theme.paper)
    }

    private func state(_ model: IslandModel, name: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name).font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
                .padding(.bottom, 14)
            ScreenStrip(model: model, theme: theme, width: 330, height: 140)
            Text(caption).font(.system(size: 12)).foregroundStyle(theme.secondary).padding(.top, 12)
        }
    }
}

@MainActor
private struct Comparison: View {
    let theme: Theme
    private let notchedCompact = makeModel(.compact, notched: true)
    private let notchedExpanded = makeModel(.expanded, notched: true)
    private let notchlessCompact = makeModel(.compact, notched: false)
    private let notchlessExpanded = makeModel(.expanded, notched: false)
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            column(notched: true, title: "MacBook", subtitle: "Grows from the notch")
            column(notched: false, title: "External display", subtitle: "A pill from the top edge")
        }
        .padding(24)
        .background(theme.paper)
    }

    private func column(notched: Bool, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
            Text(subtitle).font(.system(size: 12)).foregroundStyle(theme.secondary)
                .padding(.top, 4).padding(.bottom, 20)
            Text("COMPACT").font(.system(size: 10, weight: .semibold)).tracking(1.3)
                .foregroundStyle(theme.secondary).padding(.bottom, 9)
            ScreenStrip(model: notched ? notchedCompact : notchlessCompact,
                        theme: theme, width: 506, height: 88)
            Text("EXPANDED").font(.system(size: 10, weight: .semibold)).tracking(1.3)
                .foregroundStyle(theme.secondary).padding(.top, 20).padding(.bottom, 9)
            ScreenStrip(model: notched ? notchedExpanded : notchlessExpanded,
                        theme: theme, width: 506, height: 144)
        }
    }
}

@main
private enum ReadmeImages {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Docs/Images", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for theme in Theme.allCases {
            try write(Hero(theme: theme), theme: theme, name: "hero", to: destination)
            try write(States(theme: theme), theme: theme, name: "states", to: destination)
            try write(Comparison(theme: theme), theme: theme, name: "displays", to: destination)
        }
    }

    @MainActor
    private static func write<V: View>(_ view: V, theme: Theme, name: String, to directory: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, theme.scheme).fixedSize())
        renderer.scale = 2
        renderer.isOpaque = true
        renderer.colorMode = .nonLinear
        guard let image = renderer.cgImage else { throw Failure.render(name) }
        let url = directory.appendingPathComponent("\(name)-\(theme.rawValue).png")
        guard let encoder = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw Failure.render(name) }
        CGImageDestinationAddImage(encoder, image, nil)
        guard CGImageDestinationFinalize(encoder) else { throw Failure.render(name) }
        let bytes = try Data(contentsOf: url).count
        guard bytes < 1_000_000 else { throw Failure.tooLarge(url.lastPathComponent, bytes) }
        print("\(url.lastPathComponent): \(image.width) × \(image.height) px, \(bytes) bytes")
    }

    private enum Failure: Error {
        case render(String)
        case tooLarge(String, Int)
    }
}
