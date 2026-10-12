import AppKit
import SwiftUI

/// Border, shadow and corner shape, saved separately for every notch style.
struct ThemeOptions: Codable, Equatable {
    enum Border: String, Codable, CaseIterable, Identifiable {
        case none, hairline, neon

        var id: Self { self }

        var title: String {
            switch self {
            case .none: return "None"
            case .hairline: return "Glass rim"
            case .neon: return "Neon glow"
            }
        }
    }

    var border: Border
    var neonColor: String
    var neonFollowsAlbum: Bool
    var shadow: Bool
    var shadowRadius: Double
    var shoulderRadius: Double
    var collapsedRadius: Double
    var expandedRadius: Double

    static func defaults(for style: NotchStyle) -> ThemeOptions {
        let glass = style != .black
        return ThemeOptions(border: glass ? .hairline : .none,
                            neonColor: "#3DF58F",
                            neonFollowsAlbum: false,
                            shadow: glass,
                            shadowRadius: 16,
                            shoulderRadius: 10,
                            collapsedRadius: 10,
                            expandedRadius: 28)
    }
}

/// Pages of the expanded notch.
enum DashboardTab: String, CaseIterable, Identifiable, Codable {
    case home, shelf, clipboard, actions, system, notifications

    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "Home"
        case .shelf: return "Shelf & Transfers"
        case .clipboard: return "Clipboard"
        case .actions: return "Focus & Actions"
        case .system: return "Dashboard"
        case .notifications: return "Notifications"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .shelf: return "tray.full.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .actions: return "bolt.circle.fill"
        case .system: return "gauge.with.dots.needle.67percent"
        case .notifications: return "bell.badge.fill"
        }
    }
}

enum DateDisplayStyle: String, CaseIterable, Identifiable {
    case full, abbreviated, long, numeric, custom

    var id: Self { self }

    var title: String {
        switch self {
        case .full: return "Friday, 9 October"
        case .abbreviated: return "Fri, 9 Oct"
        case .long: return "9 October 2026"
        case .numeric: return "09/10/2026"
        case .custom: return "Custom"
        }
    }

    func format(_ date: Date, custom: String) -> String {
        switch self {
        case .full: return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        case .abbreviated: return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .long: return date.formatted(.dateTime.day().month(.wide).year())
        case .numeric: return date.formatted(date: .numeric, time: .omitted)
        case .custom:
            let formatter = DateFormatter()
            formatter.dateFormat = custom.isEmpty ? "EEEE d MMMM" : custom
            return formatter.string(from: date)
        }
    }
}

/// A button in the quick action launcher.
struct QuickAction: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case app, url, shell, shortcut

        var id: Self { self }

        var title: String {
            switch self {
            case .app: return "Open app"
            case .url: return "Open link or folder"
            case .shell: return "Run shell command"
            case .shortcut: return "Run shortcut"
            }
        }

        var placeholder: String {
            switch self {
            case .app: return "/Applications/Safari.app"
            case .url: return "https://github.com or ~/Projects"
            case .shell: return "open -a Xcode ~/Projects/App"
            case .shortcut: return "Shortcut name"
            }
        }
    }

    var id = UUID()
    var title: String
    var kind: Kind
    var target: String
    var symbol: String

    static let defaults: [QuickAction] = [
        QuickAction(title: "Terminal", kind: .app, target: "/System/Applications/Utilities/Terminal.app", symbol: "terminal"),
        QuickAction(title: "Activity", kind: .app, target: "/System/Applications/Utilities/Activity Monitor.app", symbol: "waveform.path.ecg"),
        QuickAction(title: "Downloads", kind: .url, target: "~/Downloads", symbol: "arrow.down.circle.fill"),
        QuickAction(title: "Dark Mode", kind: .shell,
                    target: "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'",
                    symbol: "circle.lefthalf.filled"),
        QuickAction(title: "Sleep Screen", kind: .shell, target: "pmset displaysleepnow", symbol: "moon.zzz.fill"),
    ]
}

extension Color {
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let value = UInt32(digits, radix: 16) ?? 0x3DF58F
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }

    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return String(format: "#%02X%02X%02X",
                      Int((color.redComponent * 255).rounded()),
                      Int((color.greenComponent * 255).rounded()),
                      Int((color.blueComponent * 255).rounded()))
    }
}
