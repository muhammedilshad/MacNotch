import AppKit
import SwiftUI

/// Fill behind the notch content: deep black or one of the glass styles, plus an optional animation.
struct NotchBackground: View {
    let style: NotchStyle
    let animation: BackgroundAnimation
    var inPreview = false

    @EnvironmentObject private var player: NowPlayingMonitor
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            switch style {
            case .black:
                NotchLayout.pureBlack
            case .frosted:
                VisualEffectBlur(material: .hudWindow, inPreview: inPreview)
                // Milky white haze over a dark base keeps white text readable.
                Color.white.opacity(0.13)
            case .clear:
                ClearGlass(inPreview: inPreview)
                Color.black.opacity(0.12)
            case .blur:
                VisualEffectBlur(material: .fullScreenUI, inPreview: inPreview)
                Color.black.opacity(0.4)
            case .image:
                NotchLayout.pureBlack
                if let url = settings.backgroundImageURL {
                    BackgroundPicture(url: url, blur: settings.backgroundImageBlur)
                    Color.black.opacity(settings.backgroundImageDim)
                }
            }
            if settings.matchAlbumArt, player.track != nil, !player.artworkColors.isEmpty {
                // Washes the notch in the artwork's colours, darkened so text stays readable.
                LinearGradient(colors: player.artworkColors.map { Color(nsColor: $0) },
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.55)
                    .overlay(Color.black.opacity(0.25))
                    .animation(.easeInOut(duration: 0.8), value: player.artworkColors)
            }
            if animation != .none {
                AnimatedBackdrop(kind: animation, artwork: player.artwork)
                    .opacity(style == .black ? 0.7 : 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The user's picture, loaded once per file.
private struct BackgroundPicture: View {
    let url: URL
    let blur: Double

    private static var cache: (url: URL, image: NSImage)?

    var body: some View {
        if let image = Self.image(for: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: blur)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }

    private static func image(for url: URL) -> NSImage? {
        if let cache, cache.url == url { return cache.image }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache = (url, image)
        return image
    }
}

/// NSVisualEffectView. In the notch it blurs whatever is behind the window; in the main window's
/// preview it blurs the preview's own wallpaper instead.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var inPreview = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = inPreview ? .withinWindow : .behindWindow
    }
}

/// See-through glass: Liquid Glass on macOS 26 and later, a light blur on older versions.
struct ClearGlass: View {
    var inPreview = false

    var body: some View {
        if #available(macOS 26.0, *) {
            LiquidGlass()
        } else {
            VisualEffectBlur(material: .underWindowBackground, inPreview: inPreview)
                .opacity(0.75)
        }
    }
}

@available(macOS 26.0, *)
private struct LiquidGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .clear
        view.cornerRadius = 0
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {}
}

// MARK: - Animations

struct AnimatedBackdrop: View {
    let kind: BackgroundAnimation
    let artwork: NSImage?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            switch kind {
            case .none:
                Color.clear
            case .aurora:
                Aurora(time: t)
            case .albumGlow:
                if let artwork {
                    AlbumGlow(artwork: artwork, time: t)
                } else {
                    Aurora(time: t)
                }
            case .waves:
                Waves(time: t)
            }
        }
    }
}

/// Slow-moving blurred colour blobs.
private struct Aurora: View {
    let time: Double

    private static let colors: [Color] = [
        Color(red: 0.10, green: 0.85, blue: 0.75),
        Color(red: 0.55, green: 0.25, blue: 0.95),
        Color(red: 0.15, green: 0.45, blue: 1.00),
        Color(red: 0.95, green: 0.30, blue: 0.60),
    ]

    var body: some View {
        Canvas { context, size in
            context.addFilter(.blur(radius: max(14, size.height * 0.3)))
            for (index, color) in Self.colors.enumerated() {
                let i = Double(index)
                let x = size.width * (0.5 + 0.42 * sin(time * (0.21 + i * 0.07) + i * 1.7))
                let y = size.height * (0.5 + 0.38 * cos(time * (0.17 + i * 0.05) + i * 2.3))
                let r = max(size.width * 0.18, size.height * 0.5) * (1 + 0.15 * sin(time * 0.3 + i))
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: 2 * r, height: 1.2 * r)),
                             with: .color(color))
            }
        }
    }
}

/// The current song's artwork, hugely blurred and slowly turning, like Apple Music's lyrics view.
private struct AlbumGlow: View {
    let artwork: NSImage
    let time: Double

    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height) * 1.4
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: side, height: side)
                .rotationEffect(.degrees(time * 12))
                .blur(radius: 30)
                .saturation(1.5)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .clipped()
    }
}

/// Glowing sine waves drifting across the notch.
private struct Waves: View {
    let time: Double

    var body: some View {
        ZStack {
            WaveLines(time: time, lineWidth: 6).blur(radius: 8)
            WaveLines(time: time, lineWidth: 1.2)
        }
        .opacity(0.55)
    }
}

private struct WaveLines: View {
    let time: Double
    let lineWidth: CGFloat

    private static let colors: [Color] = [
        Color(red: 0.20, green: 0.95, blue: 0.70),
        Color(red: 0.30, green: 0.55, blue: 1.00),
        Color(red: 0.75, green: 0.35, blue: 1.00),
    ]

    var body: some View {
        Canvas { context, size in
            for (index, color) in Self.colors.enumerated() {
                let i = Double(index)
                var path = Path()
                let baseline = size.height * (0.55 + 0.12 * i)
                let amplitude = size.height * (0.10 + 0.04 * sin(time * 0.5 + i))
                let wavelength = size.width / (1.2 + 0.3 * i)
                for step in stride(from: 0.0, through: Double(size.width), by: 4) {
                    let y = baseline + amplitude * sin(step / wavelength * 2 * .pi + time * (0.9 + 0.25 * i) + i * 2)
                    if step == 0 { path.move(to: CGPoint(x: step, y: y)) } else { path.addLine(to: CGPoint(x: step, y: y)) }
                }
                context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: lineWidth)
            }
        }
    }
}
