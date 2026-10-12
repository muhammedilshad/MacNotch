import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

enum Pane: String, CaseIterable, Identifiable {
    case overview, notch, appearance, music, text, battery, shelf, actions, system, general

    var id: Self { self }

    enum Group: String, CaseIterable {
        case start = "", look = "Look & Feel", features = "Features", app = "App"
    }

    var group: Group {
        switch self {
        case .overview: return .start
        case .notch, .appearance: return .look
        case .music, .text, .battery, .shelf, .actions, .system: return .features
        case .general: return .app
        }
    }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .notch: return "Notch"
        case .appearance: return "Appearance"
        case .text: return "Clock & Calendar"
        case .music: return "Music"
        case .battery: return "Battery"
        case .shelf: return "Shelf & Clipboard"
        case .actions: return "Focus & Actions"
        case .system: return "Dashboard & Privacy"
        case .general: return "General"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "Everything MacNotch can do, at a glance."
        case .notch: return "Turn the notch on, choose how it opens and which pages it shows."
        case .appearance: return "Styles, glass, borders, corners and animations."
        case .text: return "Clock, date, world clocks, your own text, events and meeting reminders."
        case .music: return "Music from any app, with controls, progress, volume and a live waveform."
        case .battery: return "Charging animation, unplug reminders, low-battery alerts and battery health."
        case .shelf: return "Keep files on a shelf, follow downloads, and reuse anything you copied."
        case .actions: return "A focus timer, one-click actions and copying text from the screen."
        case .system: return "System gauges, dev servers, camera and mic dots, unread badges and audio devices."
        case .general: return "Startup and app information."
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "sparkles"
        case .notch: return "rectangle.topthird.inset.filled"
        case .appearance: return "paintbrush.pointed.fill"
        case .text: return "calendar"
        case .music: return "music.note"
        case .battery: return "bolt.fill"
        case .shelf: return "tray.full.fill"
        case .actions: return "timer"
        case .system: return "gauge.with.dots.needle.67percent"
        case .general: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .overview: return .indigo
        case .notch: return Color(white: 0.2)
        case .appearance: return .pink
        case .text: return .red
        case .music: return Color(red: 0.98, green: 0.24, blue: 0.4)
        case .battery: return .green
        case .shelf: return .blue
        case .actions: return .orange
        case .system: return .teal
        case .general: return .gray
        }
    }

    /// Panes about how the notch looks get the live preview on top.
    var showsPreview: Bool {
        [.notch, .appearance, .text, .music, .battery].contains(self)
    }
}

/// View-local state kept in an ObservableObject: the Command Line Tools toolchain ships
/// without the SwiftUI macro plugin that `@State` needs.
final class MainViewState: ObservableObject {
    @Published var pane: Pane? = .overview
    @Published var previewExpanded = true
    @Published var backgroundError: String?
    @Published var worldClockQuery = ""
    @Published var search = ""
}

/// The main window, laid out like System Settings: a searchable sidebar with the app card on top,
/// and each section as a grouped form that starts with an icon and a short explanation.
struct MainView: View {
    @ObservedObject var state: MainViewState

