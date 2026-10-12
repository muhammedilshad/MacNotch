import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Banner

/// Reminder, timer, battery and OCR messages: a title row beside the camera and a row of buttons below.
struct BannerView: View {
    let geometry: NotchGeometry
    let banner: NotchBanner

    private let wing: CGFloat = 175
    private var height: CGFloat { geometry.notchHeight }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    HStack(spacing: 7) {
                        Image(systemName: banner.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(banner.tint)
                            .shadow(color: banner.tint.opacity(0.8), radius: 4)
                        Text(banner.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 14)
                }
                .frame(width: wing, height: height, alignment: .leading)
                Color.clear.frame(width: geometry.notchWidth, height: height)
                ZStack {
                    if let trailing = banner.trailing {
                        Text(trailing)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(banner.tint)
                            .lineLimit(1)
                            .padding(.trailing, 14)
                    }
                }
                .frame(width: wing, height: height, alignment: .trailing)
            }

            if banner.subtitle != nil || !banner.actions.isEmpty {
                HStack(spacing: 8) {
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    ForEach(banner.actions) { action in
                        Button { NotchController.shared.perform(action) } label: {
                            Text(action.title)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(action.primary ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(action.primary ? banner.tint : Color.white.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 2 * wing + geometry.notchWidth)
    }
}

/// Small grey caption above each section of a page.
struct PageHeader<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
            if let detail {
                Text(detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Spacer(minLength: 0)
            trailing
        }
        .frame(height: 16)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, detail: String? = nil) {
        self.init(title: title, detail: detail) { EmptyView() }
    }
}

struct PillButton: View {
    let symbol: String
    var title: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                if let title { Text(title).font(.system(size: 10, weight: .semibold)) }
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shelf & transfers

struct ShelfPage: View {
    @EnvironmentObject private var shelf: ShelfStore
    @EnvironmentObject private var transfers: TransferMonitor
    @EnvironmentObject private var model: NotchModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(alignment: .top, spacing: NotchLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                PageHeader(title: "Shelf", detail: shelf.items.isEmpty ? nil : "\(shelf.items.count)") {
                    if !shelf.items.isEmpty {
                        PillButton(symbol: "dot.radiowaves.left.and.right", title: "AirDrop") {
                            shelf.airDrop(shelf.items.map(\.url))
                        }
                        PillButton(symbol: "trash") { shelf.clear() }
                    }
                }
                if shelf.items.isEmpty {
                    dropZone
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(shelf.items) { ShelfTile(item: $0) }
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentBlue, lineWidth: model.dropTargeted ? 2 : 0))
                }
            }
            .frame(width: 330)

            SectionDivider()

            VStack(alignment: .leading, spacing: 6) {
                PageHeader(title: "Transfers")
                if !settings.downloadsMonitor {
                    hint("Turn on download tracking in Settings")
                } else if transfers.active.isEmpty && transfers.recent.isEmpty {
                    hint("No downloads or AirDrops in the last 30 minutes")
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(transfers.active.prefix(3)) { TransferRow(transfer: $0) }
                        ForEach(transfers.recent.prefix(max(0, 3 - transfers.active.count))) { TransferRow(transfer: $0) }
                    }
                }
            }
            .frame(width: 180)
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .foregroundStyle(model.dropTargeted ? Color.accentBlue : .white.opacity(0.25))
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(model.dropTargeted ? Color.accentBlue.opacity(0.15) : .clear))
            .overlay(VStack(spacing: 4) {
                Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 18))
                Text("Drop files here to keep them handy").font(.system(size: 11, weight: .medium))
                Text("Drag them out again, or AirDrop them").font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .foregroundStyle(.white.opacity(0.7)))
            .frame(height: 90)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(.white.opacity(0.45))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShelfTile: View {
    let item: ShelfStore.Item

    @EnvironmentObject private var shelf: ShelfStore

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 44, height: 44)
            Text(item.url.lastPathComponent)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 26, alignment: .top)
        }
        .frame(width: 68, height: 86)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .help(item.url.path)
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("AirDrop") { shelf.airDrop([item.url]) }
            Menu("Share") {
                ForEach(ShelfStore.shareServices(for: [item.url]), id: \.title) { service in
                    Button(service.title) { shelf.share([item.url], with: service) }
                }
            }
            if TextRecognizer.isImage(item.url) {
                Button("Copy Text from Image") { NotchController.shared.recognizeText(in: item.url) }
            }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([item.url as NSURL])
            }
            Divider()
            Button("Remove from Shelf") { shelf.remove(item) }
        }
    }
}

