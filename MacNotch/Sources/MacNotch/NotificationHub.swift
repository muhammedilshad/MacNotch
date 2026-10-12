import AppKit
import ApplicationServices

/// Unread counts from the Dock's app badges (Mail, Messages, Slack…).
///
/// macOS doesn't let apps read other apps' notifications, but the Dock badges are readable through
/// the Accessibility API once the user allows it in System Settings → Privacy & Security → Accessibility.
final class NotificationHub: ObservableObject {
    static let shared = NotificationHub()

    struct Badge: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let count: String
        let appURL: URL?
    }

    @Published private(set) var badges: [Badge] = []
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private var timer: Timer?

    var total: Int { badges.reduce(0) { $0 + (Int($1.count) ?? 1) } }

    func setRunning(_ running: Bool) {
        if running, timer == nil {
            refresh()
            let timer = Timer(timeInterval: 4, repeats: true) { [weak self] _ in self?.refresh() }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !running {
            timer?.invalidate()
            timer = nil
            badges = []
        }
    }

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if !isTrusted,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func open(_ badge: Badge) {
        guard let url = badge.appURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        guard trusted, let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            if !badges.isEmpty { badges = [] }
            return
        }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var found: [Badge] = []
        for list in Self.children(of: app) where Self.string(list, kAXRoleAttribute) == kAXListRole {
            for item in Self.children(of: list) {
                guard let count = Self.string(item, "AXStatusLabel"), !count.isEmpty,
                      let name = Self.string(item, kAXTitleAttribute) else { continue }
                var url: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &url)
                found.append(Badge(name: name, count: count, appURL: url as? URL))
            }
        }
        if found != badges { badges = found }
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
