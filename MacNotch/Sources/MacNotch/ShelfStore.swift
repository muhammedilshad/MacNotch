import AppKit
import Foundation

/// Files dropped onto the notch, kept until removed, and dragged or AirDropped onwards from there.
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let url: URL
    }

    @Published private(set) var items: [Item] = []

    private static let key = "shelfBookmarks"

    init() {
        let saved = UserDefaults.standard.array(forKey: Self.key) as? [Data] ?? []
        items = saved.compactMap { data in
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI], bookmarkDataIsStale: &stale),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return Item(url: url)
        }
    }

    func add(_ urls: [URL]) {
        let existing = Set(items.map(\.url.standardizedFileURL))
        let new = urls.filter { !existing.contains($0.standardizedFileURL) }.map { Item(url: $0) }
        guard !new.isEmpty else { return }
        items.append(contentsOf: new)
        save()
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func airDrop(_ urls: [URL]) {
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else { return }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    static func shareServices(for urls: [URL]) -> [NSSharingService] {
        [NSSharingService.Name.sendViaAirDrop, .composeEmail, .composeMessage, .addToIPhoto]
            .compactMap(NSSharingService.init(named:))
            .filter { $0.canPerform(withItems: urls) }
    }

    func share(_ urls: [URL], with service: NSSharingService) {
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    private func save() {
        let bookmarks = items.compactMap { try? $0.url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) }
        UserDefaults.standard.set(bookmarks, forKey: Self.key)
    }
}

/// Downloads in progress and recently finished, found by watching the Downloads folder.
/// Covers Safari (.download), Chrome, Edge, Brave and Arc (.crdownload), Firefox (.part) and AirDrop.
final class TransferMonitor: ObservableObject {
    static let shared = TransferMonitor()

    struct Transfer: Identifiable, Equatable {
        var id: String { url.path }
        let url: URL
        let name: String
        let bytes: Int64
        let speed: Double
        let isActive: Bool
        let date: Date
    }

    @Published private(set) var active: [Transfer] = []
    @Published private(set) var recent: [Transfer] = []

    private static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial", "opdownload"]
    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    private var timer: Timer?
    private var lastSizes: [String: (bytes: Int64, at: Date)] = [:]

    func setRunning(_ running: Bool) {
        if running, timer == nil {
            scan()
            let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.scan() }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !running {
            timer?.invalidate()
            timer = nil
            active = []
            recent = []
        }
    }

    private func scan() {
        let keys: [URLResourceKey] = [.creationDateKey, .fileSizeKey, .isDirectoryKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                      options: [.skipsHiddenFiles]) else { return }
        let now = Date()
        var newActive: [Transfer] = []
        var newRecent: [Transfer] = []
        var sizes: [String: (bytes: Int64, at: Date)] = [:]

        for url in urls {
            let values = try? url.resourceValues(forKeys: Set(keys))
            let created = values?.creationDate ?? .distantPast
            if Self.partialExtensions.contains(url.pathExtension.lowercased()) {
                let bytes = values?.isDirectory == true ? Self.directorySize(url) : Int64(values?.fileSize ?? 0)
                var speed = 0.0
                if let last = lastSizes[url.path], now.timeIntervalSince(last.at) > 0 {
                    speed = max(0, Double(bytes - last.bytes) / now.timeIntervalSince(last.at))
                }
                sizes[url.path] = (bytes, now)
                newActive.append(Transfer(url: url, name: url.deletingPathExtension().lastPathComponent,
                                          bytes: bytes, speed: speed, isActive: true, date: created))
            } else if now.timeIntervalSince(created) < 30 * 60 {
                let bytes = values?.isDirectory == true ? 0 : Int64(values?.fileSize ?? 0)
                newRecent.append(Transfer(url: url, name: url.lastPathComponent, bytes: bytes, speed: 0,
                                          isActive: false, date: created))
            }
        }
        lastSizes = sizes
        newRecent.sort { $0.date > $1.date }
        let trimmedRecent = Array(newRecent.prefix(4))
        if newActive != active { active = newActive }
        if trimmedRecent != recent { recent = trimmedRecent }
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}