    private var visiblePanes: [Pane] {
        let query = state.search.trimmingCharacters(in: .whitespaces).lowercased()
        let panes = Pane.allCases.filter { $0 != .overview }
        guard !query.isEmpty else { return panes }
        return panes.filter { ($0.title + " " + $0.subtitle).lowercased().contains(query) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $state.pane) {
                AppCard().tag(Pane.overview)
                ForEach(Pane.Group.allCases.filter { $0 != .start }, id: \.self) { group in
                    let panes = visiblePanes.filter { $0.group == group }
                    if !panes.isEmpty {
                        Section {
                            ForEach(panes) { SidebarRow(pane: $0).tag($0) }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $state.search, placement: .sidebar, prompt: "Search")
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            let pane = state.pane ?? .overview
            Form {
                if pane == .overview {
                    OverviewPane(state: state)
                } else {
                    Section { PaneHeader(pane: pane) }
                    if pane.showsPreview {
                        Section { PreviewStage(expanded: $state.previewExpanded) }
                    }
                    switch pane {
                    case .overview: EmptyView()
                    case .notch: NotchPane()
                    case .appearance: AppearancePane(state: state)
                    case .battery: BatteryPane()
                    case .shelf: ShelfClipboardPane()
                    case .actions: ActionsPane()
                    case .system: SystemPane()
                    case .text: TextClockPane(state: state)
                    case .music: MusicPane()
                    case .general: GeneralPane()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(pane.title)
        }
    }
}

// MARK: - Building blocks

/// Rounded, coloured icon like the ones in System Settings.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.82), color], startPoint: .top, endPoint: .bottom))
            .overlay(Image(systemName: symbol)
                .font(.system(size: size * 0.52, weight: .medium))
                .foregroundStyle(.white))
            .frame(width: size, height: size)
    }
}

struct SidebarRow: View {
    let pane: Pane

    var body: some View {
        Label {
            Text(pane.title)
        } icon: {
            IconTile(symbol: pane.symbol, color: pane.color)
        }
    }
}

/// The app's own row at the top of the sidebar, like the Apple Account card in System Settings.
struct AppCard: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 10) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon).resizable().frame(width: 38, height: 38)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("MacNotch").font(.headline)
                HStack(spacing: 4) {
                    Circle()
                        .fill(settings.notchEnabled ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(settings.notchEnabled ? "Notch on" : "Notch off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Toggle("Show the notch", isOn: $settings.notchEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
                .help("Turn the notch on or off (\(HotKey.displayString) from any app)")
        }
        .padding(.vertical, 6)
    }
}

/// First group of every section: big icon, title and what the section is for.
struct PaneHeader: View {
    let pane: Pane

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: pane.symbol, color: pane.color, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title).font(.title3.weight(.semibold))
                Text(pane.subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

/// A miniature desktop with a menu bar and the live notch, scaled to fit.
struct PreviewStage: View {
    @Binding var expanded: Bool
    var height: CGFloat = 196

    @EnvironmentObject private var model: NotchModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                PreviewWallpaper()
                HStack(spacing: 14) {
                    Image(systemName: "apple.logo").font(.system(size: 11, weight: .semibold))
                    Text("Finder").font(.system(size: 11, weight: .bold))
                    Text("File   Edit   View   Go").font(.system(size: 11))
                    Spacer()
                    Image(systemName: "wifi").font(.system(size: 10, weight: .semibold))
                    Text(Date().formatted(.dateTime.weekday(.abbreviated).hour().minute())).font(.system(size: 11))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .frame(height: model.geometry.notchHeight)
                .background(Color.black.opacity(0.18))

                // Wide dashboard pages are scaled down to fit.
                GeometryReader { proxy in
                    NotchContentView(geometry: model.geometry, expanded: expanded, charging: model.charging, inPreview: true)
                        .frame(width: NotchController.canvasSize.width, alignment: .top)
                        .scaleEffect(min(1, proxy.size.width / NotchController.canvasSize.width), anchor: .top)
                        .frame(width: proxy.size.width, alignment: .top)
                }
                .opacity(settings.notchEnabled ? 1 : 0.35)

                if !settings.notchEnabled {
                    Text("The notch is turned off")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack {
                Picker("Preview", selection: $expanded) {
                    Text("Closed").tag(false)
                    Text("Open").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer()
                if expanded {
                    Picker("Page", selection: Binding(get: { model.tab }, set: { model.tab = $0 })) {
                        ForEach(DashboardTab.allCases.filter(settings.isTabEnabled)) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

/// Soft, colourful wallpaper behind the preview, so glass styles have something to show.
struct PreviewWallpaper: View {
    private func glow(_ color: Color, at center: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(0.9), color.opacity(0)], center: center, startRadius: 0, endRadius: radius)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.1, blue: 0.3), Color(red: 0.36, green: 0.16, blue: 0.48)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            glow(Color(red: 0.2, green: 0.45, blue: 1), at: UnitPoint(x: 0.12, y: 0.95), radius: 320)
            glow(Color(red: 1, green: 0.42, blue: 0.3), at: UnitPoint(x: 0.9, y: 1.0), radius: 300)
            glow(Color(red: 0.75, green: 0.3, blue: 0.95), at: UnitPoint(x: 0.52, y: 1.1), radius: 240)
        }
    }
}

// MARK: - Overview

struct OverviewPane: View {
    @ObservedObject var state: MainViewState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Section {
            VStack(spacing: 6) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().frame(width: 72, height: 72)
                }
                Text("MacNotch").font(.title2.weight(.semibold))
                Text("Your notch, made useful. Point at it to open the dashboard.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Toggle("Show the notch", isOn: $settings.notchEnabled)
                    .toggleStyle(.switch)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        Section { PreviewStage(expanded: $state.previewExpanded) }

        Section {
            ForEach(FeatureRow.Feature.allCases) { feature in
                FeatureRow(feature: feature) { state.pane = feature.pane }
            }
        } header: {
            Text("Features")
        } footer: {
            Text("Switch a feature off to hide it everywhere. Click a feature to customise it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Getting started") {
            TipRow(symbol: "cursorarrow.motionlines", color: .indigo, title: "Point at the notch",
                   text: "It opens into a dashboard. The icons at its top left switch pages.")
            TipRow(symbol: "doc.on.doc.fill", color: .blue, title: "Drag files to it",
                   text: "Drop them on the shelf, then drag them out or AirDrop them later.")
            TipRow(symbol: "command", color: .gray, title: "Shortcuts",
                   text: "\(HotKey.displayString) turns the notch on or off. \(HotKey.ocrDisplayString) copies text from the screen.")
        }

        Section {
            PermissionRows()
        } header: {
            Text("Permissions")
        } footer: {
            Text("Each permission is only needed for the feature next to it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// One feature as a settings row: icon, name, one-line description, switch and a chevron to its settings.
struct FeatureRow: View {
    enum Feature: String, CaseIterable, Identifiable {
        case music, calendar, worldClock, charging, shelf, clipboard, focus, screenText, dashboard, privacy, notifications, themes

        var id: Self { self }

        var title: String {
            switch self {
            case .music: return "Music"
            case .calendar: return "Calendar"
            case .worldClock: return "Clock & World Clocks"
            case .charging: return "Charging"
            case .shelf: return "Shelf & Transfers"
            case .clipboard: return "Clipboard History"
            case .focus: return "Focus & Quick Actions"
            case .screenText: return "Copy Text from Screen"
            case .dashboard: return "Developer Dashboard"
            case .privacy: return "Camera & Microphone Dots"
            case .notifications: return "Notification Hub"
            case .themes: return "Themes"
            }
        }

        var detail: String {
            switch self {
            case .music: return "Song, artwork and controls from any app"
            case .calendar: return "Today's events, countdowns and reminders"
            case .worldClock: return "Live clock, date format and other cities"
            case .charging: return "Glowing animation, unplug and low-battery alerts"
            case .shelf: return "Keep files on the notch and follow downloads"
            case .clipboard: return "Paste anything you copied earlier"
            case .focus: return "Pomodoro timer and one-click actions"
            case .screenText: return "\(HotKey.ocrDisplayString), select an area, and its text is copied"
            case .dashboard: return "CPU, memory, network and local servers"
            case .privacy: return "A dot while the camera or a mic is in use"
            case .notifications: return "Unread counts from your Dock apps"
            case .themes: return "Black, glass or a picture, with borders and effects"
            }
        }

        var symbol: String {
            switch self {
            case .music: return "music.note"
            case .calendar: return "calendar"
            case .worldClock: return "globe"
            case .charging: return "bolt.fill"
            case .shelf: return "tray.full.fill"
            case .clipboard: return "doc.on.clipboard.fill"
            case .focus: return "timer"
            case .screenText: return "text.viewfinder"
            case .dashboard: return "gauge.with.dots.needle.67percent"
            case .privacy: return "video.fill"
            case .notifications: return "bell.badge.fill"
            case .themes: return "paintbrush.pointed.fill"
            }
        }

        var color: Color {
            switch self {
            case .music: return Color(red: 0.98, green: 0.24, blue: 0.4)
            case .calendar: return .red
            case .worldClock: return .cyan
            case .charging: return .green
            case .shelf: return .blue
            case .clipboard: return .indigo
            case .focus: return .orange
            case .screenText: return .purple
            case .dashboard: return .teal
            case .privacy: return Color(red: 0.2, green: 0.72, blue: 0.35)
            case .notifications: return .red
            case .themes: return .pink
            }
        }

        var pane: Pane {
            switch self {
            case .music: return .music
            case .calendar, .worldClock: return .text
            case .charging: return .battery
            case .shelf, .clipboard: return .shelf
            case .focus, .screenText: return .actions
            case .dashboard, .privacy, .notifications: return .system
            case .themes: return .appearance
            }
        }
    }

    let feature: Feature
    let open: () -> Void

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: feature.symbol, color: feature.color, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                Text(feature.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let binding = isOn {
                Toggle(feature.title, isOn: binding).toggleStyle(.switch).labelsHidden().controlSize(.small)
            } else if feature == .screenText {
                Button("Try It") { NotchController.shared.captureScreenText() }.controlSize(.small)
            }
            Button(action: open) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 16, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Customise \(feature.title)")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }

    /// The switch that turns this feature on or off, if it has one.
    private var isOn: Binding<Bool>? {
        switch feature {
        case .music: return $settings.showMusic
        case .calendar: return $settings.showCalendar
        case .worldClock: return $settings.showTime
        case .charging: return $settings.chargingAnimation
        case .shelf: return tab(.shelf)
        case .clipboard:
            return Binding(get: { settings.clipboardEnabled && settings.isTabEnabled(.clipboard) },
                           set: { settings.clipboardEnabled = $0; settings.setTab(.clipboard, enabled: $0) })
        case .focus: return tab(.actions)
        case .dashboard: return tab(.system)
        case .privacy: return $settings.privacyIndicators
        case .notifications:
            return Binding(get: { settings.notificationHub && settings.isTabEnabled(.notifications) },
                           set: { settings.notificationHub = $0; settings.setTab(.notifications, enabled: $0) })
        case .screenText, .themes: return nil
        }
    }

    private func tab(_ tab: DashboardTab) -> Binding<Bool> {
        Binding(get: { settings.isTabEnabled(tab) }, set: { settings.setTab(tab, enabled: $0) })
    }
}

struct TipRow: View {
    let symbol: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Which permissions are granted, with a button to fix each one.
struct PermissionRows: View {
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var hub: NotificationHub
    @EnvironmentObject private var spectrum: AudioSpectrum

    enum Status { case granted, denied, later }

    var body: some View {
        row("Calendars", "Events, countdowns and reminders", symbol: "calendar", color: .red,
            status: calendar.access == .granted ? .granted : (calendar.access == .denied ? .denied : .later),
            anchor: "Privacy_Calendars")
        row("Accessibility", "Notification hub", symbol: "accessibility", color: .blue,
            status: hub.isTrusted ? .granted : .denied, anchor: "Privacy_Accessibility") { hub.requestAccess() }
        row("Screen Recording", "Copy text from the screen", symbol: "rectangle.dashed.badge.record", color: .indigo,
            status: CGPreflightScreenCaptureAccess() ? .granted : .later, anchor: "Privacy_ScreenCapture") {
                CGRequestScreenCaptureAccess()
            }
        row("System Audio Recording", "Waveform that follows the music", symbol: "waveform", color: .pink,
            status: spectrum.isLive ? .granted : .later, anchor: "Privacy_ScreenCapture")
    }

    private func row(_ title: String, _ detail: String, symbol: String, color: Color, status: Status,
                     anchor: String, request: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if status == .granted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Text(status == .denied ? "Not allowed" : "Asked when first used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Allow…") {
                    request?()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Panes

struct NotchPane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var model: NotchModel

    var body: some View {
        Section("Display") {
            Toggle("Show the MacNotch on screen", isOn: $settings.notchEnabled)
            Text("You can also use the switch on the MacNotch card at the top of the sidebar, the Notch menu, the Dock icon menu, or \(HotKey.displayString).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Expand when the pointer is over the notch", isOn: $settings.expandOnHover)
            Toggle("Pop open for a moment when music starts", isOn: $settings.peekOnTrackChange)
            LabeledContent("Side width") {
                HStack {
                    Slider(value: $settings.wingWidth, in: 40...220)
                    Text("\(Int(settings.wingWidth)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
        Section("Dashboard pages") {
            ForEach(DashboardTab.allCases.filter { $0 != .home }) { tab in
                Toggle(isOn: Binding(get: { settings.isTabEnabled(tab) }, set: { settings.setTab(tab, enabled: $0) })) {
                    Label(tab.title, systemImage: tab.symbol)
                }
            }
            Text("Pages appear as icons at the top left of the expanded notch. Home, with music, calendar and clock, is always there.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("This Mac") {
            LabeledContent("Notch",
                           value: model.geometry.hasHardwareNotch ? "Built-in camera notch" : "Virtual notch (no camera notch on this display)")
            LabeledContent("Notch size",
                           value: "\(Int(model.geometry.notchWidth)) × \(Int(model.geometry.notchHeight)) pt")
            LabeledContent("Processor", value: SystemInfo.processor)
        }
    }
}

struct TextClockPane: View {
    @ObservedObject var state: MainViewState
    @EnvironmentObject private var settings: AppSettings

    private var matches: [String] {
        let query = state.worldClockQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard query.count >= 2 else { return [] }
        return TimeZone.knownTimeZoneIdentifiers
            .filter { $0.lowercased().replacingOccurrences(of: "_", with: " ").contains(query) && !settings.worldClocks.contains($0) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        Section("Custom text") {
            Toggle("Show custom text", isOn: $settings.showCustomText)
            TextField("Text", text: $settings.customText, prompt: Text("Hello 👋"))
                .disabled(!settings.showCustomText)
            Text("On Macs with a camera notch the text sits beside the notch and is shown in full when it expands. On Intel Macs and displays without a notch it sits in the middle of the pill.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Clock") {
            Toggle("Show time", isOn: $settings.showTime)
            Toggle("24-hour time", isOn: $settings.use24Hour)
                .disabled(!settings.showTime)
            Toggle("Show seconds", isOn: $settings.showSeconds)
                .disabled(!settings.showTime)
        }
        Section("Date") {
            Toggle("Show date when expanded", isOn: $settings.showDate)
            Picker("Format", selection: $settings.dateStyle) {
                ForEach(DateDisplayStyle.allCases) { style in
                    Text(style == .custom ? "Custom" : style.format(Date(), custom: "")).tag(style)
                }
            }
            .disabled(!settings.showDate)
            if settings.dateStyle == .custom {
                TextField("Pattern", text: $settings.customDateFormat, prompt: Text("EEE d MMM"))
                LabeledContent("Preview", value: settings.dateStyle.format(Date(), custom: settings.customDateFormat))
                Text("Uses Unicode date patterns: EEEE weekday, EEE short weekday, d day, MMMM month, MMM short month, yyyy year, w week number.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        Section("World clocks") {
            ForEach(settings.worldClocks, id: \.self) { identifier in
                HStack {
                    Text(WorldClock.city(identifier))
                    Text(WorldClock.offsetDescription(identifier)).foregroundStyle(.secondary)
                    Spacer()
                    Text(WorldClock.time(Date(), in: TimeZone(identifier: identifier) ?? .current, use24Hour: settings.use24Hour))
                        .monospacedDigit()
                    Button(role: .destructive) {
                        settings.worldClocks.removeAll { $0 == identifier }
                    } label: { Image(systemName: "minus.circle.fill") }
                        .buttonStyle(.borderless)
                }
            }
            TextField("Add a city", text: $state.worldClockQuery, prompt: Text("Search, for example London or Tokyo"))
            ForEach(matches, id: \.self) { identifier in
                Button {
                    settings.worldClocks.append(identifier)
                    state.worldClockQuery = ""
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(identifier.replacingOccurrences(of: "_", with: " "))
                        Spacer()
                        Text(WorldClock.offsetDescription(identifier)).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
            }
            Text("Up to three cities show under the clock in the expanded notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Calendar") {
            Toggle("Show the calendar when the notch expands", isOn: $settings.showCalendar)
            Toggle("Count down to the next meeting beside the notch", isOn: $settings.eventCountdown)
                .disabled(!settings.showCalendar)
            Picker("Meeting reminders", selection: $settings.reminderMinutes) {
                Text("Off").tag(0)
                Text("1 minute before").tag(1)
                Text("5 minutes before").tag(5)
                Text("10 minutes before").tag(10)
                Text("15 minutes before").tag(15)
            }
            .disabled(!settings.showCalendar)
            Text("Reminders drop down from the notch with Join (for Zoom, Meet, Teams and Webex links), Snooze 5 min and Dismiss. Events come from the Calendar app; macOS asks for access the first time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct MusicPane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var player: NowPlayingMonitor
    @EnvironmentObject private var spectrum: AudioSpectrum

    var body: some View {
        Section("Music") {
            Toggle("Show music in the notch", isOn: $settings.showMusic)
            Toggle("Show the progress bar (drag it to seek)", isOn: $settings.showProgress)
            Toggle("Show the volume slider", isOn: $settings.showVolume)
            Toggle("Show Spotify shuffle and repeat buttons", isOn: $settings.spotifyControls)
        }
        Section("Waveform") {
            Toggle("Animate the waveform", isOn: $settings.animateMusicBars)
            Toggle("Make it react to the music", isOn: $settings.reactiveWaveform)
                .disabled(!settings.animateMusicBars)
            LabeledContent("Status", value: spectrum.isLive ? "Following the music" : (player.isPlaying && settings.reactiveWaveform ? "Waiting for audio permission" : "Built-in animation"))
            Text("To follow the beat, MacNotch listens to the Mac's sound output while music plays. macOS asks for \"System Audio Recording\" permission once; nothing is recorded or saved. Requires macOS 14.2 or later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Now playing") {
            if let track = player.track {
                LabeledContent("Song", value: track.title)
                LabeledContent("Artist", value: track.artist.isEmpty ? "—" : track.artist)
                LabeledContent("Playing in", value: track.source)
                LabeledContent("Status", value: player.isPlaying ? "Playing" : "Paused")
                HStack(spacing: 14) {
                    Spacer()
                    Button { player.send(.previous) } label: { Image(systemName: "backward.fill") }
                    Button { player.send(.togglePlayPause) } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button { player.send(.next) } label: { Image(systemName: "forward.fill") }
                    Spacer()
                }
                .controlSize(.large)
            } else {
                Text("Nothing playing yet. Play a song or video in any app and it will show up here and in the notch.")
                    .foregroundStyle(.secondary)
            }
            if AppInfo.lookup(NowPlayingMonitor.spotifyBundleID) != nil {
                Button("Open Spotify and Play") { player.launchSpotify(play: true) }
            }
        }
        Section("Supported players") {
            Text("Anything that shows up in the system's Now Playing works: Spotify, Apple Music, YouTube and other sites in Safari, Chrome, Arc or Firefox, Podcasts, VLC and more. Click the artwork in the notch to jump to the app that's playing.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct GeneralPane: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Section("Startup") {
            Toggle("Open MacNotch at login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            if let error = settings.loginItemError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Text("Closing this window keeps the notch running. Click the app in the Dock to open this window again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("About") {
            LabeledContent("Version", value: SystemInfo.version)
            LabeledContent("Running on", value: SystemInfo.processor)
            Button("Quit MacNotch") { NSApp.terminate(nil) }
        }
    }
}

struct AppearancePane: View {
    @ObservedObject var state: MainViewState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Section("Notch style") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(NotchStyle.allCases) { style in
                        StyleTile(style: style, selected: settings.notchStyle == style) {
                            settings.notchStyle = style
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            if settings.notchStyle == .image {
                HStack {
                    Button("Choose Picture…") {
                        state.backgroundError = ImageImport.choose(message: "Choose a picture for the notch background") {
                            try settings.importBackgroundImage(from: $0)
                        }
                    }
                    Button("Remove", role: .destructive) { settings.removeBackgroundImage() }
                        .disabled(settings.backgroundImageURL == nil)
                    if let error = state.backgroundError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                LabeledContent("Darken") { Slider(value: $settings.backgroundImageDim, in: 0...0.85) }
                LabeledContent("Blur") { Slider(value: $settings.backgroundImageBlur, in: 0...30) }
            }
            Toggle("Match the background to the album art", isOn: $settings.matchAlbumArt)
            Text("Tints the notch and the waveform with the colours of the song that's playing. Deep Black matches the camera notch exactly; the glass styles show what's behind the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Border, shadow and corners for \(settings.notchStyle.title)") {
            Picker("Border", selection: $settings.theme.border) {
                ForEach(ThemeOptions.Border.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if settings.theme.border == .neon {
                Toggle("Use the album art colour", isOn: $settings.theme.neonFollowsAlbum)
                ColorPicker("Neon colour", selection: Binding(get: { Color(hex: settings.theme.neonColor) },
                                                              set: { settings.theme.neonColor = $0.hexString }),
                            supportsOpacity: false)
                    .disabled(settings.theme.neonFollowsAlbum)
            }
            Toggle("Drop shadow when open", isOn: $settings.theme.shadow)
            if settings.theme.shadow {
                slider("Shadow size", value: $settings.theme.shadowRadius, in: 4...40)
            }
            slider("Top curve", value: $settings.theme.shoulderRadius, in: 4...24)
            slider("Bottom corners, closed", value: $settings.theme.collapsedRadius, in: 4...20)
            slider("Bottom corners, open", value: $settings.theme.expandedRadius, in: 12...44)
            Button("Reset \(settings.notchStyle.title) to Defaults") { settings.resetTheme() }
            Text("Each style remembers its own border, shadow and corners.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Animations") {
            Picker("Background", selection: $settings.backgroundAnimation) {
                ForEach(BackgroundAnimation.allCases) { animation in
                    Text(animation.title).tag(animation)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Music waveform", isOn: $settings.animateMusicBars)
            Toggle("Pop open when a song starts", isOn: $settings.peekOnTrackChange)
            Toggle("Charging animation", isOn: $settings.chargingAnimation)
            Toggle("Charging glow around the notch", isOn: $settings.chargingGlow)
            Toggle("Neon border pulse", isOn: $settings.neonPulse)
            Toggle("Smooth focus timer ring", isOn: $settings.animateFocusRing)
            Toggle("Bouncy banners", isOn: $settings.animateBanners)
            Toggle("Page transitions", isOn: $settings.animateTabs)
            Text("Each feature's animation can be turned off on its own. Album colours uses the artwork of the song that's playing and falls back to Aurora.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range)
                Text("\(Int(value.wrappedValue)) pt")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct StyleTile: View {
    let style: NotchStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.12, green: 0.30, blue: 0.85), Color(red: 0.95, green: 0.42, blue: 0.25)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(Color.yellow.opacity(0.85)).frame(width: 34).offset(x: -26, y: 8)
                    Circle().fill(Color.purple).frame(width: 26).offset(x: 30, y: -10)
                    NotchShape(topRadius: 6, bottomRadius: 12)
                        .fill(Color.clear)
                        .background(NotchBackground(style: style, animation: .none, inPreview: true))
                        .clipShape(NotchShape(topRadius: 6, bottomRadius: 12))
                        .overlay(Text("Aa").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white))
                        .frame(width: 92, height: 38)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(width: 120, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 2.5 : 1))
                Text(style.title).font(.callout.weight(selected ? .semibold : .regular))
                Text(style.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct BatteryPane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var battery: BatteryMonitor

    var body: some View {
        Section("Charging") {
            Toggle("Play an animation in the notch when the charger is connected", isOn: $settings.chargingAnimation)
            Toggle("Glow around the notch while it plays", isOn: $settings.chargingGlow)
            Toggle("Show the battery level beside the notch while plugged in", isOn: $settings.chargingIndicator)
            HStack {
                Button("Preview Charging") { NotchController.shared.playChargingAnimation(full: false) }
                Button("Preview Fully Charged") { NotchController.shared.playChargingAnimation(full: true) }
            }
        }
        Section("Smart charging") {
            Picker("Suggest unplugging at", selection: $settings.chargeLimitAlert) {
                Text("Off").tag(0)
                ForEach([80, 85, 90, 95], id: \.self) { Text("\($0)%").tag($0) }
            }
            Toggle("Warn at 20%, 10% and 5% on battery", isOn: $settings.lowBatteryAlerts)
            Text("Keeping a battery between 20% and 80% slows its wear. Apps can't stop a Mac from charging, so MacNotch reminds you instead; macOS's own Optimised Battery Charging is in System Settings → Battery.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Battery") {
            if battery.hasBattery {
                LabeledContent("Level", value: "\(battery.level)%")
                LabeledContent("Power", value: battery.isPluggedIn
                               ? (battery.isCharging ? "Charging" : "Plugged in, not charging")
                               : "On battery")
                if let minutes = battery.isPluggedIn ? battery.minutesToFull : battery.minutesToEmpty {
                    LabeledContent(battery.isPluggedIn ? "Time to full" : "Time left",
                                   value: TimeText.duration(TimeInterval(minutes * 60)))
                }
                if let watts = battery.adapterWatts, battery.isPluggedIn {
                    LabeledContent("Charger", value: "\(watts) W")
                }
                if let health = battery.health {
                    LabeledContent("Health", value: "\(health.capacityPercent)% of original capacity")
                    LabeledContent("Charge cycles", value: "\(health.cycleCount)")
                    if health.temperatureCelsius > 0 {
                        LabeledContent("Temperature", value: String(format: "%.1f °C", health.temperatureCelsius))
                    }
                }
            } else {
                Text("This Mac has no battery, so the charging animation never plays on its own. You can still preview it.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ShelfClipboardPane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var shelf: ShelfStore
    @EnvironmentObject private var clipboard: ClipboardMonitor

    var body: some View {
        Section("Drag-and-drop shelf") {
            Toggle("Show the Shelf page", isOn: Binding(get: { settings.isTabEnabled(.shelf) },
                                                         set: { settings.setTab(.shelf, enabled: $0) }))
            LabeledContent("Files on the shelf", value: "\(shelf.items.count)")
            Button("Clear Shelf") { shelf.clear() }.disabled(shelf.items.isEmpty)
            Text("Drag any file to the notch: it opens the shelf so you can drop it. Drag files back out to any app, double-click to open, or right-click to AirDrop, share or copy the text from an image.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("File transfers") {
            Toggle("Track downloads and AirDrops in the Downloads folder", isOn: $settings.downloadsMonitor)
            Text("Shows downloads in progress from Safari, Chrome, Edge, Arc, Brave and Firefox with their speed, and files received in the last 30 minutes. While something downloads, its speed shows beside the notch. macOS may ask for access to the Downloads folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Clipboard history") {
            Toggle("Keep a clipboard history", isOn: $settings.clipboardEnabled)
            Picker("Keep up to", selection: $settings.clipboardLimit) {
                ForEach([20, 40, 80, 150], id: \.self) { Text("\($0) items").tag($0) }
            }
            .disabled(!settings.clipboardEnabled)
            Button("Clear History", role: .destructive) { clipboard.clear() }
                .disabled(clipboard.items.isEmpty)
            Text("Click an item in the notch to copy it again; right-click to pin it. Passwords and other items that apps mark as private are never saved. History is stored only on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActionsPane: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Section("Focus timer") {
            Stepper("Focus: \(settings.focusMinutes) min", value: $settings.focusMinutes, in: 5...120, step: 5)
            Stepper("Short break: \(settings.shortBreakMinutes) min", value: $settings.shortBreakMinutes, in: 1...30)
            Stepper("Long break: \(settings.longBreakMinutes) min", value: $settings.longBreakMinutes, in: 5...60, step: 5)
            Stepper("Long break after \(settings.sessionsPerCycle) sessions", value: $settings.sessionsPerCycle, in: 2...8)
            Text("The time left shows beside the notch while a session runs, and a banner lets you start the break when it ends.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Screenshot OCR") {
            LabeledContent("Shortcut", value: HotKey.ocrDisplayString)
            Button("Copy Text from Screen…") { NotchController.shared.captureScreenText() }
            Text("Select any part of the screen and its text is copied to the clipboard. macOS asks for Screen Recording permission the first time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Quick actions") {
            ForEach($settings.quickActions) { $action in
                QuickActionEditor(action: $action) {
                    settings.quickActions.removeAll { $0.id == action.id }
                }
            }
            HStack {
                Button("Add Action") {
                    settings.quickActions.append(QuickAction(title: "New", kind: .url, target: "https://", symbol: "link"))
                }
                Button("Reset to Defaults") { settings.quickActions = QuickAction.defaults }
            }
            Text("Shell commands run with zsh as your user. Symbols are SF Symbols names, such as terminal, globe or folder.fill.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct QuickActionEditor: View {
    @Binding var action: QuickAction
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let icon = QuickActionRunner.icon(for: action) {
                    Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                } else {
                    Image(systemName: action.symbol).frame(width: 20)
                }
                TextField("Name", text: $action.title).frame(maxWidth: 140)
                Picker("", selection: $action.kind) {
                    ForEach(QuickAction.Kind.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 170)
                Spacer()
                Button { QuickActionRunner.run(action) } label: { Image(systemName: "play.fill") }
                    .buttonStyle(.borderless)
                    .help("Try it")
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            HStack {
                TextField("Target", text: $action.target, prompt: Text(action.kind.placeholder))
                if action.kind == .app {
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.application]
                        panel.directoryURL = URL(fileURLWithPath: "/Applications")
                        if panel.runModal() == .OK, let url = panel.url {
                            action.target = url.path
                            action.title = url.deletingPathExtension().lastPathComponent
                        }
                    }
                } else {
                    TextField("Symbol", text: $action.symbol).frame(maxWidth: 130)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct SystemPane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var audio: AudioController
    @EnvironmentObject private var hub: NotificationHub
    @EnvironmentObject private var privacy: PrivacyMonitor

    var body: some View {
        Section("Developer dashboard") {
            Toggle("Show the Dashboard page", isOn: Binding(get: { settings.isTabEnabled(.system) },
                                                             set: { settings.setTab(.system, enabled: $0) }))
            Text("CPU, memory and disk gauges, live network speed with a graph, local dev servers (click to open, right-click to stop) and battery health. Sampling only runs while the page is open.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Privacy status") {
            Toggle("Show a dot beside the notch while the camera or a microphone is in use", isOn: $settings.privacyIndicators)
            LabeledContent("Camera", value: privacy.cameraInUse ? "In use" : "Not in use")
            LabeledContent("Microphone", value: privacy.microphoneInUse ? "In use" : "Not in use")
            Text("Green means the camera is on, orange means a microphone is recording.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Notification hub") {
            Toggle("Show unread counts from the Dock", isOn: $settings.notificationHub)
            LabeledContent("Accessibility access", value: hub.isTrusted ? "Allowed" : "Not allowed")
            if !hub.isTrusted {
                Button("Allow Accessibility Access…") { hub.requestAccess() }
            }
            Text("macOS doesn't let apps read other apps' notifications, so the hub shows the unread badges of apps in your Dock (Mail, Messages, Slack…). Click one in the notch to open the app. After updating MacNotch you may need to switch its Accessibility permission off and on again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Audio devices") {
            Picker("Output", selection: Binding(get: { audio.defaultOutput },
                                                set: { id in audio.outputs.first { $0.id == id }.map(audio.makeDefaultOutput) })) {
                ForEach(audio.outputs) { Text($0.name).tag($0.id) }
            }
            Picker("Input", selection: Binding(get: { audio.defaultInput },
                                               set: { id in audio.inputs.first { $0.id == id }.map(audio.makeDefaultInput) })) {
                ForEach(audio.inputs) { Text($0.name).tag($0.id) }
            }
            LabeledContent("Volume") {
                HStack {
                    Button { audio.setMuted(!audio.isMuted) } label: {
                        Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderless)
                    Slider(value: Binding(get: { Double(audio.volume) }, set: { audio.setVolume(Float($0)) }))
                        .disabled(!audio.canSetVolume)
                }
            }
            Text("The same controls are in the notch: the AirPlay button on the music card switches speakers and microphones.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

enum SystemInfo {
    static var processor: String {
        #if arch(arm64)
        return "Apple silicon"
        #else
        return "Intel"
        #endif
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

enum ImageImport {
    /// Shows an open panel for an image; returns an error message if the import failed.
    static func choose(message: String, importer: (URL) throws -> Void) -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP, .gif, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = message
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try importer(url)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
