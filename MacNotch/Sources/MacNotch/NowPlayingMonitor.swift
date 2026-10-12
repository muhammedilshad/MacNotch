import AppKit
import Foundation

/// Tracks what is playing in any app: Spotify, Apple Music, YouTube or other sites in a browser, Podcasts…
///
/// macOS only shares the system "Now Playing" state with Apple-signed processes, so it is read through
/// a small helper library loaded into /usr/bin/perl (see Adapter/NowPlayingAdapter.m). If the helper
/// can't run, Apple Music and Spotify are still picked up from their own distributed notifications.
final class NowPlayingMonitor: ObservableObject {
    static let shared = NowPlayingMonitor()

    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
        /// Display name of the playing app, such as "Spotify" or "Google Chrome".
        var source: String
        var bundleID: String?
    }

    enum Command: Int {
        case togglePlayPause = 2
        case next = 4
        case previous = 5
    }

    /// Playback position. `elapsed` was measured at `measuredAt`; see `position(at:)`.
    struct Timing: Equatable {
        var duration: Double
        var elapsed: Double
        var measuredAt: Date
        var rate: Double
    }

    static let spotifyBundleID = "com.spotify.client"

    @Published private(set) var isPlaying = false
    @Published private(set) var track: Track?
    @Published private(set) var artwork: NSImage? {
        didSet { artworkColors = artwork.map(ArtworkPalette.colors(of:)) ?? [] }
    }
    /// A few vivid colours from the artwork, for tinting the notch.
    @Published private(set) var artworkColors: [NSColor] = []
    @Published private(set) var timing: Timing?
    @Published private(set) var spotifyShuffle = false
    @Published private(set) var spotifyRepeat = false
    /// Icon of the app that is playing.
    @Published private(set) var appIcon: NSImage?

    private let adapter = NowPlayingAdapter()
    private var adapterDelivers = false
    private var appPlaying: [String: Bool] = [:]
    private var started = false

    private static let playerApps: [(source: String, notification: String, bundleID: String)] = [
        ("Music", "com.apple.Music.playerInfo", "com.apple.Music"),
        ("Spotify", "com.spotify.client.PlaybackStateChanged", "com.spotify.client"),
    ]

    func start() {
        guard !started else { return }
        started = true

        let center = DistributedNotificationCenter.default()
        for player in Self.playerApps {
            center.addObserver(forName: Notification.Name(player.notification), object: nil, queue: .main) { [weak self] note in
                self?.handlePlayerNotification(note, player: player)
            }
        }

        adapter?.start { [weak self] message in self?.handleAdapterMessage(message) }
    }

    // MARK: System Now Playing (any app)

    private func handleAdapterMessage(_ message: [String: Any]) {
        guard message["error"] == nil else { return }
        adapterDelivers = true

        if let encoded = message["artwork"] as? String {
            artwork = Data(base64Encoded: encoded).flatMap(NSImage.init(data:))
        }

        let title = message["title"] as? String ?? ""
        guard !title.isEmpty else {
            track = nil
            artwork = nil
            appIcon = nil
            timing = nil
            setPlaying(false)
            return
        }

        let bundleID = (message["bundleID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let app = bundleID.flatMap(AppInfo.lookup)
        let newTrack = Track(title: title,
                             artist: message["artist"] as? String ?? "",
                             album: message["album"] as? String ?? "",
                             source: app?.name ?? "Now Playing",
                             bundleID: bundleID)
        if newTrack != track {
            track = newTrack
            appIcon = app?.icon
            if bundleID == Self.spotifyBundleID { refreshSpotifyModes() }
        }
        let playing = message["playing"] as? Bool ?? false
        if let duration = message["duration"] as? Double, duration > 0 {
            let measuredAt = (message["timestamp"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let newTiming = Timing(duration: duration,
                                   elapsed: message["elapsed"] as? Double ?? 0,
                                   measuredAt: measuredAt,
                                   rate: playing ? (message["rate"] as? Double ?? 1) : 0)
            if newTiming != timing { timing = newTiming }
        } else if timing != nil {
            timing = nil
        }
        setPlaying(playing)
    }

    /// Current playback position in seconds, extrapolated from the last report.
    func position(at date: Date) -> Double {
        guard let timing else { return 0 }
        let position = timing.elapsed + date.timeIntervalSince(timing.measuredAt) * timing.rate
        return min(max(0, position), timing.duration)
    }

    var canSeek: Bool { adapterDelivers && timing != nil }

    func seek(to seconds: Double) {
        guard let adapter, let timing else { return }
        let target = min(max(0, seconds), timing.duration)
        self.timing = Timing(duration: timing.duration, elapsed: target, measuredAt: Date(), rate: timing.rate)
        adapter.seek(to: target)
    }

    // MARK: Spotify

    var isSpotify: Bool { track?.bundleID == Self.spotifyBundleID }

    func launchSpotify(play: Bool) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.spotifyBundleID) else {
            NSWorkspace.shared.open(URL(string: "https://open.spotify.com")!)
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            guard play else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                SpotifyScript.run("play")
            }
        }
    }

    func toggleSpotifyShuffle() {
        spotifyShuffle.toggle()
        SpotifyScript.run("set shuffling to \(spotifyShuffle)")
    }

    func toggleSpotifyRepeat() {
        spotifyRepeat.toggle()
        SpotifyScript.run("set repeating to \(spotifyRepeat)")
    }

    private func refreshSpotifyModes() {
        SpotifyScript.read("{shuffling, repeating}") { [weak self] result in
            guard let result, result.numberOfItems == 2 else { return }
            self?.spotifyShuffle = result.atIndex(1)?.booleanValue ?? false
            self?.spotifyRepeat = result.atIndex(2)?.booleanValue ?? false
        }
    }

    /// Opens the app that is playing.
    func openPlayer() {
        guard let bundleID = track?.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Music / Spotify fallback

    private func handlePlayerNotification(_ note: Notification, player: (source: String, notification: String, bundleID: String)) {
        guard !adapterDelivers else { return }
        let info = note.userInfo ?? [:]
        let state = info["Player State"] as? String ?? ""
        let playing = state == "Playing"
        appPlaying[player.source] = playing

        let title = info["Name"] as? String ?? ""
        if state == "Stopped", track?.source == player.source {
            track = nil
            artwork = nil
            appIcon = nil
        } else if !title.isEmpty, playing || track == nil || track?.source == player.source {
            let newTrack = Track(title: title,
                                 artist: info["Artist"] as? String ?? "",
                                 album: info["Album"] as? String ?? "",
                                 source: player.source,
                                 bundleID: player.bundleID)
            if newTrack != track {
                track = newTrack
                artwork = nil
                appIcon = AppInfo.lookup(player.bundleID)?.icon
            }
        }
        setPlaying(appPlaying.values.contains(true))
    }

    private func setPlaying(_ playing: Bool) {
        if playing != isPlaying { isPlaying = playing }
    }

    // MARK: Controls

    func send(_ command: Command) {
        if adapterDelivers, let adapter {
            adapter.send(command.rawValue)
            return
        }
        let player = Self.playerApps.first { $0.source == track?.source }
            ?? Self.playerApps.first { app in
                NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty == false
            }
        guard let player,
              !NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID).isEmpty else { return }

        let verb: String
        switch command {
        case .togglePlayPause: verb = "playpause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        }
        var error: NSDictionary?
        NSAppleScript(source: "tell application id \"\(player.bundleID)\" to \(verb)")?.executeAndReturnError(&error)
        if let error { NSLog("MacNotch: AppleScript control failed: \(error)") }
    }
}

/// AppleScript for the parts of Spotify that the system Now Playing controls don't cover.
enum SpotifyScript {
    private static let queue = DispatchQueue(label: "MacNotch.spotify")

    static func run(_ command: String) {
        read(command) { _ in }
    }

    static func read(_ expression: String, completion: @escaping (NSAppleEventDescriptor?) -> Void) {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: NowPlayingMonitor.spotifyBundleID).isEmpty else {
            completion(nil)
            return
        }
        queue.async {
            var error: NSDictionary?
            let result = NSAppleScript(source: "tell application id \"\(NowPlayingMonitor.spotifyBundleID)\" to \(expression)")?
                .executeAndReturnError(&error)
            if let error { NSLog("MacNotch: Spotify script failed: \(error)") }
            DispatchQueue.main.async { completion(result) }
        }
    }
}