struct TransferRow: View {
    let transfer: TransferMonitor.Transfer

    var body: some View {
        HStack(spacing: 7) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: transfer.url.path))
                .resizable()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.name)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if transfer.isActive {
                    IndeterminateBar().frame(height: 3)
                    Text("\(ByteFormat.size(transfer.bytes))\(transfer.speed > 0 ? " · " + ByteFormat.speed(transfer.speed) : "")")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text("Done · \(ByteFormat.size(transfer.bytes))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if transfer.isActive {
                NSWorkspace.shared.activateFileViewerSelecting([transfer.url])
            } else {
                NSWorkspace.shared.open(transfer.url)
            }
        }
        .onDrag { NSItemProvider(contentsOf: transfer.url) ?? NSItemProvider() }
    }
}

/// Moving highlight for transfers whose total size isn't known.
struct IndeterminateBar: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            GeometryReader { proxy in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(Color.accentBlue)
                        .frame(width: proxy.size.width * 0.35)
                        .offset(x: proxy.size.width * (phase * 1.35 - 0.35))
                }
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Clipboard

struct ClipboardPage: View {
    @EnvironmentObject private var clipboard: ClipboardMonitor
    @EnvironmentObject private var settings: AppSettings

    private var sortedItems: [ClipboardMonitor.Item] {
        clipboard.items.filter(\.pinned) + clipboard.items.filter { !$0.pinned }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PageHeader(title: "Clipboard", detail: clipboard.items.isEmpty ? nil : "\(clipboard.items.count) items · click to copy") {
                if !clipboard.items.isEmpty {
                    PillButton(symbol: "trash", title: "Clear") { clipboard.clear() }
                }
            }
            if !settings.clipboardEnabled {
                message("Clipboard history is off. Turn it on in Settings → Shelf & Clipboard.")
            } else if clipboard.items.isEmpty {
                message("Copy some text, a link, an image or a file and it shows up here. Passwords are never saved.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedItems) { ClipCard(item: $0) }
                    }
                }
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: 80)
    }
}

struct ClipCard: View {
    let item: ClipboardMonitor.Item

    @EnvironmentObject private var clipboard: ClipboardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                if let bundleID = item.sourceBundleID, let icon = AppInfo.lookup(bundleID)?.icon {
                    Image(nsImage: icon).resizable().frame(width: 13, height: 13)
                }
                Image(systemName: symbol)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 0)
                if item.pinned {
                    Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                }
                Text(Self.age(item.date))
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            content
        }
        .padding(8)
        .frame(width: 132, height: 92, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay {
            if clipboard.lastCopiedID == item.id {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .overlay(Label("Copied", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: clipboard.lastCopiedID)
        .contentShape(Rectangle())
        .onTapGesture { clipboard.copy(item) }
        .onDrag { dragProvider }
        .contextMenu {
            Button("Copy") { clipboard.copy(item) }
            Button(item.pinned ? "Unpin" : "Pin") { clipboard.togglePin(item) }
            if item.kind == .link, let url = item.text.flatMap(URL.init(string:)) {
                Button("Open Link") { NSWorkspace.shared.open(url) }
            }
            Divider()
            Button("Delete") { clipboard.remove(item) }
        }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text, .link:
            Text(item.title)
                .font(.system(size: 10.5, design: item.kind == .link ? .default : .rounded))
                .foregroundStyle(item.kind == .link ? Color.accentBlue : .white.opacity(0.9))
                .lineLimit(4)
        case .image:
            if let image = clipboard.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 116, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        case .file:
            HStack(spacing: 6) {
                if let path = item.filePaths?.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 30, height: 30)
                }
                Text(item.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
            }
        }
    }

    private var symbol: String {
        switch item.kind {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    private var dragProvider: NSItemProvider {
        switch item.kind {
        case .text, .link: return NSItemProvider(object: (item.text ?? "") as NSString)
        case .file: return item.filePaths?.first.flatMap { NSItemProvider(contentsOf: URL(fileURLWithPath: $0)) } ?? NSItemProvider()
        case .image: return clipboard.image(for: item).map { NSItemProvider(object: $0) } ?? NSItemProvider()
        }
    }

    static func age(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }
}

// MARK: - Focus & actions

struct ActionsPage: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(alignment: .top, spacing: NotchLayout.sectionSpacing) {
            FocusPanel().frame(width: 238, alignment: .leading)
            SectionDivider()
            VStack(alignment: .leading, spacing: 6) {
                PageHeader(title: "Quick actions") {
                    PillButton(symbol: "plus") { (NSApp.delegate as? AppDelegate)?.showMainWindow(pane: .actions) }
                }
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 6), count: 4), spacing: 6) {
                        QuickActionTile(title: "Copy Text", symbol: "text.viewfinder", icon: nil) {
                            NotchController.shared.captureScreenText()
                        }
                        .help("Select part of the screen and copy its text (\(HotKey.ocrDisplayString))")
                        ForEach(settings.quickActions) { action in
                            QuickActionTile(title: action.title, symbol: action.symbol, icon: QuickActionRunner.icon(for: action)) {
                                QuickActionRunner.run(action)
                            }
                            .help(action.target)
                        }
                    }
                }
            }
            .frame(width: 298)
        }
    }
}

