import AppKit
import Foundation
import ServiceManagement

enum NotchStyle: String, CaseIterable, Identifiable {
    case black
    case frosted
    case clear
    case blur
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .black: return "Deep Black"
        case .frosted: return "Frosted"
        case .clear: return "Clear"
        case .blur: return "Blur"
        case .image: return "Image"
        }
    }

    var subtitle: String {
        switch self {
        case .black: return "Blends into the camera notch"
        case .frosted: return "Soft, milky glass"
        case .clear: return "See-through liquid glass"
        case .blur: return "Heavy, dark blur"
        case .image: return "Your own picture"
        }
    }
}

enum BackgroundAnimation: String, CaseIterable, Identifiable {
    case none
    case aurora
    case albumGlow
    case waves

    var id: Self { self }

    var title: String {
        switch self {
        case .none: return "None"
        case .aurora: return "Aurora"
        case .albumGlow: return "Album colours"
        case .waves: return "Waves"
        }
    }
}

/// All user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let notchEnabled = "notchEnabled"
        static let expandOnHover = "expandOnHover"
        static let peekOnTrackChange = "peekOnTrackChange"
        static let wingWidth = "wingWidth"
        static let showCustomText = "showCustomText"
        static let customText = "customText"
        static let showTime = "showTime"
        static let use24Hour = "use24Hour"
        static let showSeconds = "showSeconds"
        static let showDate = "showDate"
        static let showMusic = "showMusic"
        static let showCalendar = "showCalendar"
        static let notchStyle = "notchStyle"
        static let backgroundAnimation = "backgroundAnimation"
        static let chargingAnimation = "chargingAnimation"
        static let chargingIndicator = "chargingIndicator"
        static let themes = "themes"
        static let matchAlbumArt = "matchAlbumArt"
        static let backgroundImageFileName = "backgroundImageFileName"
        static let backgroundImageDim = "backgroundImageDim"
        static let backgroundImageBlur = "backgroundImageBlur"
        static let animateMusicBars = "animateMusicBars"
        static let reactiveWaveform = "reactiveWaveform"
        static let chargingGlow = "chargingGlow"
        static let neonPulse = "neonPulse"
        static let animateFocusRing = "animateFocusRing"
        static let animateBanners = "animateBanners"
        static let animateTabs = "animateTabs"
        static let showProgress = "showProgress"
        static let showVolume = "showVolume"
        static let spotifyControls = "spotifyControls"
        static let dateStyle = "dateStyle"
        static let customDateFormat = "customDateFormat"
        static let eventCountdown = "eventCountdown"
        static let reminderMinutes = "reminderMinutes"
        static let worldClocks = "worldClocks"
        static let enabledTabs = "enabledTabs"
        static let clipboardEnabled = "clipboardEnabled"
        static let clipboardLimit = "clipboardLimit"
        static let downloadsMonitor = "downloadsMonitor"
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let sessionsPerCycle = "sessionsPerCycle"
        static let quickActions = "quickActions"
        static let privacyIndicators = "privacyIndicators"
        static let chargeLimitAlert = "chargeLimitAlert"
        static let lowBatteryAlerts = "lowBatteryAlerts"
        static let notificationHub = "notificationHub"
    }

    private let defaults = UserDefaults.standard

    @Published var notchEnabled: Bool { didSet { defaults.set(notchEnabled, forKey: Key.notchEnabled) } }
    @Published var expandOnHover: Bool { didSet { defaults.set(expandOnHover, forKey: Key.expandOnHover) } }
    @Published var peekOnTrackChange: Bool { didSet { defaults.set(peekOnTrackChange, forKey: Key.peekOnTrackChange) } }
    @Published var wingWidth: Double { didSet { defaults.set(wingWidth, forKey: Key.wingWidth) } }

    @Published var showCustomText: Bool { didSet { defaults.set(showCustomText, forKey: Key.showCustomText) } }
    @Published var customText: String { didSet { defaults.set(customText, forKey: Key.customText) } }

    @Published var showTime: Bool { didSet { defaults.set(showTime, forKey: Key.showTime) } }
    @Published var use24Hour: Bool { didSet { defaults.set(use24Hour, forKey: Key.use24Hour) } }
    @Published var showSeconds: Bool { didSet { defaults.set(showSeconds, forKey: Key.showSeconds) } }
    @Published var showDate: Bool { didSet { defaults.set(showDate, forKey: Key.showDate) } }

    @Published var showMusic: Bool { didSet { defaults.set(showMusic, forKey: Key.showMusic) } }
    @Published var showCalendar: Bool { didSet { defaults.set(showCalendar, forKey: Key.showCalendar) } }

    @Published var notchStyle: NotchStyle { didSet { defaults.set(notchStyle.rawValue, forKey: Key.notchStyle) } }
    @Published var backgroundAnimation: BackgroundAnimation {
        didSet { defaults.set(backgroundAnimation.rawValue, forKey: Key.backgroundAnimation) }
    }

    @Published var chargingAnimation: Bool { didSet { defaults.set(chargingAnimation, forKey: Key.chargingAnimation) } }
    @Published var chargingIndicator: Bool { didSet { defaults.set(chargingIndicator, forKey: Key.chargingIndicator) } }

    // Themes
    @Published var themes: [String: ThemeOptions] { didSet { saveCodable(themes, forKey: Key.themes) } }
    @Published var matchAlbumArt: Bool { didSet { defaults.set(matchAlbumArt, forKey: Key.matchAlbumArt) } }
    @Published private(set) var backgroundImageFileName: String? {
        didSet { defaults.set(backgroundImageFileName, forKey: Key.backgroundImageFileName) }
    }
    @Published var backgroundImageDim: Double { didSet { defaults.set(backgroundImageDim, forKey: Key.backgroundImageDim) } }
    @Published var backgroundImageBlur: Double { didSet { defaults.set(backgroundImageBlur, forKey: Key.backgroundImageBlur) } }

    // Animations, one switch per feature
    @Published var animateMusicBars: Bool { didSet { defaults.set(animateMusicBars, forKey: Key.animateMusicBars) } }
    @Published var reactiveWaveform: Bool { didSet { defaults.set(reactiveWaveform, forKey: Key.reactiveWaveform) } }
    @Published var chargingGlow: Bool { didSet { defaults.set(chargingGlow, forKey: Key.chargingGlow) } }
    @Published var neonPulse: Bool { didSet { defaults.set(neonPulse, forKey: Key.neonPulse) } }
    @Published var animateFocusRing: Bool { didSet { defaults.set(animateFocusRing, forKey: Key.animateFocusRing) } }
    @Published var animateBanners: Bool { didSet { defaults.set(animateBanners, forKey: Key.animateBanners) } }
    @Published var animateTabs: Bool { didSet { defaults.set(animateTabs, forKey: Key.animateTabs) } }

    // Music
    @Published var showProgress: Bool { didSet { defaults.set(showProgress, forKey: Key.showProgress) } }
    @Published var showVolume: Bool { didSet { defaults.set(showVolume, forKey: Key.showVolume) } }
    @Published var spotifyControls: Bool { didSet { defaults.set(spotifyControls, forKey: Key.spotifyControls) } }

    // Clock and calendar
    @Published var dateStyle: DateDisplayStyle { didSet { defaults.set(dateStyle.rawValue, forKey: Key.dateStyle) } }
    @Published var customDateFormat: String { didSet { defaults.set(customDateFormat, forKey: Key.customDateFormat) } }
    @Published var eventCountdown: Bool { didSet { defaults.set(eventCountdown, forKey: Key.eventCountdown) } }
    /// Minutes before a meeting to show a reminder; 0 turns reminders off.
    @Published var reminderMinutes: Int { didSet { defaults.set(reminderMinutes, forKey: Key.reminderMinutes) } }
    /// Time zone identifiers, such as "Europe/London".
    @Published var worldClocks: [String] { didSet { defaults.set(worldClocks, forKey: Key.worldClocks) } }

    // Dashboard
    @Published var enabledTabs: [DashboardTab] { didSet { defaults.set(enabledTabs.map(\.rawValue), forKey: Key.enabledTabs) } }
    @Published var clipboardEnabled: Bool { didSet { defaults.set(clipboardEnabled, forKey: Key.clipboardEnabled) } }
    @Published var clipboardLimit: Int { didSet { defaults.set(clipboardLimit, forKey: Key.clipboardLimit) } }
    @Published var downloadsMonitor: Bool { didSet { defaults.set(downloadsMonitor, forKey: Key.downloadsMonitor) } }
    @Published var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) } }
    @Published var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes) } }
    @Published var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes) } }
    @Published var sessionsPerCycle: Int { didSet { defaults.set(sessionsPerCycle, forKey: Key.sessionsPerCycle) } }
    @Published var quickActions: [QuickAction] { didSet { saveCodable(quickActions, forKey: Key.quickActions) } }
    @Published var privacyIndicators: Bool { didSet { defaults.set(privacyIndicators, forKey: Key.privacyIndicators) } }
    @Published var notificationHub: Bool { didSet { defaults.set(notificationHub, forKey: Key.notificationHub) } }

    // Smart charging
    /// Battery level that triggers an "unplug" suggestion; 0 turns it off.
    @Published var chargeLimitAlert: Int { didSet { defaults.set(chargeLimitAlert, forKey: Key.chargeLimitAlert) } }
    @Published var lowBatteryAlerts: Bool { didSet { defaults.set(lowBatteryAlerts, forKey: Key.lowBatteryAlerts) } }

    @Published private(set) var loginItemError: String?

    /// Border, shadow and corners of the current style.
    var theme: ThemeOptions {
        get { themes[notchStyle.rawValue] ?? .defaults(for: notchStyle) }
        set { themes[notchStyle.rawValue] = newValue }
    }

    func resetTheme() { themes[notchStyle.rawValue] = nil }

    func isTabEnabled(_ tab: DashboardTab) -> Bool { tab == .home || enabledTabs.contains(tab) }

    func setTab(_ tab: DashboardTab, enabled: Bool) {
        var tabs = enabledTabs.filter { $0 != tab }
        if enabled { tabs.append(tab) }
        enabledTabs = DashboardTab.allCases.filter(tabs.contains)
    }

    private init() {

        defaults.register(defaults: [
            Key.notchEnabled: true,
            Key.expandOnHover: true,
            Key.peekOnTrackChange: true,
            Key.wingWidth: 90.0,
            Key.showCustomText: true,
            Key.customText: "Hello 👋",
            Key.showTime: true,
            Key.use24Hour: false,
            Key.showSeconds: false,
            Key.showDate: true,
            Key.showMusic: true,
            Key.showCalendar: true,
            Key.notchStyle: NotchStyle.black.rawValue,
            Key.backgroundAnimation: BackgroundAnimation.none.rawValue,
            Key.chargingAnimation: true,
            Key.chargingIndicator: true,
            Key.matchAlbumArt: false,
            Key.backgroundImageDim: 0.35,
            Key.backgroundImageBlur: 0.0,
            Key.animateMusicBars: true,
            Key.reactiveWaveform: true,
            Key.chargingGlow: true,
            Key.neonPulse: true,
            Key.animateFocusRing: true,
            Key.animateBanners: true,
            Key.animateTabs: true,
            Key.showProgress: true,
            Key.showVolume: true,
            Key.spotifyControls: true,
            Key.dateStyle: DateDisplayStyle.full.rawValue,
            Key.customDateFormat: "EEE d MMM",
            Key.eventCountdown: true,
            Key.reminderMinutes: 5,
            Key.worldClocks: [String](),
            Key.enabledTabs: DashboardTab.allCases.map(\.rawValue),
            Key.clipboardEnabled: true,
            Key.clipboardLimit: 40,
            Key.downloadsMonitor: true,
            Key.focusMinutes: 25,
            Key.shortBreakMinutes: 5,
            Key.longBreakMinutes: 15,
            Key.sessionsPerCycle: 4,
            Key.privacyIndicators: true,
            Key.chargeLimitAlert: 0,
            Key.lowBatteryAlerts: true,
            Key.notificationHub: true,
        ])
        notchEnabled = defaults.bool(forKey: Key.notchEnabled)
        expandOnHover = defaults.bool(forKey: Key.expandOnHover)
        peekOnTrackChange = defaults.bool(forKey: Key.peekOnTrackChange)
        wingWidth = defaults.double(forKey: Key.wingWidth)
        showCustomText = defaults.bool(forKey: Key.showCustomText)
        customText = defaults.string(forKey: Key.customText) ?? ""
        showTime = defaults.bool(forKey: Key.showTime)
        use24Hour = defaults.bool(forKey: Key.use24Hour)
        showSeconds = defaults.bool(forKey: Key.showSeconds)
        showDate = defaults.bool(forKey: Key.showDate)
        showMusic = defaults.bool(forKey: Key.showMusic)
        showCalendar = defaults.bool(forKey: Key.showCalendar)
        notchStyle = NotchStyle(rawValue: defaults.string(forKey: Key.notchStyle) ?? "") ?? .black
        backgroundAnimation = BackgroundAnimation(rawValue: defaults.string(forKey: Key.backgroundAnimation) ?? "") ?? .none
        chargingAnimation = defaults.bool(forKey: Key.chargingAnimation)
        chargingIndicator = defaults.bool(forKey: Key.chargingIndicator)
        themes = Self.loadCodable([String: ThemeOptions].self, from: defaults, forKey: Key.themes) ?? [:]
        matchAlbumArt = defaults.bool(forKey: Key.matchAlbumArt)
        backgroundImageFileName = defaults.string(forKey: Key.backgroundImageFileName)
        backgroundImageDim = defaults.double(forKey: Key.backgroundImageDim)
        backgroundImageBlur = defaults.double(forKey: Key.backgroundImageBlur)
        animateMusicBars = defaults.bool(forKey: Key.animateMusicBars)
        reactiveWaveform = defaults.bool(forKey: Key.reactiveWaveform)
        chargingGlow = defaults.bool(forKey: Key.chargingGlow)
        neonPulse = defaults.bool(forKey: Key.neonPulse)
        animateFocusRing = defaults.bool(forKey: Key.animateFocusRing)
        animateBanners = defaults.bool(forKey: Key.animateBanners)
        animateTabs = defaults.bool(forKey: Key.animateTabs)
        showProgress = defaults.bool(forKey: Key.showProgress)
        showVolume = defaults.bool(forKey: Key.showVolume)
        spotifyControls = defaults.bool(forKey: Key.spotifyControls)
        dateStyle = DateDisplayStyle(rawValue: defaults.string(forKey: Key.dateStyle) ?? "") ?? .full
        customDateFormat = defaults.string(forKey: Key.customDateFormat) ?? ""
        eventCountdown = defaults.bool(forKey: Key.eventCountdown)
        reminderMinutes = defaults.integer(forKey: Key.reminderMinutes)
        worldClocks = defaults.stringArray(forKey: Key.worldClocks) ?? []
        enabledTabs = (defaults.stringArray(forKey: Key.enabledTabs) ?? []).compactMap(DashboardTab.init(rawValue:))
        clipboardEnabled = defaults.bool(forKey: Key.clipboardEnabled)
        clipboardLimit = defaults.integer(forKey: Key.clipboardLimit)
        downloadsMonitor = defaults.bool(forKey: Key.downloadsMonitor)
        focusMinutes = defaults.integer(forKey: Key.focusMinutes)
        shortBreakMinutes = defaults.integer(forKey: Key.shortBreakMinutes)
        longBreakMinutes = defaults.integer(forKey: Key.longBreakMinutes)
        sessionsPerCycle = defaults.integer(forKey: Key.sessionsPerCycle)
        quickActions = Self.loadCodable([QuickAction].self, from: defaults, forKey: Key.quickActions) ?? QuickAction.defaults
        privacyIndicators = defaults.bool(forKey: Key.privacyIndicators)
        chargeLimitAlert = defaults.integer(forKey: Key.chargeLimitAlert)
        lowBatteryAlerts = defaults.bool(forKey: Key.lowBatteryAlerts)
        notificationHub = defaults.bool(forKey: Key.notificationHub)
    }

    /// The app used to be called "Dynamic Notch" (bundle ID com.dd.dynamicnotch). On the first launch
    /// as MacNotch, its settings and files in Application Support are carried over.
    static func migrateFromOldName() {
        let defaults = UserDefaults.standard
        let flag = "migratedFromOldName"
        guard !defaults.bool(forKey: flag) else { return }
        if let old = defaults.persistentDomain(forName: "com.dd.dynamicnotch") {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldDirectory = support.appendingPathComponent("DynamicNotch", isDirectory: true)
        if FileManager.default.fileExists(atPath: oldDirectory.path),
           !FileManager.default.fileExists(atPath: storageDirectory.path) {
            try? FileManager.default.moveItem(at: oldDirectory, to: storageDirectory)
        }
        defaults.set(true, forKey: flag)
    }

    /// The GIF option was removed in 2.0; deletes its saved file and settings.
    static func removeLegacyGIF() {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "gifFileName") {
            try? FileManager.default.removeItem(at: storageDirectory.appendingPathComponent(name))
        }
        defaults.removeObject(forKey: "gifFileName")
        defaults.removeObject(forKey: "gifMode")
    }

    private func saveCodable<T: Encodable>(_ value: T, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, forKey key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    // MARK: Picture storage

    static var storageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacNotch", isDirectory: true)
    }

    var backgroundImageURL: URL? {
        guard let backgroundImageFileName else { return nil }
        let url = Self.storageDirectory.appendingPathComponent(backgroundImageFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func importBackgroundImage(from source: URL) throws {
        let name = try copyIntoStorage(source, prefix: "notch-background")
        if let old = backgroundImageURL { try? FileManager.default.removeItem(at: old) }
        backgroundImageFileName = name
    }

    func removeBackgroundImage() {
        if let url = backgroundImageURL { try? FileManager.default.removeItem(at: url) }
        backgroundImageFileName = nil
    }

    enum ImportError: LocalizedError {
        case notAnImage
        var errorDescription: String? { "That file isn't an image macOS can open." }
    }

    /// Copies the chosen file into Application Support so it keeps working if the original moves.
    private func copyIntoStorage(_ source: URL, prefix: String) throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.storageDirectory, withIntermediateDirectories: true)

        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let name = "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)"
        let destination = Self.storageDirectory.appendingPathComponent(name)

        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        try fm.copyItem(at: source, to: destination)

        guard NSImage(contentsOf: destination) != nil else {
            try? fm.removeItem(at: destination)
            throw ImportError.notAnImage
        }
        return name
    }

    // MARK: Launch at login

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        objectWillChange.send()
    }
}
