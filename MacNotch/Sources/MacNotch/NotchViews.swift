import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Notch outline: concave shoulders that curve out of the screen's top edge, straight sides
/// and rounded bottom corners. All four corners are circular arcs drawn as cubic curves.
/// With `closed` false the top edge is left open, so borders aren't drawn along the screen edge.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var closed = true

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let k: CGFloat = 0.5523 // Bezier handle length for a quarter circle.
        let tr = min(topRadius, rect.height / 2)
        let br = max(0, min(bottomRadius, rect.height - tr, rect.width / 2 - tr))
        let left = rect.minX + tr
        let right = rect.maxX - tr

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(to: CGPoint(x: left, y: rect.minY + tr),
                      control1: CGPoint(x: rect.minX + tr * k, y: rect.minY),
                      control2: CGPoint(x: left, y: rect.minY + tr * (1 - k)))
        path.addLine(to: CGPoint(x: left, y: rect.maxY - br))
        path.addCurve(to: CGPoint(x: left + br, y: rect.maxY),
                      control1: CGPoint(x: left, y: rect.maxY - br * (1 - k)),
                      control2: CGPoint(x: left + br * (1 - k), y: rect.maxY))
        path.addLine(to: CGPoint(x: right - br, y: rect.maxY))
        path.addCurve(to: CGPoint(x: right, y: rect.maxY - br),
                      control1: CGPoint(x: right - br * (1 - k), y: rect.maxY),
                      control2: CGPoint(x: right, y: rect.maxY - br * (1 - k)))
        path.addLine(to: CGPoint(x: right, y: rect.minY + tr))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                      control1: CGPoint(x: right, y: rect.minY + tr * (1 - k)),
                      control2: CGPoint(x: rect.maxX - tr * k, y: rect.minY))
        if closed { path.closeSubpath() }
        return path
    }
}

/// Sizing rules shared by the notch view and the click/hover hit-testing in NotchController.
struct NotchLayout {
    /// sRGB (0, 0, 0) at full opacity, the same as the unlit pixels around the camera notch.
    static let pureBlack = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)

    static let musicCardWidth: CGFloat = 300
    static let calendarCardWidth: CGFloat = 178
    static let infoCardWidth: CGFloat = 132
    static let sectionSpacing: CGFloat = 16
    static let expandedPadding: CGFloat = 18
    /// Every dashboard page has the same height, so switching pages only changes the width.
    static let dashboardHeight: CGFloat = 118
    static let pageWidths: [DashboardTab: CGFloat] = [
        .shelf: 560, .clipboard: 640, .actions: 620, .system: 700, .notifications: 520,
    ]

    let geometry: NotchGeometry
    let settings: AppSettings
    let player: NowPlayingMonitor
    let battery: BatteryMonitor
    var tab: DashboardTab = .home

    var topRadius: CGFloat { CGFloat(settings.theme.shoulderRadius) }
    var page: DashboardTab { settings.isTabEnabled(tab) ? tab : .home }

    var trimmedText: String { settings.customText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasText: Bool { settings.showCustomText && !trimmedText.isEmpty }

    var barsVisible: Bool { settings.showMusic && player.isPlaying }

    var chargingIndicatorVisible: Bool {
        settings.chargingIndicator && battery.hasBattery && battery.isPluggedIn
    }

    /// The meeting to count down to beside the notch: one starting within 15 minutes, or under way.
    var soonEvent: CalendarMonitor.Event? {
        guard settings.eventCountdown, settings.showCalendar, let event = CalendarMonitor.shared.nextEvent else { return nil }
        return event.start.timeIntervalSinceNow < 15 * 60 ? event : nil
    }

    var privacyVisible: Bool {
        settings.privacyIndicators && (PrivacyMonitor.shared.cameraInUse || PrivacyMonitor.shared.microphoneInUse)
    }

    var hasStatus: Bool {
        FocusTimer.shared.state != .idle || soonEvent != nil || !TransferMonitor.shared.active.isEmpty || chargingIndicatorVisible
    }

    /// Without a camera notch the middle of the pill is visible, so the custom text goes there.
    var textInCenter: Bool { !geometry.hasHardwareNotch }

    /// Both wings share one width so the middle stays exactly over the camera notch.
    var wingWidth: CGFloat {
        let left = barsVisible
        let right = settings.showTime || (hasText && !textInCenter) || hasStatus || privacyVisible
        return (left || right) ? CGFloat(settings.wingWidth) : 0
    }

    // MARK: Expanded

    var showsInfoCard: Bool {
        settings.showTime || settings.showDate || hasText || !settings.worldClocks.isEmpty
    }

    var homeWidth: CGFloat {
        var widths: [CGFloat] = []
        if settings.showMusic { widths.append(Self.musicCardWidth) }
        if settings.showCalendar { widths.append(Self.calendarCardWidth) }
        if showsInfoCard || widths.isEmpty { widths.append(Self.infoCardWidth) }
        return widths.reduce(0, +) + CGFloat(widths.count - 1) * (Self.sectionSpacing * 2 + 1)
    }

    var expandedWidth: CGFloat {
        let content = page == .home ? homeWidth : Self.pageWidths[page] ?? 500
        return min(max(content + 2 * Self.expandedPadding, geometry.notchWidth + 2 * CGFloat(settings.wingWidth), 520),
                   NotchController.canvasSize.width - 2 * topRadius - 20)
    }

    /// Outer size of the shape when collapsed.
    var collapsedSize: CGSize {
        CGSize(width: geometry.notchWidth + 2 * wingWidth + 2 * topRadius, height: geometry.notchHeight)
    }

    /// Lower bound for the expanded shape, used until the real size has been measured.
    var minimumExpandedSize: CGSize {
        CGSize(width: expandedWidth + 2 * topRadius, height: geometry.notchHeight + 8 + Self.dashboardHeight + 14)
    }
}

