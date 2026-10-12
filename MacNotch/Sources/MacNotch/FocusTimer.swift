import AppKit
import Foundation

/// A Pomodoro-style focus timer: focus sessions separated by short breaks, with a long break
/// after every few sessions.
final class FocusTimer: ObservableObject {
    static let shared = FocusTimer()

    enum Mode: String {
        case focus, shortBreak, longBreak

        var title: String {
            switch self {
            case .focus: return "Focus"
            case .shortBreak: return "Short break"
            case .longBreak: return "Long break"
            }
        }
    }

    enum State { case idle, running, paused }

    @Published private(set) var mode: Mode = .focus
    @Published private(set) var state: State = .idle
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private(set) var completedSessions = 0

    /// Called when a session ends, with the mode that just finished.
    var onFinish: ((Mode) -> Void)?

    private var finishItem: DispatchWorkItem?

    func duration(of mode: Mode) -> TimeInterval {
        let settings = AppSettings.shared
        let minutes: Int
        switch mode {
        case .focus: minutes = settings.focusMinutes
        case .shortBreak: minutes = settings.shortBreakMinutes
        case .longBreak: minutes = settings.longBreakMinutes
        }
        return TimeInterval(max(1, minutes) * 60)
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        switch state {
        case .idle: return duration(of: mode)
        case .paused: return pausedRemaining ?? duration(of: mode)
        case .running: return max(0, (endDate ?? date).timeIntervalSince(date))
        }
    }

    func progress(at date: Date = Date()) -> Double {
        1 - remaining(at: date) / duration(of: mode)
    }

    var nextMode: Mode {
        guard mode == .focus else { return .focus }
        let cycle = max(1, AppSettings.shared.sessionsPerCycle)
        return (completedSessions + 1) % cycle == 0 ? .longBreak : .shortBreak
    }

    func start(_ newMode: Mode? = nil) {
        if let newMode { mode = newMode }
        run(for: duration(of: mode))
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = remaining()
        state = .paused
        endDate = nil
        finishItem?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        run(for: pausedRemaining ?? duration(of: mode))
    }

    func toggle() {
        switch state {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        }
    }

    func reset() {
        finishItem?.cancel()
        state = .idle
        endDate = nil
        pausedRemaining = nil
    }

    /// Ends the current session early and moves on to the next one, without starting it.
    func skip() {
        let next = nextMode
        if mode == .focus { completedSessions += 1 }
        reset()
        mode = next
    }

    private func run(for seconds: TimeInterval) {
        finishItem?.cancel()
        state = .running
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(seconds)
        let item = DispatchWorkItem { [weak self] in self?.finish() }
        finishItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func finish() {
        let finished = mode
        let next = nextMode
        if finished == .focus { completedSessions += 1 }
        reset()
        mode = next
        NSSound(named: finished == .focus ? "Glass" : "Hero")?.play()
        onFinish?(finished)
    }
}

enum TimeText {
    /// "24:59" or "1:04:59".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }

    /// "12 min", "1 h 5 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }
}