/// Picks a few vivid colours from an image by sampling a tiny copy of it.
enum ArtworkPalette {
    static func colors(of image: NSImage) -> [NSColor] {
        let side = 10
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return [] }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        var pixels: [NSColor] = []
        for x in 0..<side {
            for y in 0..<side {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) { pixels.append(color) }
            }
        }
        // Most colourful first, skipping near-duplicates of colours already chosen.
        let ranked = pixels.sorted { score($0) > score($1) }
        var chosen: [NSColor] = []
        for color in ranked where chosen.allSatisfy({ distance($0, color) > 0.25 }) {
            chosen.append(color)
            if chosen.count == 3 { break }
        }
        return chosen
    }

    private static func score(_ color: NSColor) -> CGFloat {
        color.saturationComponent * 0.7 + color.brightnessComponent * 0.3
    }

    private static func distance(_ a: NSColor, _ b: NSColor) -> CGFloat {
        abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent) + abs(a.blueComponent - b.blueComponent)
    }
}

enum AppInfo {
    private static var cache: [String: (name: String, icon: NSImage)] = [:]

    static func lookup(_ bundleID: String) -> (name: String, icon: NSImage)? {
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        let info = (name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name,
                    icon: NSWorkspace.shared.icon(forFile: url.path))
        cache[bundleID] = info
        return info
    }
}