struct QuickActionTile: View {
    let title: String
    let symbol: String
    let icon: NSImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let icon {
                    Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(height: 22)
                }
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 70, height: 44)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FocusPanel: View {
    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var settings: AppSettings

    static func color(for mode: FocusTimer.Mode) -> Color {
        mode == .focus ? .orange : .teal
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: settings.animateFocusRing ? 1.0 / 30.0 : 1, paused: timer.state != .running)) { context in
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    FocusRing(progress: timer.progress(at: context.date), color: Self.color(for: timer.mode), lineWidth: 6)
                    VStack(spacing: 0) {
                        Text(TimeText.clock(timer.remaining(at: context.date)))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text(timer.mode.title.uppercased())
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Self.color(for: timer.mode))
                    }
                }
                .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 7) {
                    Text(stateText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 6) {
                        roundButton(timer.state == .running ? "pause.fill" : "play.fill", filled: true) { timer.toggle() }
                        roundButton("arrow.counterclockwise") { timer.reset() }
                        roundButton("forward.end.fill") { timer.skip() }
                    }
                    HStack(spacing: 4) {
                        ForEach([15, 25, 50], id: \.self) { minutes in
                            Button {
                                settings.focusMinutes = minutes
                                if timer.mode == .focus && timer.state == .idle { timer.reset() }
                            } label: {
                                Text("\(minutes)m")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(settings.focusMinutes == minutes ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(settings.focusMinutes == minutes ? Color.orange : Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var stateText: String {
        let done = timer.completedSessions
        switch timer.state {
        case .idle: return done == 0 ? "Ready to focus" : "\(done) session\(done == 1 ? "" : "s") done"
        case .running: return timer.mode == .focus ? "Focusing…" : "On a break"
        case .paused: return "Paused"
        }
    }

    private func roundButton(_ symbol: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(filled ? .black : .white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(filled ? Self.color(for: timer.mode) : Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct FocusRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Developer dashboard

struct SystemPage: View {
    @EnvironmentObject private var system: SystemMonitor
    @EnvironmentObject private var battery: BatteryMonitor

    var body: some View {
        HStack(alignment: .top, spacing: NotchLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                PageHeader(title: "System")
                HStack(spacing: 10) {
                    MiniGauge(title: "CPU", value: system.cpu, text: "\(Int(system.cpu * 100))%", color: .accentBlue)
                    MiniGauge(title: "Memory", value: system.memoryFraction,
                          text: ByteFormat.compact(Int64(system.memoryUsed)), color: .purple)
                    MiniGauge(title: "Disk", value: system.diskUsedFraction,
                          text: ByteFormat.compact(system.diskFree) + " free", color: .pink)
                }
            }
            .frame(width: 168, alignment: .leading)

            SectionDivider()

            VStack(alignment: .leading, spacing: 5) {
                PageHeader(title: "Network")
                speedRow("arrow.down", system.downloadSpeed, .accentBlue)
                speedRow("arrow.up", system.uploadSpeed, .green)
                Sparkline(download: system.downloadHistory, upload: system.uploadHistory)
                    .frame(height: 26)
                Text(system.localAddress.map { "IP \($0)" } ?? "Offline")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(width: 140, alignment: .leading)

            SectionDivider()

            VStack(alignment: .leading, spacing: 4) {
                PageHeader(title: "Dev servers")
                if system.devServers.isEmpty {
                    Text("No local servers listening")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(system.devServers) { server in
                                Button { system.open(server) } label: {
                                    HStack(spacing: 5) {
                                        Circle().fill(Color.green).frame(width: 5, height: 5)
                                        Text(":" + String(server.port))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                        Text(server.process)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Open http://localhost:" + String(server.port))
                                .contextMenu {
                                    Button("Open in Browser") { system.open(server) }
                                    Button("Copy URL") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString("http://localhost:" + String(server.port), forType: .string)
                                    }
                                    Divider()
                                    Button("Stop \(server.process) (PID \(server.pid))") { system.stop(server) }
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 140, alignment: .leading)

            SectionDivider()

            BatteryDetails().frame(width: 130, alignment: .leading)
        }
        .onAppear { system.addClient() }
        .onDisappear { system.removeClient() }
    }

    private func speedRow(_ symbol: String, _ speed: Double, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 9, weight: .heavy)).foregroundStyle(color)
            Text(ByteFormat.speed(speed))
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

/// Smart charging: level, time estimate, charger power and battery health.
struct BatteryDetails: View {
    @EnvironmentObject private var battery: BatteryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PageHeader(title: "Battery")
            if battery.hasBattery {
                HStack(spacing: 6) {
                    Text("\(battery.level)%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(battery.isPluggedIn ? ChargingView.green : .white)
                    BatteryGlyph(fraction: Double(battery.level) / 100)
                }
                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                if let watts = battery.adapterWatts, battery.isPluggedIn {
                    detail("powerplug.fill", "\(watts) W charger")
                }
                if let health = battery.health {
                    detail("heart.fill", "\(health.capacityPercent)% health · \(health.cycleCount) cycles")
                }
            } else {
                Text("No battery").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var statusText: String {
        if battery.isPluggedIn {
            if battery.level >= 100 { return "Fully charged" }
            if let minutes = battery.minutesToFull { return "\(TimeText.duration(TimeInterval(minutes * 60))) to full" }
            return battery.isCharging ? "Charging" : "Plugged in, not charging"
        }
        if let minutes = battery.minutesToEmpty { return "\(TimeText.duration(TimeInterval(minutes * 60))) left" }
        return "On battery"
    }

    private func detail(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 8))
            Text(text).font(.system(size: 9.5)).lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.5))
    }
}

struct MiniGauge: View {
    let title: String
    let value: Double
    let text: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                FocusRing(progress: min(1, max(0, value)), color: color, lineWidth: 5)
                    .animation(.easeInOut(duration: 0.5), value: value)
                Text(text)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(5)
            }
            .frame(width: 46, height: 46)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

struct Sparkline: View {
    let download: [Double]
    let upload: [Double]

    var body: some View {
        Canvas { context, size in
            let peak = max(download.max() ?? 0, upload.max() ?? 0, 1024)
            for (series, color) in [(download, Color.accentBlue), (upload, Color.green)] {
                guard series.count > 1 else { continue }
                var path = Path()
                for (index, value) in series.enumerated() {
                    let point = CGPoint(x: size.width * CGFloat(index) / CGFloat(series.count - 1),
                                        y: size.height * (1 - CGFloat(value / peak)))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
            }
        }
    }
}

// MARK: - Notifications

struct NotificationsPage: View {
    @EnvironmentObject private var hub: NotificationHub
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PageHeader(title: "Notifications", detail: hub.total > 0 ? "\(hub.total) unread" : nil)
            if !settings.notificationHub {
                message("The notification hub is off. Turn it on in Settings → System.")
            } else if !hub.isTrusted {
                VStack(spacing: 8) {
                    Text("MacNotch reads the unread badges of the apps in your Dock. macOS needs your permission for that.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Button { hub.requestAccess() } label: {
                        Text("Allow Accessibility Access")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
            } else if hub.badges.isEmpty {
                message("You're all caught up — no unread badges in the Dock.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(hub.badges) { badge in
                            Button { hub.open(badge) } label: {
                                VStack(spacing: 4) {
                                    ZStack(alignment: .topTrailing) {
                                        if let url = badge.appURL {
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                                .resizable()
                                                .frame(width: 44, height: 44)
                                        }
                                        Text(badge.count)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .frame(minWidth: 18, minHeight: 18)
                                            .background(Capsule().fill(Color.red))
                                            .offset(x: 6, y: -4)
                                    }
                                    Text(badge.name)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                                .frame(width: 70)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: 80)
    }
}
