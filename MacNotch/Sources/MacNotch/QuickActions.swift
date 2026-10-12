import AppKit
import Vision

enum QuickActionRunner {
    static func run(_ action: QuickAction) {
        let target = (action.target as NSString).expandingTildeInPath
        switch action.kind {
        case .app:
            let url = target.hasSuffix(".app")
                ? URL(fileURLWithPath: target)
                : NSWorkspace.shared.urlForApplication(withBundleIdentifier: target)
            if let url { NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) }
        case .url:
            if target.hasPrefix("/") {
                NSWorkspace.shared.open(URL(fileURLWithPath: target))
            } else if let url = URL(string: target) {
                NSWorkspace.shared.open(url)
            }
        case .shell:
            launch("/bin/zsh", ["-lc", action.target])
        case .shortcut:
            launch("/usr/bin/shortcuts", ["run", action.target])
        }
    }

    static func icon(for action: QuickAction) -> NSImage? {
        guard action.kind == .app else { return nil }
        let target = (action.target as NSString).expandingTildeInPath
        let path = target.hasSuffix(".app") ? target : NSWorkspace.shared.urlForApplication(withBundleIdentifier: target)?.path
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private static func launch(_ executable: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("MacNotch: quick action failed: \(error)")
        }
    }
}

/// Screenshot OCR: select part of the screen, and its text is copied to the clipboard.
enum TextRecognizer {
    enum Outcome {
        case copied(String)
        case noText
        case cancelled
        case failed(String)
    }

    /// Uses the system screenshot tool's selection UI. macOS asks for Screen Recording permission once.
    static func captureScreenText(completion: @escaping (Outcome) -> Void) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("macnotch-ocr-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", file.path]
        process.terminationHandler = { _ in
            defer { try? FileManager.default.removeItem(at: file) }
            guard FileManager.default.fileExists(atPath: file.path) else {
                DispatchQueue.main.async { completion(.cancelled) }
                return
            }
            let outcome = recognizeAndCopy(imageAt: file)
            DispatchQueue.main.async { completion(outcome) }
        }
        do {
            try process.run()
        } catch {
            completion(.failed(error.localizedDescription))
        }
    }

    static func recognizeAndCopy(imageAt url: URL) -> Outcome {
        do {
            let text = try recognize(imageAt: url)
            guard !text.isEmpty else { return .noText }
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            return .copied(text)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func recognize(imageAt url: URL) throws -> String {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if #available(macOS 13.0, *) { request.automaticallyDetectsLanguage = true }
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    static func isImage(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "heic", "tiff", "gif", "bmp", "webp"].contains(url.pathExtension.lowercased())
    }
}