struct NotchContentView: View {
    let geometry: NotchGeometry
    let expanded: Bool
    var charging: ChargingActivity? = nil
    /// The main window's preview blurs the window's own content instead of the desktop.
    var inPreview = false

    @EnvironmentObject private var model: NotchModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var player: NowPlayingMonitor
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var focus: FocusTimer
    @EnvironmentObject private var privacy: PrivacyMonitor
    @EnvironmentObject private var transfers: TransferMonitor
    @EnvironmentObject private var hub: NotificationHub

    private var layout: NotchLayout {
        NotchLayout(geometry: geometry, settings: settings, player: player, battery: battery, tab: model.tab)
    }
    private var topRadius: CGFloat { layout.topRadius }
    private var height: CGFloat { geometry.notchHeight }
    private var wingWidth: CGFloat { layout.wingWidth }

    private var bottomRadius: CGFloat {
        if charging != nil || model.banner != nil { return 16 }
        return CGFloat(expanded ? settings.theme.expandedRadius : settings.theme.collapsedRadius)
    }

    private var raised: Bool { expanded || model.banner != nil || charging != nil }

    var body: some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
        let theme = settings.theme
        ZStack(alignment: .top) {
            if let charging {
                ChargingView(geometry: geometry, activity: charging)
                    .transition(.opacity)
            } else if let banner = model.banner {
                BannerView(geometry: geometry, banner: banner)
                    .transition(settings.animateBanners ? .opacity.combined(with: .scale(scale: 0.92, anchor: .top)) : .opacity)
            } else if expanded {
                expandedLayout.transition(.opacity)
            } else {
                collapsedLayout.transition(.opacity)
            }
        }
        .padding(.horizontal, topRadius)
        .background(NotchBackground(style: settings.notchStyle, animation: settings.backgroundAnimation, inPreview: inPreview))
        .clipShape(shape)
        .overlay(NotchBorder(shape: NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, closed: false),
                             theme: theme, chargingGlow: charging != nil && settings.chargingGlow))
        .shadow(color: .black.opacity(theme.shadow && raised ? 0.55 : 0), radius: CGFloat(theme.shadowRadius), y: 6)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: expanded)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: charging)
        .animation(settings.animateBanners ? .spring(response: 0.42, dampingFraction: 0.74) : .easeInOut(duration: 0.15),
                   value: model.banner)
        .animation(settings.animateTabs ? .spring(response: 0.36, dampingFraction: 0.86) : nil, value: model.tab)
        .animation(.easeInOut(duration: 0.25), value: wingWidth)
    }

    // MARK: Collapsed

    private var collapsedLayout: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if layout.barsVisible, let art = player.artwork {
                    artworkView(art, size: height - 10)
                }
                if layout.barsVisible {
                    MusicBars(playing: true)
                        .frame(width: 20, height: height * 0.45)
                }
            }
            .padding(.leading, 8)
            .frame(width: wingWidth, height: height, alignment: .leading)
            .clipped()

            ZStack {
                if layout.textInCenter && layout.hasText {
                    Text(layout.trimmedText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                }
            }
            .frame(width: geometry.notchWidth, height: height)

            HStack(spacing: 6) {
                if layout.privacyVisible {
                    PrivacyDots()
                }
                statusChip
                if layout.hasText && !layout.textInCenter {
                    Text(layout.trimmedText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                if settings.showTime && !layout.hasStatus {
                    ClockText(fontSize: 13, compact: true)
                        .layoutPriority(1)
                }
            }
            .padding(.trailing, 8)
            .frame(width: wingWidth, height: height, alignment: .trailing)
            .clipped()
        }
        .frame(height: height)
    }

    /// The single most useful status beside the notch: focus timer, next meeting, download or charge.
    @ViewBuilder private var statusChip: some View {
        if focus.state != .idle {
            TimelineView(.periodic(from: Date(), by: 1)) { context in
                HStack(spacing: 4) {
                    FocusRing(progress: focus.progress(at: context.date), color: FocusPanel.color(for: focus.mode), lineWidth: 2.2)
                        .frame(width: 12, height: 12)
                    Text(TimeText.clock(focus.remaining(at: context.date)))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(focus.state == .paused ? .white.opacity(0.5) : .white)
                }
            }
            .fixedSize()
            .layoutPriority(2)
        } else if let event = layout.soonEvent {
            TimelineView(.everyMinute) { context in
                HStack(spacing: 4) {
                    Circle().fill(Color(nsColor: event.color)).frame(width: 6, height: 6)
                    Text(event.start > context.date ? TimeText.duration(event.start.timeIntervalSince(context.date)) : "Now")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .fixedSize()
            .layoutPriority(2)
        } else if let download = transfers.active.first {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentBlue)
                Text(download.speed > 0 ? ByteFormat.speed(download.speed) : ByteFormat.size(download.bytes))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .fixedSize()
            .layoutPriority(2)
        } else if layout.chargingIndicatorVisible {
            HStack(spacing: 2) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("\(battery.level)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(ChargingView.green)
            .fixedSize()
            .layoutPriority(2)
        }
    }

    // MARK: Expanded

    private var expandedLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            topBar
            ZStack(alignment: .topLeading) {
                page
                    .id(layout.page)
                    .transition(settings.animateTabs ? .opacity.combined(with: .offset(y: 6)) : .identity)
            }
            .frame(height: NotchLayout.dashboardHeight, alignment: .top)
        }
        .padding(.horizontal, NotchLayout.expandedPadding)
        .padding(.bottom, 14)
        .frame(width: layout.expandedWidth, alignment: .leading)
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { model.dropTargeted }, set: { model.dropTargeted = $0 })) { providers in
            guard settings.isTabEnabled(.shelf) else { return false }
            FileDrop.load(providers) { urls in
                ShelfStore.shared.add(urls)
                model.tab = .shelf
            }
            return true
        }
    }

    private var topBar: some View {
        HStack(spacing: 2) {
            ForEach(DashboardTab.allCases.filter(settings.isTabEnabled)) { tab in
                Button {
                    model.tab = tab
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(layout.page == tab ? .white : .white.opacity(0.45))
                        .frame(width: 24, height: 22)
                        .background(Capsule().fill(Color.white.opacity(layout.page == tab ? 0.16 : 0)))
                        .overlay(alignment: .topTrailing) {
                            if tab == .notifications && hub.total > 0 {
                                Circle().fill(Color.red).frame(width: 6, height: 6).offset(x: -3, y: 3)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
            Spacer()
            if layout.privacyVisible {
                PrivacyDots().padding(.trailing, 6)
            }
            Button {
                (NSApp.delegate as? AppDelegate)?.showMainWindow()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open MacNotch settings")
        }
        .frame(height: height)
    }

    @ViewBuilder private var page: some View {
        switch layout.page {
        case .home: homePage
        case .shelf: ShelfPage()
        case .clipboard: ClipboardPage()
        case .actions: ActionsPage()
        case .system: SystemPage()
        case .notifications: NotificationsPage()
        }
    }

    private var homePage: some View {
        HStack(alignment: .top, spacing: NotchLayout.sectionSpacing) {
            ForEach(Array(homeSections.enumerated()), id: \.element) { index, section in
                if index > 0 { SectionDivider() }
                switch section {
                case .music: MusicCard().frame(width: NotchLayout.musicCardWidth, alignment: .leading)
                case .calendar: CalendarCard().frame(width: NotchLayout.calendarCardWidth, alignment: .leading)
                case .info: ClockCard().frame(width: NotchLayout.infoCardWidth, alignment: .leading)
                }
            }
        }
    }

    private enum HomeSection: Hashable { case music, calendar, info }

    private var homeSections: [HomeSection] {
        var sections: [HomeSection] = []
        if settings.showMusic { sections.append(.music) }
        if settings.showCalendar { sections.append(.calendar) }
        if layout.showsInfoCard || sections.isEmpty { sections.append(.info) }
        return sections
    }

    private func artworkView(_ image: NSImage, size: CGFloat) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 84)
            .padding(.top, 8)
    }
}

/// Green dot while the camera is on, orange while a microphone is recording.
struct PrivacyDots: View {
    @EnvironmentObject private var privacy: PrivacyMonitor

    var body: some View {
        HStack(spacing: 3) {
            if privacy.cameraInUse { dot(.green).help("The camera is in use") }
            if privacy.microphoneInUse { dot(.orange).help("A microphone is in use") }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.8), radius: 3)
    }
}

/// Theme border: a glass rim or a neon glow, plus a green glow while charging.
struct NotchBorder: View {
    let shape: NotchShape
    let theme: ThemeOptions
    let chargingGlow: Bool

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var player: NowPlayingMonitor

    var body: some View {
        ZStack {
            switch theme.border {
            case .none:
                EmptyView()
            case .hairline:
                shape.stroke(LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0.34)],
                                            startPoint: .top, endPoint: .bottom),
                             lineWidth: 1)
            case .neon:
                NeonStroke(shape: shape, color: neonColor, pulse: settings.neonPulse)
            }
            if chargingGlow {
                NeonStroke(shape: shape, color: ChargingView.green, pulse: true)
            }
        }
        .allowsHitTesting(false)
    }

    private var neonColor: Color {
        if theme.neonFollowsAlbum, let color = player.artworkColors.first { return Color(nsColor: color) }
        return Color(hex: theme.neonColor)
    }
}