/// Runs the bundled NowPlayingAdapter library inside /usr/bin/perl and reads its JSON lines.
private final class NowPlayingAdapter {
    private static let perl = URL(fileURLWithPath: "/usr/bin/perl")
    private static let loader = """
        use DynaLoader;
        my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
        my $sym = DynaLoader::dl_find_symbol($lib, $ARGV[1]) or die DynaLoader::dl_error();
        DynaLoader::dl_install_xsub("main::run", $sym);
        run();
        """

    private let library: URL
    private var process: Process?
    private var buffer = Data()
    private var onMessage: (([String: Any]) -> Void)?
    private var quickExits = 0

    init?() {
        guard FileManager.default.isExecutableFile(atPath: Self.perl.path),
              let library = Bundle.main.url(forResource: "NowPlayingAdapter", withExtension: "dylib") else { return nil }
        self.library = library
    }

    func start(onMessage: @escaping ([String: Any]) -> Void) {
        self.onMessage = onMessage
        launch()
    }

    private func launch() {
        let process = makeProcess(symbol: "dn_stream")
        let output = Pipe()
        process.standardOutput = output
        // Keeping the write end open is what keeps the helper alive; it exits when we quit.
        process.standardInput = Pipe()
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            DispatchQueue.main.async { self?.consume(data) }
        }
        let launchedAt = Date()
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.relaunch(after: Date().timeIntervalSince(launchedAt)) }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            NSLog("MacNotch: could not start the Now Playing helper: \(error)")
        }
    }

    private func relaunch(after uptime: TimeInterval) {
        process = nil
        buffer.removeAll()
        quickExits = uptime < 5 ? quickExits + 1 : 0
        guard quickExits < 5 else {
            NSLog("MacNotch: the Now Playing helper keeps exiting; giving up")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.launch() }
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                onMessage?(object)
            }
        }
    }

    func send(_ command: Int) {
        run(["DN_COMMAND": String(command)])
    }

    func seek(to seconds: Double) {
        run(["DN_SEEK": String(seconds)])
    }

    private func run(_ environment: [String: String]) {
        let process = makeProcess(symbol: "dn_send")
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private func makeProcess(symbol: String) -> Process {
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = ["-e", Self.loader, library.path, symbol]
        return process
    }
}