struct NeonStroke: View {
    let shape: NotchShape
    let color: Color
    let pulse: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !pulse)) { context in
            let glow = pulse ? 0.6 + 0.4 * sin(context.date.timeIntervalSinceReferenceDate * 2.4) : 1
            shape.stroke(color, lineWidth: 1.6)
                .shadow(color: color.opacity(glow), radius: 4)
                .shadow(color: color.opacity(glow * 0.7), radius: 11)
        }
    }
}

enum FileDrop {
    static func load(_ providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { if !urls.isEmpty { completion(urls) } }
    }
}

// MARK: - Pieces

struct ClockText: View {
    let fontSize: CGFloat
    let compact: Bool
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: Date()), by: 1)) { context in
            Text(Self.format(context.date, use24Hour: settings.use24Hour, seconds: settings.showSeconds, compact: compact))
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        }
    }

    static func format(_ date: Date, use24Hour: Bool, seconds: Bool, compact: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let base = use24Hour ? "HH:mm" : "h:mm"
        let withSeconds = seconds ? base + ":ss" : base
        formatter.dateFormat = (use24Hour || compact) ? withSeconds : withSeconds + " a"
        return formatter.string(from: date)
    }
}

struct DateText: View {
    var fontSize: CGFloat = 13

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(settings.dateStyle.format(context.date, custom: settings.customDateFormat))
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
    }
}

/// Equaliser bars. They follow the real music when the system audio tap is running,
/// and fall back to a smooth built-in animation otherwise.
struct MusicBars: View {
    let playing: Bool

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var spectrum: AudioSpectrum
    @EnvironmentObject private var player: NowPlayingMonitor

    private var color: Color {
        if settings.matchAlbumArt, let first = player.artworkColors.first { return Color(nsColor: first) }
        return Color(red: 0.35, green: 0.95, blue: 0.55)
    }

    var body: some View {
        GeometryReader { proxy in
            if spectrum.isLive && playing && settings.animateMusicBars {
                bars(proxy.size) { index in Double(spectrum.levels[index % spectrum.levels.count]) }
                    .animation(.linear(duration: 0.06), value: spectrum.levels)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !playing || !settings.animateMusicBars)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    bars(proxy.size) { index in
                        settings.animateMusicBars ? abs(sin(t * (2.6 + Double(index) * 0.7) + Double(index) * 1.3)) : 0.5
                    }
                }
            }
        }
    }

    private func bars(_ size: CGSize, level: @escaping (Int) -> Double) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<AudioSpectrum.bandCount, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(height: playing ? max(3, size.height * (0.2 + 0.8 * level(index))) : 3)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
